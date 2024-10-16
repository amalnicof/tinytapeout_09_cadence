/*
 * Module `I2SController`
 *
 * Controls the ADC and DAC on the I2S2 Pmod module. The specific ICs are the CS5343 and CS4344.
 * The MCLK is the same as the system clock. Both SCLK and LRCK are derived from MCLK.
 * SCLK is set 64 times faster than LRCK. Both the ADC and DAC are run at the same sampling
 * frequency.
 *
 * The supported sampling frequency can be configured using the `clockConfig` port. The equation
 * below can be used to calculate the sampling frequency.
 * F_mclk = F_sys/((clockConfig+1) * 2)
 * F_lrck = F_fs = F_mclk/256
 *
 * The adc is right shifted to fit to DataWidth, and the dac is Left shifted to 24 bits
 */

`timescale 1ns / 1ps

module I2SController #(
    parameter int ClockConfigWidth = 4,
    parameter int DataWidth = 12,  // Number of bits for ADC and DAC data

    localparam int SerialDataWidth = 24,  // Number of bits to and from the I2S2 port per sample

    localparam int LrckMultiplier = 64,  // lrck is 64x times slower than sclk
    localparam int LrckCounterMax = (LrckMultiplier / 2) - 1,
    localparam int LrckCounterWidth = $clog2(LrckCounterMax)

) (
    input wire clk,
    input wire reset,

    input wire [ClockConfigWidth-1:0] clockConfig,

    // ADC data port
    output logic signed [DataWidth-1:0] adcData,
    output logic adcDataValid,

    // DAC data port
    input wire signed [DataWidth-1:0] dacData,
    input wire dacDataValid,

    // I2S2 port
    output logic mclk,
    output logic sclk,
    output logic lrck,
    input  wire  adc,
    output logic dac
);
  typedef enum logic [1:0] {
    IDLE_S,
    CLEAR_S,
    SHIFT_S
  } state_e;

  // Clock divider counters
  logic [ClockConfigWidth-1:0] mclkCounter;
  logic sclkCounter;  // mclk div 4
  logic [4:0] lrckCounter;  // sclk div 64

  // Pulse signals
  wire mclkTransition = mclkCounter == clockConfig;
  wire sclkTransition = mclkTransition && mclk && sclkCounter == 1'h1;
  wire lrckTransition = sclkTransition && sclk && lrckCounter == 5'h1f;

  wire samplePulse = sclkTransition && !sclk;  // Pulse to sample adc, posedge of sclk
  wire dacTransition = sclkTransition && sclk;  // Pulse to change dac, negedge of sclk

  // external input synchronizer
  logic [1:0] adcSynchronizer;
  wire adcQ = adcSynchronizer[1];

  // State machine signals
  state_e currentState;
  state_e nextState;

  logic [DataWidth-1:0] dacDataQ;  // Registered data for dac output

  // Generate clocks and pulses
  always_ff @(posedge clk) begin : ClockGeneration
    if (reset) begin
      mclk <= 1'b0;
      sclk <= 1'b0;
      lrck <= 1'b0;
      mclkCounter <= ClockConfigWidth'(0);
      sclkCounter <= 2'b0;
      lrckCounter <= 6'b0;
    end else begin
      if (mclkTransition) begin
        mclkCounter <= ClockConfigWidth'(0);
        mclk <= ~mclk;
      end else begin
        mclkCounter <= mclkCounter + 1;
      end

      if (mclkTransition && mclk) begin
        // Count on negedge of mclk
        sclkCounter <= sclkCounter + 1;
        if (sclkTransition) begin
          sclk <= ~sclk;
        end
      end

      if (sclkTransition && sclk) begin
        // Count on negedge of sclk
        lrckCounter <= lrckCounter + 1;
        if (lrckTransition) begin
          lrck <= ~lrck;
        end
      end
    end
  end

  always_ff @(posedge clk) begin : AdcSynchronizer
    if (reset) begin
      adcSynchronizer <= 0;
    end else begin
      adcSynchronizer <= {adcSynchronizer[0], adc};
    end
  end

  always_comb begin : NextStateCompute
    if (reset) begin
      nextState = IDLE_S;
    end else begin
      unique case (currentState)
        IDLE_S: begin
          if (lrckTransition && !lrck) begin
            // positive edge of lrck
            nextState = CLEAR_S;
          end else begin
            nextState = IDLE_S;
          end
        end

        CLEAR_S: begin
          if (samplePulse) begin
            // Skip the first sample pulse as per specification
            nextState = SHIFT_S;
          end else begin
            nextState = CLEAR_S;
          end
        end

        SHIFT_S: begin
          if (lrckCounter == SerialDataWidth + 1) begin
            nextState = IDLE_S;
          end else begin
            nextState = SHIFT_S;
          end
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin : NextStateExecution
    currentState <= nextState;
  end

  always_ff @(posedge clk) begin : AdcExecution
    if (reset) begin
      adcData <= 0;
    end else begin
      unique case (currentState)
        IDLE_S: begin
          adcDataValid <= 0;
        end

        CLEAR_S: begin
          adcData <= 0;
        end

        SHIFT_S: begin
          if (samplePulse && lrckCounter <= SerialDataWidth - DataWidth) begin
            adcData <= {adcData[DataWidth-2:0], adcQ};
          end

          if (nextState == IDLE_S) begin
            adcDataValid <= 1;
          end
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin : DacExecution
    if (reset) begin
      dac <= 0;
    end else begin
      case (currentState)
        IDLE_S: begin
          dac <= 1'b0;
        end

        CLEAR_S: begin
        end

        SHIFT_S: begin
          if (dacTransition) begin
            if (lrckCounter < DataWidth) begin
              dac <= dacDataQ[DataWidth-lrckCounter-1];
            end else begin
              dac <= 1'b0;
            end
          end
        end
        default: dac <= 1'b0;
      endcase
    end
  end

  always_ff @(posedge clk) begin : DacDataUpdate
    if (reset) begin
      dacDataQ <= 0;
    end else begin
      if (dacDataValid && currentState != SHIFT_S) begin
        dacDataQ <= dacData;
      end
    end
  end
endmodule

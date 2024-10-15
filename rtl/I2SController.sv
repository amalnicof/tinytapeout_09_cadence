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
 * TODO EDIT
 * F_sclk = F_clk/((clockConfig+1)*2)
 * Fs = F_sclk/64
 *
 * Assuming a system clock of 32MHz, and a config width of 6 bits, the range of the sampling
 * frequency is 7936kHz to 500kHz. Though it is important to remember that the sampling frequency
 * range of the ADC and DAC ICs are 4kHz-100kHz
 */

`timescale 1ns / 1ps

module I2SController #(
    parameter int ClockConfigWidth = 4,
    parameter int DataWidth = 12,  // Number of bits for ADC and DAC data

    localparam int SerialDataWidth = 24,  // Number of bits to and from the I2S2 port per sample
    localparam int ScaleWidth = $clog2(SerialDataWidth + DataWidth),

    localparam int LrckMultiplier = 64,  // lrck is 64x times slower than sclk
    localparam int LrckCounterMax = (LrckMultiplier / 2) - 1,
    localparam int LrckCounterWidth = $clog2(LrckCounterMax),

    localparam int AdditionalShiftCounterWidth = $clog2(DataWidth)
) (
    input wire clk,
    input wire reset,

    input wire [ClockConfigWidth-1:0] clockConfig,

    // ADC data port
    input wire [ScaleWidth-1:0] adcScale,
    output logic [DataWidth-1:0] adcData,
    output logic adcDataValid,

    // DAC data port
    input wire [ScaleWidth-1:0] dacScale,
    input wire [DataWidth-1:0] dacData,
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
    SHIFT_S,
    SHIFT_MORE_S
  } state_e;

  // Clock divider counters
  logic [ClockConfigWidth-1:0] mclkCounter;
  logic sclkCounter;  // mclk div 4
  logic [4:0] lrckCounter;  // sclk div 64

  logic [AdditionalShiftCounterWidth-1:0] additionalShiftCounter;

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

  wire [ScaleWidth-1:0] adcScaleBounded = adcScale > SerialDataWidth + DataWidth ? 0 : adcScale;
  wire [ScaleWidth-1:0] dacScaleBounded = dacScale > SerialDataWidth + DataWidth ? 0 : dacScale;

  logic [DataWidth-1:0] dacDataQ;  // Registered data for dac output
  // Data should be sourced from dacDataQ when shifting
  wire dacDataIndexValid =
    signed'((LrckCounterWidth + 1)'(lrckCounter))
      > signed'(SerialDataWidth) - signed'((ScaleWidth + 1)'(dacScaleBounded+1))
    && lrckCounter < SerialDataWidth + DataWidth - dacScaleBounded;

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
            if (adcScaleBounded > lrckCounter - 1) begin
              nextState = SHIFT_MORE_S;
            end else begin
              nextState = IDLE_S;
            end
          end else begin
            nextState = SHIFT_S;
          end
        end

        SHIFT_MORE_S: begin
          if (additionalShiftCounter == (adcScaleBounded - SerialDataWidth - 1)) begin
            nextState = IDLE_S;
          end else begin
            nextState = SHIFT_MORE_S;
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
      additionalShiftCounter <= 0;
    end else begin
      unique case (currentState)
        IDLE_S: begin
          adcDataValid <= 0;
          additionalShiftCounter <= 0;
        end

        CLEAR_S: begin
          adcData <= 0;
        end

        SHIFT_S: begin
          if (samplePulse && lrckCounter <= adcScaleBounded) begin
            adcData <= {adcData[DataWidth-2:0], adcQ};
          end

          if (nextState == IDLE_S) begin
            adcDataValid <= 1;
          end
        end

        SHIFT_MORE_S: begin
          // Shift in extra zeros to scale up
          additionalShiftCounter <= additionalShiftCounter + 1;
          adcData <= {adcData[DataWidth-2:0], 1'b0};

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
      unique case (currentState)
        IDLE_S: begin
          dac <= 0;
        end

        CLEAR_S: begin
        end

        SHIFT_S: begin
          if (dacTransition) begin
            if (dacDataIndexValid) begin
              dac <= dacDataQ[SerialDataWidth-lrckCounter+DataWidth-dacScaleBounded-1];
            end else begin
              dac <= 0;
            end
          end
        end

        SHIFT_MORE_S: begin
          dac <= 0;
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin : DacDataUpdate
    if (reset) begin
      dacDataQ <= 0;
    end else begin
      if (dacDataValid && currentState != SHIFT_S && !dacDataIndexValid) begin
        dacDataQ <= dacData;
      end
    end
  end
endmodule

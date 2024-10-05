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
 * F_sclk = F_clk/((clockConfig+1)*2)
 * Fs = F_sclk/64
 *
 * Assuming a system clock of 32MHz, and a config width of 7 bits, the range of the sampling
 * frequency is 3937kHz to 500kHz. Though it is important to remember that the sampling frequency
 * range of the ADC and DAC ICs are 4kHz-100kHz
 */

`timescale 1ns / 1ps

module I2SController #(
    parameter int ClockConfigWidth = 6,
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
    input wire [ScaleWidth-1:0] adcScaleRaw,
    output logic [DataWidth-1:0] adcData,
    output logic adcValidPulse,

    // DAC data port
    input wire [ScaleWidth-1:0] dacScaleRaw,
    input wire [ DataWidth-1:0] dacData,

    // I2S2 port
    output wire  mclk,
    output logic sclk,
    output logic lrck,
    input  wire  adcIn,
    output logic dacOut
);
  typedef enum logic [1:0] {
    IDLE_S,
    CLEAR_S,
    SHIFT_S,
    SHIFT_MORE_S
  } state_e;

  // Clock divider counters
  logic [ClockConfigWidth-1:0] sclkClockCounter;
  logic [LrckCounterWidth-1:0] lrClockCounter;
  logic [AdditionalShiftCounterWidth-1:0] additionalShiftCounter;

  // Pulse signals
  wire sclkTransitionPulse;  // Edge transition pulse for sclk
  wire lrckTransitionPulse;  // Edge transition pulse for lrck
  wire samplePulse;  // Pulse to sample adcIn, negative edge of sclk
  wire dacTransitionPulse;  // Pulse to change dacOut, positive edge of sclk

  logic [1:0] adcSynchronizer;
  wire adcSynced;

  // State machine signals
  state_e currentState;
  state_e nextState;

  wire [ScaleWidth-1:0] adcScale;
  wire [ScaleWidth-1:0] dacScale;

  logic [DataWidth-1:0] intDacData;  // Registered data for dac output
  wire dacDataIndexValid;  // Data should be sourced from intDacData

  assign mclk = clk;
  assign sclkTransitionPulse = sclkClockCounter == clockConfig;
  assign lrckTransitionPulse = lrClockCounter == LrckCounterMax;
  assign samplePulse = sclkTransitionPulse && sclk;
  assign dacTransitionPulse = sclkTransitionPulse && !sclk;

  assign adcSynced = adcSynchronizer[1];

  assign adcScale = adcScaleRaw > SerialDataWidth + DataWidth ? 0 : adcScaleRaw;
  assign dacScale = dacScaleRaw > SerialDataWidth + DataWidth ? 0 : dacScaleRaw;
  assign dacDataIndexValid =
    signed'((LrckCounterWidth+1)'(lrClockCounter))
      > signed'(SerialDataWidth) - 1 - signed'((ScaleWidth+1)'(dacScale))
    && lrClockCounter < SerialDataWidth + DataWidth - dacScale;

  // Generate clocks and pulses
  always_ff @(posedge clk) begin : ClockGeneration
    if (reset) begin
      sclkClockCounter <= 0;
      lrClockCounter <= 0;

      sclk <= 0;
      lrck <= 0;
    end else begin
      if (sclkTransitionPulse) begin
        sclkClockCounter <= 0;
        sclk <= ~sclk;

        if (!sclk) begin
          // On the posedge of sclk
          if (lrckTransitionPulse) begin
            lrClockCounter <= 0;
            lrck <= ~lrck;
          end else begin
            lrClockCounter <= lrClockCounter + 1;
          end
        end
      end else begin
        sclkClockCounter <= sclkClockCounter + 1;
      end
    end
  end

  always_ff @(posedge clk) begin : AdcSynchronizer
    if (reset) begin
      adcSynchronizer <= 0;
    end else begin
      adcSynchronizer <= {adcSynchronizer[0], adcIn};
    end
  end

  always_comb begin : NextStateCompute
    if (reset) begin
      nextState = IDLE_S;
    end else begin
      unique case (currentState)
        IDLE_S: begin
          if (lrckTransitionPulse && !lrck) begin
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
          if (lrClockCounter == SerialDataWidth) begin
            if (adcScale > lrClockCounter) begin
              nextState = SHIFT_MORE_S;
            end else begin
              nextState = IDLE_S;
            end
          end else begin
            nextState = SHIFT_S;
          end
        end

        SHIFT_MORE_S: begin
          if (additionalShiftCounter == (adcScale - SerialDataWidth - 1)) begin
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
          adcValidPulse <= 0;
          additionalShiftCounter <= 0;
        end

        CLEAR_S: begin
          adcData <= 0;
        end

        SHIFT_S: begin
          if (samplePulse && lrClockCounter <= adcScale) begin
            adcData <= {adcData[DataWidth-2:0], adcSynced};
          end

          if (nextState == IDLE_S) begin
            adcValidPulse <= 1;
          end
        end

        SHIFT_MORE_S: begin
          // Shift in extra zeros to scale up
          additionalShiftCounter <= additionalShiftCounter + 1;
          adcData <= {adcData[DataWidth-2:0], 1'b0};

          if (nextState == IDLE_S) begin
            adcValidPulse <= 1;
          end
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin : DacExecution
    if (reset) begin
      intDacData <= 0;
    end else begin
      unique case (currentState)
        IDLE_S: begin
          dacOut <= 0;
        end

        CLEAR_S: begin
          // Update internal register
          intDacData <= dacData;
        end

        SHIFT_S: begin
          if (dacTransitionPulse) begin
            if (dacDataIndexValid) begin
              dacOut <= intDacData[SerialDataWidth-lrClockCounter-1+DataWidth-dacScale];
            end else begin
              dacOut <= 0;
            end
          end
        end

        SHIFT_MORE_S: begin
          dacOut <= 0;
        end
      endcase
    end
  end
endmodule

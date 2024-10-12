/*
 * Module `I2SClockGenerator`
 *
 * Generates the 3 clocks necessary to run the I2S2 Pmod module.
 */

`timescale 1ns / 1ps

module I2SClockGenerator #(
    parameter integer ClockConfigWidth = 4
) (
    input wire clk,
    input wire reset,

    input wire [ClockConfigWidth-1:0] clockConfig,

    output logic mclk,
    output logic sclk,
    output logic lrck
);
  logic [ClockConfigWidth-1:0] mclkCounter;
  logic [1:0] sclkCounter;  // mclk div 4
  logic [5:0] lrckCounter;  // sclk div 64

  always_ff @(posedge clk) begin : ClockGenerator
    if (reset) begin
      mclk <= 1'b0;
      sclk <= 1'b0;
      lrck <= 1'b0;
      mclkCounter <= ClockConfigWidth'(0);
      sclkCounter <= 2'b0;
      lrckCounter <= 6'b0;
    end else begin
      mclkCounter <= mclkCounter + 1;

      if (mclkCounter == clockConfig) begin
        mclkCounter <= ClockConfigWidth'(0);
        mclk <= ~mclk;
        sclkCounter <= sclkCounter + 1;

        if (sclkCounter == 2'd3) begin
          sclk <= ~sclk;
          lrckCounter <= lrckCounter + 1;

          if (lrckCounter == 6'd63) begin
            lrck <= ~lrck;
          end
        end
      end
    end
  end
endmodule

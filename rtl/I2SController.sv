/*
 * Module `I2SController`
 *
 * Controls the ADC and DAC on the I2S2 Pmod module. The specific ICs are the CS5343 and CS4344.
 * The MCLK is the same as the system clock. Both SCLK and LRCK are derived from MCLK.
 * SCLK is set 64 times faster than LRCK. Both the ADC and DAC are run at the same sampling
 * frequency.
 */

`timescale 1ns / 1ns

module I2SController #(
    // parameter int CLK_F = 50000000
) (
    input wire clk,
    input wire reset,

    // I2S2 Port
    output wire mclk,
    output wire sclk,
    output wire lrck,
    input  wire adcIn,
    output wire dacOut

);
  // Generate clock
  logic [1:0] clockGenCounter;


  always_ff @(posedge clk) begin
    if (reset) begin
      clockGenCounter <= 0;
    end else begin
      clockGenCounter <= clockGenCounter + 1;
    end
  end

endmodule



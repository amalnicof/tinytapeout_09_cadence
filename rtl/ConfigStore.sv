/*
 * Module `ConfigStore`
 *
 * Stores configuration values using a shift register.
 */

`timescale 1ns / 1ps

module ConfigStore #(
    parameter integer ClockConfigWidth = 4,
    parameter integer ScaleWidth = 6,
    parameter integer SymCoeffsWidth = 1,

    parameter logic [ClockConfigWidth-1:0] DefaultClockConfig = 4'hf,  // Around 7kHz for 32MHz Clk
    parameter logic [ScaleWidth-1:0] DefaultAdcScale = 6'd24,  // No scaling
    parameter logic [ScaleWidth-1:0] DefaultDacScale = 6'd12,  // No Scaling
    parameter logic DefaultSymCoeffs = 1'b1,

    localparam integer ShiftRegSize = ClockConfigWidth + (ScaleWidth * 2) + SymCoeffsWidth
) (
    input wire clk,
    input wire reset,

    // Shift register port
    input  wire serialEn,
    input  wire serialIn,
    output wire serialOut,

    // Config
    output wire [ClockConfigWidth-1:0] clockConfig,
    output wire [ScaleWidth-1:0] adcScale,
    output wire [ScaleWidth-1:0] dacScale,
    output wire symCoeffs
);
  logic [ShiftRegSize-1:0] shiftReg;

  assign {symCoeffs, dacScale, adcScale, clockConfig} = shiftReg;
  assign serialOut = shiftReg[ShiftRegSize-1];

  always @(posedge clk) begin
    if (reset) begin
      shiftReg <= {DefaultSymCoeffs, DefaultDacScale, DefaultAdcScale, DefaultClockConfig};
    end else if (serialEn) begin
      shiftReg <= {shiftReg[ShiftRegSize-2:0], serialIn};
    end
  end
endmodule

/*
 * Module `ConfigStore`
 *
 * Stores configuration values using a shift register.
 */

`timescale 1ns / 1ps

module ConfigStore #(
    parameter integer ClockConfigWidth = 6,
    parameter integer ScaleWidth = 6,

    localparam integer ShiftRegSize = ClockConfigWidth + (ScaleWidth * 2)
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
    output wire [ScaleWidth-1:0] dacScale
);
  logic [ShiftRegSize-1:0] shiftReg;

  assign {dacScale, adcScale, clockConfig} = shiftReg;
  assign serialOut = shiftReg[ShiftRegSize-1];

  always @(posedge clk) begin
    if (reset) begin
      shiftReg <= 0;
    end else begin
      shiftReg <= {shiftReg[ShiftRegSize-2:0], serialIn};
    end
  end
endmodule

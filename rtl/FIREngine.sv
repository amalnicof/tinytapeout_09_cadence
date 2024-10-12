/*
 * Module `FIREngine`
 *
 * Top module for the FIREngine
 */

`timescale 1ns / 1ps

module FIREngine #(
    localparam integer ClockConfigWidth = 4,
    localparam integer DataWidth = 12,
    localparam integer ScaleWidth = 6
) (
    input wire clk,
    input wire reset,

    // I2S2 Port
    output wire mclk,
    output wire sclk,
    output wire lrck,
    input  wire adc,
    output wire dac,

    // SPI Port
    input wire spiClk,
    input wire mosi,
    input wire cs
);
  // Serial signals
  wire serial;
  wire serialEn;

  // Configuration signals
  wire [ClockConfigWidth-1:0] clockConfig;
  wire [ScaleWidth-1:0] adcScale;
  wire [ScaleWidth-1:0] dacScale;

  // Data signals
  wire [11:0] adcData;
  wire adcDataValid;

  // Instantiations
  I2SController #(
      .ClockConfigWidth(ClockConfigWidth),
      .DataWidth(DataWidth)
  ) i2sController (
      .clk(clk),
      .reset(reset),
      .clockConfig(clockConfig),
      .adcScale(adcScale),
      .adcData(adcData),
      .adcDataValid(adcDataValid),
      .dacScale(dacScale),
      .dacData(adcData),  // TODO: DEBUG: Pass adc to dac
      .dacDataValid(adcDataValid),  // TODO: DEBUG: Pass adc to dac
      .mclk(mclk),
      .sclk(sclk),
      .lrck(lrck),
      .adc(adc),
      .dac(dac)
  );

  SPISlave spiSlave (
      .clk(clk),
      .reset(reset),
      .serialOut(serial),
      .serialEn(serialEn),
      .rawSCLK(spiClk),
      .rawMOSI(mosi),
      .rawCS(cs)
  );

  ConfigStore #(
      .ClockConfigWidth(ClockConfigWidth),
      .ScaleWidth(ScaleWidth)
  ) configStore (
      .clk(clk),
      .reset(reset),
      .serialEn(serialEn),
      .serialIn(serial),
      .serialOut(),  // TODO: Connect to coefficient shift register
      .clockConfig(clockConfig),
      .adcScale(adcScale),
      .dacScale(dacScale)
  );
endmodule

/*
 * Module `FIREngine`
 *
 * Top module for the FIREngine
 */

`timescale 1ns / 1ps

module FIREngine #(
    localparam integer ClockConfigWidth = 4,
    localparam integer DataWidth = 12,
    localparam integer ScaleWidth = 6,
    localparam integer Taps = 8
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
  wire serial;  // from spi to config
  wire serialFir;  // from config to fir
  wire serialEn;

  // Configuration signals
  wire [ClockConfigWidth-1:0] clockConfig;
  wire [ScaleWidth-1:0] adcScale;
  wire [ScaleWidth-1:0] dacScale;

  // Data signals
  wire [DataWidth-1:0] adcData;
  wire adcDataValid;

  wire [DataWidth-1:0] firData;
  wire firDataValid;

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
      .dacData(firData),
      .dacDataValid(firDataValid),
      .mclk(mclk),
      .sclk(sclk),
      .lrck(lrck),
      .adc(adc),
      .dac(dac)
  );

  fir #(
      .DataWidth(DataWidth),
      .NTaps(Taps)
  ) firInst (
      .clk(clk),
      .rst(reset),
      .start(adcDataValid),
      .lock(!cs),  // Lock when spi is writing data
      .done(firDataValid),
      .coeff_load_in(serialEn),
      .coeff_in(serialFir),
      .x(adcData),
      .y(firData)
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
      .serialOut(serialFir),
      .clockConfig(clockConfig),
      .adcScale(adcScale),
      .dacScale(dacScale)
  );
endmodule

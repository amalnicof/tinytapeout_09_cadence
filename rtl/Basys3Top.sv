/*
 * Module `Basys3Top`
 *
 * Top file for implementation on the Basys3 board.
 */

module Basys3Top (
    input wire rawClk,
    input wire extReset,

    // I2S2 Port
    output dacMCLK,
    output dacLRCK,
    output dacSCLK,
    output dacData,
    output adcMCLK,
    output adcLRCK,
    output adcSCLK,
    input  adcData,

    // SPI Port
    input wire cs,
    input wire mosi,
    input wire spiClk
);
  wire clk;
  wire reset;

  wire mclk;
  wire sclk;
  wire lrck;

  ClockGenerator clockGen (
      .sysClk(clk),
      .reset (extReset),
      .locked(locked),
      .rawClk(rawClk)
  );

  FIREngine firEngine (
      .clk(clk),
      .reset(reset),
      .mclk(mclk),
      .sclk(sclk),
      .lrck(lrck),
      .adc(adcData),
      .dac(dacData),
      .spiClk(spiClk),
      .mosi(mosi),
      .cs(cs)
  );

  ILA ila (
      .clk(clk),
      .probe0(firEngine.adcData),
      .probe1(adcData),
      .probe2(dacData),
      .probe3(mclk),
      .probe4(sclk),
      .probe5(lrck),
      .probe6(firEngine.adcDataValid),
      .probe7(firEngine.clockConfig),
      .probe8(firEngine.adcScale),
      .probe9(firEngine.dacScale),
      .probe10(spiClk),
      .probe11(mosi),
      .probe12(cs),
      .probe13(firEngine.serialEn),
      .probe14(firEngine.serial)
  );

  assign reset   = !locked;

  assign dacMCLK = mclk;
  assign dacLRCK = lrck;
  assign dacSCLK = sclk;
  assign adcMCLK = mclk;
  assign adcLRCK = lrck;
  assign adcSCLK = sclk;
endmodule
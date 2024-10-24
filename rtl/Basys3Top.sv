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
  wire resetN;

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
      .resetN(resetN),
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
      .probe8(spiClk),
      .probe9(mosi),
      .probe10(cs),
      .probe11(firEngine.serialEn),
      .probe12(firEngine.serial),
      .probe13(firEngine.firInst.coeffs[0]),
      .probe14(firEngine.firInst.coeffs[1]),
      .probe15(firEngine.firInst.coeffs[2]),
      .probe16(firEngine.firInst.coeffs[3]),
      .probe17(firEngine.firInst.coeffs[4]),
      .probe18(firEngine.firData)
  );

  assign resetN  = locked;

  assign dacMCLK = mclk;
  assign dacLRCK = lrck;
  assign dacSCLK = sclk;
  assign adcMCLK = mclk;
  assign adcLRCK = lrck;
  assign adcSCLK = sclk;
endmodule

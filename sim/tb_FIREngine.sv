`timescale 1ns / 1ps

interface i2s_if;
  logic mclk;
  logic sclk;
  logic lrck;
  logic adc;
  logic dac;

  modport Slave(input mclk, input sclk, input lrck, output adc, input dac);
endinterface  // i2s_if

interface spi_if;
  logic sclk;
  logic mosi;
  logic cs;  // Active low chip-select

  modport Master(output sclk, output mosi, output cs);
endinterface

class I2SSlaveModel;
  virtual interface i2s_if.Slave i2s;

  function new(virtual interface i2s_if.Slave s);
    i2s = s;
    i2s.adc = 1'b0;
  endfunction  //new()

  task static SendAdc(input logic [23:0] data);
    @(posedge i2s.lrck);  // Only send data on high lrck

    for (int i = 0; i < 24; i++) begin
      @(posedge i2s.sclk);
      i2s.adc = data[23-i];
    end
  endtask

  task static ReadDac(output logic [23:0] data);
    @(posedge i2s.lrck);  // Only read data on high lrck
    @(negedge i2s.sclk);  // Skip first sample pulse

    for (int i = 0; i < 24; i++) begin
      @(negedge i2s.sclk);
      data = {data[22:0], i2s.dac};
    end
  endtask
endclass  // I2SSlaveModel

class SPIMasterModel;
  virtual interface spi_if.Master spi;
  logic stopClockGen;

  function new(virtual interface spi_if.Master s);
    spi = s;
    spi.sclk = 1'b0;
    spi.mosi = 1'b0;
    spi.cs = 1'b1;
  endfunction

  task static GenerateClock(input logic stop);
    // Generate 1MHz clock
    while (!stopClockGen) begin
      #500ns;
      spi.sclk = !spi.sclk;
    end
  endtask  // static

  task static SendData(input logic data[]);
    stopClockGen = 0;

    fork
      GenerateClock();
      begin
        cs <= 1'b0;
        @(posedge spi.sclk);
        @(posedge spi.sclk);
        @(posedge spi.sclk);
        @(posedge spi.sclk);
        stopClockGen = 1;
      end
    join
  endtask  // static
endclass

module tb_FIREngine ();
  i2s_if i2s ();
  spi_if spi ();
  I2SSlaveModel i2sModel;
  SPIMasterModel spiModel;

  // Configuration
  logic [5:0] dacScale;
  logic [5:0] adcScale;
  logic [3:0] clockConfig;
  logic [11:0] taps[8];
  wire [111:0] configData = {dacScale, adcScale, clockConfig, taps};

  // DUT signals
  logic clk;
  logic reset;

  FIREngine #(
      .ClockConfigWidth(4),
      .DataWidth(12),
      .ScaleWidth(6),
      .Taps(8)
  ) dut (
      .clk(clk),
      .reset(reset),
      .mclk(i2s.mclk),
      .sclk(i2s.sclk),
      .lrck(i2s.lrck),
      .adc(i2s.adc),
      .dac(i2s.dac),
      .spiClk(spi.sclk),
      .mosi(spi.mosi),
      .cs(spi.cs)
  );

  task static WaitClock(input int cycles);
    repeat (cycles) @(posedge clk);
  endtask  //static

  // Generate 32MHz clock
  initial begin
    clk = 0;
    forever begin
      #15.625 clk = ~clk;
    end
  end

  initial begin
    $dumpfile("outputs/tb_FIREngine_trace.vcd");
    $dumpvars(0, tb_FIREngine);

    $display("===================");
    $display("FIREngine Testbench");
    $display("===================");

    i2sModel = new(i2s.Slave);
    spiModel = new(spi.Master);

    // Reset core
    reset = 1;
    WaitClock(3);
    reset = 0;
    WaitClock(2);

    // Test configuration
    spiModel.SendData(configData);

    @(negedge i2s.lrck);
    WaitClock(16);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

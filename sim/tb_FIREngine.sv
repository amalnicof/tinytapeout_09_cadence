`timescale 1ns / 1ps

interface i2s2_if;
  logic mclk;
  logic sclk;
  logic lrck;
  logic adc;
  logic dac;

  modport Slave(input mclk, input sclk, input lrck, output adc, input dac);
endinterface  //i2s2_if

class I2S2SlaveModel;
  virtual interface i2s2_if.Slave i2s2;

  function new(virtual interface i2s2_if.Slave s);
    i2s2 = s;
  endfunction  //new()

  task static SendAdc(input logic [23:0] data);
    @(posedge i2s2.lrck);  // Only send data on high lrck

    for (int i = 0; i < 24; i++) begin
      @(posedge i2s2.sclk);
      i2s2.adc = data[23-i];
    end
  endtask

  task static ReadDac(output logic [23:0] data);
    @(posedge i2s2.lrck);  // Only read data on high lrck
    @(negedge i2s2.sclk);  // Skip first sample pulse

    for (int i = 0; i < 24; i++) begin
      @(negedge i2s2.sclk);
      data = {data[22:0], i2s2.dac};
    end
  endtask
endclass  //I2S2SlaveModel

module tb_FIREngine ();
  i2s2_if i2s2If ();
  I2S2SlaveModel model;

  logic [23:0] adcData;
  logic [23:0] recvDacData;

  // DUT signals
  logic clk;
  logic reset;

  FIREngine dut (
      .clk(clk),
      .reset(reset),
      .mclk(i2s2If.mclk),
      .sclk(i2s2If.sclk),
      .lrck(i2s2If.lrck),
      .adc(i2s2If.adc),
      .dac(i2s2If.dac),
      .spiClk(1'b1),
      .mosi(1'b1),
      .cs(1'b1)
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

    $display("=======================");
    $display("FIREngine Testbench");
    $display("=======================");

    model = new(i2s2If.Slave);

    // Test ADC DAC Passthrough
    i2s2If.adc = 0;
    reset = 1;
    WaitClock(3);
    reset = 0;
    WaitClock(2);

    adcData = $urandom();
    model.SendAdc(adcData);
    model.ReadDac(recvDacData);
    assert ({12'h0, adcData[11:0]} == recvDacData)
    else
      $error(
          "ADC DAC Passthrough failed, should be %h not %h", {12'h0, adcData[11:0]}, recvDacData
      );

    @(negedge i2s2If.lrck);
    WaitClock(16);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

/*
 * Module `tb_I2SController`
 *
 * Test bench for the I2SController. Ensures the following,
 * * Correct generation of sub clocks
 */


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

module tb_I2SController ();
  parameter int ClockConfigWidth = 6;

  // Testbench signals
  realtime timeStart;  // Time in ps
  realtime timeEnd;  // Time in ps

  logic [35:0] comparisonBuffer;
  logic [23:0] recvDacData;

  i2s2_if i2s2If ();
  I2S2SlaveModel model;

  // DUT signals
  logic clk;
  logic reset;

  logic [ClockConfigWidth-1:0] clockConfig;

  logic [5:0] adcScale;
  wire [11:0] adcData;
  wire adcValidPulse;

  logic [5:0] dacScale;
  logic [11:0] dacData;

  I2SController #(
      .ClockConfigWidth(ClockConfigWidth)
  ) i2sController (
      .clk(clk),
      .reset(reset),
      .clockConfig(clockConfig),
      .adcScaleRaw(adcScale),
      .adcData(adcData),
      .adcValidPulse(adcValidPulse),
      .dacScaleRaw(dacScale),
      .dacData(dacData),
      .mclk(i2s2If.mclk),
      .sclk(i2s2If.sclk),
      .lrck(i2s2If.lrck),
      .adcIn(i2s2If.adc),
      .dacOut(i2s2If.dac)
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

  // Testing procedure
  initial begin
    $dumpfile("outputs/tb_I2SController_trace.vcd");
    $dumpvars(0, tb_I2SController);

    $display("=======================");
    $display("I2SController Testbench");
    $display("=======================");

    model = new(i2s2If.Slave);

    clockConfig = 0;
    adcScale = 0;
    dacScale = 0;
    dacData = 0;
    i2s2If.adc = 0;
    reset = 1;
    WaitClock(2);

    // Test clock generation
    $display("Testing clock generation");

    // Config = 1, div 4
    // F_sclk = 8MHz, 125000ps
    // F_lrck = 125kHz, 8000000ps
    clockConfig = 6'b0000001;
    WaitClock(1);
    reset = 0;

    @(posedge i2s2If.sclk);
    timeStart = $realtime();
    @(posedge i2s2If.sclk);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 125000ps)
    else $error("SCLK period incorrect");

    @(posedge i2s2If.lrck);
    timeStart = $realtime();
    @(posedge i2s2If.lrck);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 8000000ps)
    else $error("LRCK period incorrect");

    // Test ADC scaling
    $display("Testing ADC scaling");
    @(negedge i2s2If.lrck);
    clockConfig = 6'b0000000;  // Set clock config to fastest possible for sim purposes
    WaitClock(1);

    comparisonBuffer = 36'h000ffffff;
    for (int i = 0; i <= 36; i++) begin
      adcScale = i;

      fork
        model.SendAdc(24'hffffff);
        begin
          @(posedge adcValidPulse);
          @(posedge clk);
          assert (adcData == comparisonBuffer[35:24])
          else
            $error(
                "ADC Scaling Failure: adcScale=%d, should be %h not %h",
                i,
                comparisonBuffer[35:24],
                adcData
            );
        end
      join

      comparisonBuffer = {comparisonBuffer[34:0], 1'b0};
    end

    $display("Testing invalid ADC scale");
    for (int i = 37; i < ((1 << 6) - 1); i++) begin
      adcScale = i;

      fork
        model.SendAdc(24'hffffff);
        begin
          @(posedge adcValidPulse);
          @(posedge clk);
          assert (adcData == 0)
          else
            $error("ADC Invalid Scaling Failure: adcScale=%d, should be %h not %h", i, 0, adcData);
        end
      join
    end

    // Test DAC scaling
    $display("Testing DAC scale");
    comparisonBuffer = 36'h000000fff;
    for (int i = 0; i < 36; i++) begin
      dacScale = i;
      dacData  = 12'hfff;

      model.ReadDac(recvDacData);
      assert (recvDacData == comparisonBuffer[35:12])
      else
        $error(
            "DAC Scaling Failure: dacScale=%d, should be %h not %h",
            i,
            comparisonBuffer[35:12],
            recvDacData
        );

      comparisonBuffer = {comparisonBuffer[34:0], 1'b0};
    end

    $display("Testing invalid DAC scale");
    comparisonBuffer = 36'h000000fff;
    for (int i = 37; i < ((1 << 6) - 1); i++) begin
      dacScale = i;
      dacData  = 12'hfff;

      model.ReadDac(recvDacData);
      assert (recvDacData == comparisonBuffer[35:12])
      else
        $error("DAC Invalid Scaling Failure: dacScale=%d, should be %h not %h", i, 0, recvDacData);
    end

    WaitClock(16);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

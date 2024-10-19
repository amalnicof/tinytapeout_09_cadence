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
    i2s2.adc = 0;
  endfunction  //new()

  task static SendAdc(input logic signed [23:0] data);
    @(posedge i2s2.lrck);  // Only send data on high lrck

    for (int i = 0; i < 24; i++) begin
      @(negedge i2s2.sclk);
      i2s2.adc = data[23-i];
    end
  endtask

  task static ReadDac(output logic signed [23:0] data);
    @(posedge i2s2.lrck);  // Only read data on high lrck
    @(posedge i2s2.sclk);  // Skip first sample pulse

    for (int i = 0; i < 24; i++) begin
      @(posedge i2s2.sclk);
      data = {data[22:0], i2s2.dac};
    end
  endtask
endclass  //I2S2SlaveModel

module tb_I2SController ();
  // Testbench signals
  realtime timeStart;  // Time in ps
  realtime timeEnd;  // Time in ps

  logic signed [23:0] sentAdcData;
  logic signed [23:0] recvDacData;

  i2s2_if i2s2If ();
  I2S2SlaveModel model;

  // DUT signals
  logic clk;
  logic reset;

  logic [3:0] clockConfig;

  wire signed [11:0] adcData;
  wire adcValidPulse;

  logic signed [11:0] dacData;
  logic dacDataValid;

  I2SController i2sController (
      .clk(clk),
      .reset(reset),
      .clockConfig(clockConfig),
      .adcData(adcData),
      .adcDataValid(adcValidPulse),
      .dacData(dacData),
      .dacDataValid(dacDataValid),
      .mclk(i2s2If.mclk),
      .sclk(i2s2If.sclk),
      .lrck(i2s2If.lrck),
      .adc(i2s2If.adc),
      .dac(i2s2If.dac)
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
    dacData = 0;
    dacDataValid = 0;
    reset = 1;
    WaitClock(2);

    // Test clock generation
    $display("Testing clock generation");

    // Set config to slowest
    // MCLK 1MHz
    // SCLK 250kHz
    // LRCK 3906.25kHz
    clockConfig = 4'd15;
    WaitClock(1);
    reset = 0;

    // Lock clock generator
    @(posedge i2s2If.lrck);
    @(posedge i2s2If.lrck);

    @(posedge i2s2If.mclk);
    timeStart = $realtime();
    @(posedge i2s2If.mclk);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 1000000ps)
    else $error("mclk period incorrect");

    @(posedge i2s2If.sclk);
    timeStart = $realtime();
    @(posedge i2s2If.sclk);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 4000000ps)
    else $error("sclk period incorrect");

    @(posedge i2s2If.lrck);
    timeStart = $realtime();
    @(posedge i2s2If.lrck);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 256000000ps)
    else $error("lrck period incorrect");

    // Test ADC scaling
    $display("Testing ADC");
    @(negedge i2s2If.lrck);
    clockConfig = 4'b0;  // Set clock config to fastest possible for sim purposes
    WaitClock(1);

    for (int i = 0; i <= 24; i++) begin
      std::randomize(sentAdcData);
      fork
        model.SendAdc(sentAdcData);
        begin
          @(posedge adcValidPulse);
          @(posedge clk);
          assert (adcData == sentAdcData >>> 12)
          else $error("ADC Failure: should be %h not %h", i, sentAdcData >>> 12, adcData);
        end
      join
    end

    // Test DAC scaling
    $display("Testing DAC");
    for (int i = 0; i < 24; i++) begin
      @(negedge i2s2If.lrck);
      std::randomize(dacData);
      dacDataValid = 1'b1;
      WaitClock(2);
      dacDataValid = 1'b0;
      WaitClock(1);

      model.ReadDac(recvDacData);
      assert (recvDacData == {dacData, 12'b0})
      else
        $error(
            "DAC Scaling Failure: dacScale=%d, should be %h not %h",
            i,
            {
              dacData, 12'b0
            },
            recvDacData
        );
    end

    WaitClock(16);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

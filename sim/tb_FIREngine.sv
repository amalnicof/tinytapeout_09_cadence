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
      @(negedge i2s.sclk);
      i2s.adc = data[23-i];
    end
  endtask

  task static ReadDac(output logic [23:0] data);
    @(posedge i2s.lrck);  // Only read data on high lrck
    @(posedge i2s.sclk);  // Skip first sample pulse

    for (int i = 0; i < 24; i++) begin
      @(posedge i2s.sclk);
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

  task static GenerateClock();
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
        @(posedge spi.sclk);
        spi.cs = 1'b0;

        for (int i = 0; i < data.size; i++) begin
          @(negedge spi.sclk);
          spi.mosi = data[i];
        end

        @(negedge spi.sclk);
        spi.cs = 1'b1;
        stopClockGen = 1'b1;
      end
    join
  endtask  // static
endclass

module tb_FIREngine ();
  localparam integer NTaps = 8;
  localparam integer NCoeff = NTaps / 2;

  logic [23:0] expFilterOutput;
  logic [23:0] adcData;
  logic [23:0] dacData;

  i2s_if i2s ();
  spi_if spi ();
  I2SSlaveModel i2sModel;
  SPIMasterModel spiModel;

  // Configuration
  logic [5:0] dacScale;
  logic [5:0] adcScale;
  logic [3:0] clockConfig;
  logic [11:0] coeffs[NCoeff];
  logic configData[6+6+4+(12*NCoeff)];

  // DUT signals
  logic clk;
  logic reset;

  FIREngine dut (
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
  endtask  // static

  task static ComputeFilterResponse(input logic [11:0] in, output logic [11:0] out);
    static logic [11:0] filterSamples[NTaps] = '{NTaps{12'd0}};
    logic [26:0] acc;  // UFix<16,11> TODO: SIGN

    begin
      filterSamples = {in, filterSamples[0:NTaps-2]};
      acc = 0;
      for (int i = 0; i < NCoeff; i++) begin
        acc += (filterSamples[i] + filterSamples[NTaps-1-i]) * coeffs[i];
      end

      out = acc >> 11;
    end

  endtask  // static

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
    $display("Test configuration");
    dacScale = $urandom();
    adcScale = $urandom();
    clockConfig = $urandom();
    for (int i = 0; i < NCoeff; i++) begin
      coeffs[i] = $urandom();
    end
    configData = {>>{{<<12{coeffs}}, dacScale, adcScale, clockConfig}};
    spiModel.SendData(configData);

    assert (clockConfig == dut.clockConfig)
    else $error("clockConfig incorrect, should be %h not %h", clockConfig, dut.clockConfig);
    assert (adcScale == dut.adcScale)
    else $error("adcScale incorrect, should be %h not %h", adcScale, dut.adcScale);
    assert (dacScale == dut.dacScale)
    else $error("dacScale incorrect, should be %h not %h", dacScale, dut.dacScale);
    for (int i = 0; i < NCoeff; i++) begin
      assert (coeffs[i] == dut.firInst.coeffs[i])
      else
        $error("coeff incorrect, at %d should be %h not %h", i, coeffs[i], dut.firInst.coeffs[i]);
    end

    $display("Test impulse response");
    dut.configStore.shiftReg = {6'd12, 6'd24, 4'd0};
    dut.firInst.samples = '{NTaps{12'd0}};

    adcData = 1'b1 << 11;
    i2sModel.SendAdc(adcData);
    for (int i = 0; i < NTaps + 1; i++) begin
      ComputeFilterResponse(i == 0 ? adcData : 0, expFilterOutput);
      i2sModel.ReadDac(dacData);

      assert (dacData == expFilterOutput)
      else
        $error(
            "Impulse response incorrect, at %d should be %h not %h", i, expFilterOutput, dacData
        );
    end

    $display("Test random data response");
    adcData = $urandom();
    i2sModel.SendAdc(adcData);
    for (int i = 0; i < NTaps * 2; i++) begin
      fork
        begin
          ComputeFilterResponse(adcData, expFilterOutput);
          adcData = $urandom();
          i2sModel.SendAdc(adcData);
        end
        begin
          i2sModel.ReadDac(dacData);
        end
      join

      assert (dacData == expFilterOutput)
      else $error("Response incorrect, at %d should be %h not %h", i, expFilterOutput, dacData);
    end

    for (int i = 0; i < NTaps + 1; i++) begin
      fork
        begin
          ComputeFilterResponse(adcData, expFilterOutput);
          adcData = 0;
          i2sModel.SendAdc(0);
        end
        begin
          i2sModel.ReadDac(dacData);
        end
      join

      assert (dacData == expFilterOutput)
      else
        $error("Fading response incorrect, at %d should be %h not %h", i, expFilterOutput, dacData);
    end


    WaitClock(16);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

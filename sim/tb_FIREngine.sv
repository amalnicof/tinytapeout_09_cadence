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

  task static SendAdc(input logic signed [23:0] data);
    @(posedge i2s.lrck);  // Only send data on high lrck

    for (int i = 0; i < 24; i++) begin
      @(negedge i2s.sclk);
      i2s.adc = data[23-i];
    end
  endtask

  task static ReadDac(output logic signed [23:0] data);
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
  localparam integer NTaps = 9;
  localparam integer NCoeff = (NTaps + 1) / 2;
  localparam integer DataWidth = 12;

  // int + extra int bit + frac bits + sign
  localparam integer AccumulatorWidth = DataWidth + 1 + DataWidth - 1 + 1;
  localparam logic signed [DataWidth-1:0] DataMax = (1 << (DataWidth - 1)) - 1;
  localparam logic signed [DataWidth-1:0] DataMin = 1 << (DataWidth - 1);

  logic signed [DataWidth-1:0] expFilterOutput;
  logic signed [23:0] adcData;
  logic signed [23:0] dacData;

  // Time in ps
  realtime timeStart;
  realtime timeEnd;

  i2s_if i2s ();
  spi_if spi ();
  I2SSlaveModel i2sModel;
  SPIMasterModel spiModel;

  // Configuration
  logic symCoeffs;
  logic [3:0] clockConfig;
  logic signed [DataWidth-1:0] coeffs[NCoeff];
  logic configData[1+4+(12*NCoeff)];

  // DUT signals
  logic clk;
  logic resetN;

  FIREngine #(
      .NTaps(NTaps)
  ) dut (
      .clk(clk),
      .resetN(resetN),
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
    static logic signed [DataWidth-1:0] filterSamples[NTaps] = '{NTaps{DataWidth'(0)}};
    logic signed [AccumulatorWidth-1:0] acc;
    logic signed [DataWidth:0] outInt;

    begin
      filterSamples = {in, filterSamples[0:NTaps-2]};
      acc = 0;
      for (int i = 0; i < NCoeff - 1; i++) begin
        if (symCoeffs) begin
          acc += (filterSamples[i] + filterSamples[NTaps-1-i]) * coeffs[i];
        end else begin
          acc += (filterSamples[i] - filterSamples[NTaps-1-i]) * coeffs[i];
        end
      end
      acc += coeffs[NCoeff-1] * filterSamples[NTaps/2];

      // Convert to output format
      outInt = acc >>> (DataWidth - 1);
      if (outInt > DataMax) begin
        out = DataMax;
      end else if (outInt < DataMin) begin
        out = DataMin;
      end else begin
        out = outInt[DataWidth-1:0];
      end
    end

  endtask  // static

  task static ResetCore();
    resetN = 0;
    WaitClock(2);
    resetN = 1;
    WaitClock(2);
  endtask  //static

  // Generate 50MHz clock
  initial begin
    clk = 0;
    forever begin
      #10 clk = ~clk;
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

    /**
     * Test configuration
     */
    $display("Test configuration");
    ResetCore();

    symCoeffs = 1'b1;
    std::randomize(clockConfig);
    std::randomize(coeffs);
    configData = {>>{{<<DataWidth{coeffs}}, symCoeffs, clockConfig}};
    spiModel.SendData(configData);

    assert (clockConfig == dut.clockConfig)
    else $error("clockConfig incorrect, should be %h not %h", clockConfig, dut.clockConfig);
    for (int i = 0; i < NCoeff; i++) begin
      assert (coeffs[i] == dut.firInst.coeffs[i])
      else
        $error("coeff incorrect, at %d should be %h not %h", i, coeffs[i], dut.firInst.coeffs[i]);
    end

    /**
     * Test clock generation
     */
    $display("Test clock generation");
    ResetCore();

    // Set config to slowest
    // MCLK 1.56250MHz
    // SCLK 390.625kHz
    // LRCK 6.10351kHz
    clockConfig = 4'd15;
    configData  = {>>{{<<DataWidth{coeffs}}, symCoeffs, clockConfig}};
    spiModel.SendData(configData);

    // Lock clock generator
    @(posedge i2s.lrck);
    @(posedge i2s.lrck);

    @(posedge i2s.mclk);
    timeStart = $realtime();
    @(posedge i2s.mclk);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 640ns)
    else $error("mclk period incorrect");

    @(posedge i2s.sclk);
    timeStart = $realtime();
    @(posedge i2s.sclk);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 2560ns)
    else $error("sclk period incorrect");

    @(posedge i2s.lrck);
    timeStart = $realtime();
    @(posedge i2s.lrck);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 163840ns)
    else $error("lrck period incorrect");

    /**
     * Test impulse response
     */
    $display("Test impulse response");
    ResetCore();

    symCoeffs   = 1'b1;
    clockConfig = 4'd0;
    configData  = {>>{{<<DataWidth{coeffs}}, symCoeffs, clockConfig}};
    spiModel.SendData(configData);

    adcData = 1'b1 << 22;
    i2sModel.SendAdc(adcData);
    for (int i = 0; i < NTaps + 1; i++) begin
      ComputeFilterResponse(i == 0 ? adcData >>> 12 : 0, expFilterOutput);
      i2sModel.ReadDac(dacData);

      assert (dacData == {expFilterOutput, 12'b0})
      else
        $error(
            "Impulse response incorrect, at %d should be %h not %h",
            i,
            {
              expFilterOutput, 12'b0
            },
            dacData
        );
    end

    /**
     * Test random data response
     */
    $display("Test random data response");
    ResetCore();

    configData = {>>{{<<DataWidth{coeffs}}, symCoeffs, clockConfig}};
    spiModel.SendData(configData);

    std::randomize(adcData);
    i2sModel.SendAdc(adcData);
    for (int i = 0; i < NTaps * 2; i++) begin
      fork
        begin
          ComputeFilterResponse(adcData >>> 12, expFilterOutput);
          std::randomize(adcData);
          i2sModel.SendAdc(adcData);
        end
        begin
          i2sModel.ReadDac(dacData);
        end
      join

      assert (dacData == {expFilterOutput, 12'b0})
      else
        $error(
            "Response incorrect, at %d should be %h not %h", i, {expFilterOutput, 12'b0}, dacData
        );
    end

    for (int i = 0; i < NTaps + 1; i++) begin
      fork
        begin
          ComputeFilterResponse(i == 0 ? adcData >>> 12 : 0, expFilterOutput);
          i2sModel.SendAdc(0);
        end
        begin
          i2sModel.ReadDac(dacData);
        end
      join

      assert (dacData == {expFilterOutput, 12'b0})
      else
        $error(
            "Fading response incorrect, at %d should be %h not %h",
            i,
            {
              expFilterOutput, 12'b0
            },
            dacData
        );
    end

    /**
     * Test anti-symmetric impulse
     */
    $display("Test anti-symmetric impulse");
    ResetCore();

    symCoeffs  = 1'b0;
    configData = {>>{{<<DataWidth{coeffs}}, symCoeffs, clockConfig}};
    spiModel.SendData(configData);

    adcData = 1'b1 << 22;
    i2sModel.SendAdc(adcData);
    for (int i = 0; i < NTaps + 1; i++) begin
      ComputeFilterResponse(i == 0 ? adcData >>> 12 : 0, expFilterOutput);
      i2sModel.ReadDac(dacData);

      assert (dacData == {expFilterOutput, 12'b0})
      else
        $error(
            "Anti-symmetric, impulse response incorrect, at %d should be %h not %h",
            i,
            {
              expFilterOutput, 12'b0
            },
            dacData
        );
    end

    /**
     * Test anti-symmetric random data response
     */
    $display("Test anti-symmetric random data response");
    ResetCore();

    configData = {>>{{<<DataWidth{coeffs}}, symCoeffs, clockConfig}};
    spiModel.SendData(configData);

    std::randomize(adcData);
    i2sModel.SendAdc(adcData);
    for (int i = 0; i < NTaps * 2; i++) begin
      fork
        begin
          ComputeFilterResponse(adcData >>> 12, expFilterOutput);
          std::randomize(adcData);
          i2sModel.SendAdc(adcData);
        end
        begin
          i2sModel.ReadDac(dacData);
        end
      join

      assert (dacData == {expFilterOutput, 12'b0})
      else
        $error(
            "Anti-symmetric, response incorrect, at %d should be %h not %h",
            i,
            {
              expFilterOutput, 12'b0
            },
            dacData
        );
    end

    for (int i = 0; i < NTaps + 1; i++) begin
      fork
        begin
          ComputeFilterResponse(i == 0 ? adcData >>> 12 : 0, expFilterOutput);
          i2sModel.SendAdc(0);
        end
        begin
          i2sModel.ReadDac(dacData);
        end
      join

      assert (dacData == {expFilterOutput, 12'b0})
      else
        $error(
            "Anti-symmetric, fading response incorrect, at %d should be %h not %h",
            i,
            {
              expFilterOutput, 12'b0
            },
            dacData
        );
    end

    WaitClock(16);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

`timescale 1ns / 1ps

module tb_ConfigStore ();
  logic clk;
  logic reset;

  logic [17:0] testData;
  logic [17:0] recvData;

  logic serialEn;
  logic serialIn;
  wire serialOut;

  wire [5:0] clockConfig;
  wire [5:0] adcScale;
  wire [5:0] dacScale;

  ConfigStore dut (
      .clk(clk),
      .reset(reset),
      .serialEn(serialEn),
      .serialIn(serialIn),
      .serialOut(serialOut),
      .clockConfig(clockConfig),
      .adcScale(adcScale),
      .dacScale(dacScale)
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
    $dumpfile("outputs/tb_ConfigStore_trace.vcd");
    $dumpvars(0, tb_ConfigStore);

    $display("=====================");
    $display("ConfigStore Testbench");
    $display("=====================");

    reset = 1;

    @(posedge clk);
    reset = 0;
    @(posedge clk);

    $display("Testing random data");
    repeat (4) begin
      testData = $urandom();

      for (int i = 0; i < 18; i++) begin
        @(posedge clk);
        serialEn = 1;
        serialIn = testData[17-i];
      end

      @(negedge clk);
      assert (clockConfig == testData[5:0])
      else $error("clockConfig incorrect, should be %h not %h", testData[5:0], clockConfig);
      assert (adcScale == testData[11:6])
      else $error("adcScale incorrect, should be %h not %h", testData[11:6], adcScale);
      assert (dacScale == testData[17:12])
      else $error("dacScale incorrect, should be %h not %h", testData[17:12], dacScale);

      // Verify serial out
      serialIn = 0;
      for (int i = 0; i < 18; i++) begin
        @(posedge clk);
        serialEn = 1;
        recvData = {recvData[16:0], serialOut};
      end
      serialEn = 0;

      @(negedge clk);
      assert (recvData == testData)
      else $error("Serial output incorrect, should be %h not %h", testData, recvData);
    end

    reset = 1;
    WaitClock(8);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

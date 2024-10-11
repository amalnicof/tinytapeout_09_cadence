`timescale 1ns / 1ps

module tb_I2SClockGenerator ();
  // Testbench signals
  realtime timeStart;  // Time in ps
  realtime timeEnd;  // Time in ps

  // DUT signals
  logic clk;
  logic reset;
  logic [3:0] clockConfig;
  wire mclk;
  wire sclk;
  wire lrck;

  I2SClockGenerator dut (
      .clk(clk),
      .reset(reset),
      .clockConfig(clockConfig),
      .mclk(mclk),
      .sclk(sclk),
      .lrck(lrck)
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
    $dumpfile("outputs/tb_I2SClockGenerator_trace.vcd");
    $dumpvars(0, tb_I2SClockGenerator);

    $display("===========================");
    $display("I2SClockGenerator Testbench");
    $display("===========================");

    reset = 1;
    WaitClock(2);

    // Set config to slowest
    // MCLK 1MHz
    // SCLK 250kHz
    // LRCK 3906.25kHz
    clockConfig = 4'd15;
    WaitClock(1);
    reset = 0;

    // Lock generator
    @(posedge lrck);
    @(posedge lrck);

    @(posedge mclk);
    timeStart = $realtime();
    @(posedge mclk);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 1000000ps)
    else $error("mclk period incorrect");

    @(posedge sclk);
    timeStart = $realtime();
    @(posedge sclk);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 4000000ps)
    else $error("sclk period incorrect");

    @(posedge lrck);
    timeStart = $realtime();
    @(posedge lrck);
    timeEnd = $realtime();
    assert ((timeEnd - timeStart) == 256000000ps)
    else $error("lrck period incorrect");

    WaitClock(16);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

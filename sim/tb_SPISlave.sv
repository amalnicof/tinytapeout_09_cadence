`timescale 1ns / 1ps

module tb_SPISlave ();
  logic clk;
  logic reset;

  wire serialOut;
  wire serialEn;

  logic sclk;
  logic mosi;
  logic cs;

  logic [31:0] randomData;
  logic [1:0] sclkCounter;
  logic [31:0] shiftReg;

  SPISlave dut (
      .clk(clk),
      .reset(reset),
      .serialOut(serialOut),
      .serialEn(serialEn),
      .rawSCLK(sclk),
      .rawMOSI(mosi),
      .rawCS(cs)
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

  // Generate 8Mhz clock
  initial begin
    sclk = 0;
    sclkCounter = 0;
    forever begin
      @(posedge clk);
      sclkCounter++;

      if (sclkCounter == 2) begin
        sclk = ~sclk;
      end
    end
  end

  // Shift register
  initial begin
    shiftReg = 0;
    forever begin
      @(posedge serialEn);
      shiftReg = {shiftReg[30:0], serialOut};
    end
  end

  // Testing procedure
  initial begin
    $dumpfile("outputs/tb_SPISlave_trace.vcd");
    $dumpvars(0, tb_SPISlave);

    $display("==================");
    $display("SPISlave Testbench");
    $display("==================");

    $display("Testing 32bit data");

    reset = 1;
    mosi = 1;
    cs = 1;
    WaitClock(4);
    reset = 0;
    WaitClock(4);

    // Shift in 32 bits of random data
    randomData = $urandom();

    cs = 0;
    for (int i = 0; i < 32; i++) begin
      @(negedge sclk);
      mosi = randomData[31-i];
    end

    @(negedge sclk);
    assert (shiftReg == randomData)
    else $error("SPI output data incorrect, should be %h not %h", randomData, shiftReg);

    reset = 1;
    WaitClock(8);
    $display("Testing complete.");
    $display("=================");
    $finish();
  end
endmodule

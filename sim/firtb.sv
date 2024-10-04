`timescale 1ns/1ps

module firtb;

   parameter BITS = 8;
   parameter TAPS = 4;

   reg clk, rst_n, start;
   reg [BITS-1:0] x;
   wire [BITS-1:0] y;

   always #5 clk = ~clk;

   initial begin
      clk = 0;
      #5;
      rst_n = 0;
      #12;
      rst_n = 1;
   end

   int n;

   fir #(.BITS(BITS), .TAPS(TAPS)) DUT (
      .clk(clk),
      .rst_n(rst_n),
      .start(start),
      .x(x),
      .y(y)
   );

   initial begin
      x = 'd0;
      start = 1'b0;

      $dumpfile("trace.vcd");
      $dumpvars(0, firtb);

      @(posedge rst_n);

      // shift samples in
      for (n = 0; n < 20; n = n + 1) begin
		repeat(2) begin
			@(negedge clk);
			start = ~start;
		end

        $display("X %x, Y %x", x, y);

		@(negedge clk);
        x = $random();
      end

      $finish();
   end

endmodule

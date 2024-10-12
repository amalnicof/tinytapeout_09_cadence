`timescale 1ns/1ps

module firtb;

`ifdef USE_SDF
   initial
     begin
        $sdf_annotate("../syn/outputs/iir_delays.sdf",tb.dut,,"sdf.log","MAXIMUM");
     end
`endif

   parameter BITS = 8;
   parameter TAPS = 6;
   parameter int TAPSHALF = TAPS/2;

   reg clk, rst_n, start, coeff_load_in, coeff_in;
   reg [BITS-1:0] x, x1, x2, x3, x4, x5, y_exp;
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

   fir
     `ifndef NETLIST 
       #(.BITS(BITS), .TAPS(TAPS)) 
     `endif
   DUT (
      .clk(clk),
      .rst_n(rst_n),
      .start(start),
	  .coeff_load_in(coeff_load_in),
	  .coeff_in(coeff_in),
      .x(x),
      .y(y)
   );

	initial begin
      x = 'd0;
      start = 1'b0;
	  coeff_load_in = 1'b0;
	  coeff_in = 1'b0;
	x1 = 'd0;
	x2 = 'd0;
	x3 = 'd0;
	x4 = 'd0;
	x5 = 'd0;
	y_exp = 'd0;

      $dumpfile("trace.vcd");
      $dumpvars(0, firtb);

      @(posedge rst_n);
	
	// shift in coeffs
	repeat(TAPSHALF*BITS) begin
		@(negedge clk);
		coeff_load_in = 1'b1;
		coeff_in = ~coeff_in;
	end
	@(negedge clk);
	coeff_load_in = 1'b0;
	@(negedge clk);
	force DUT.coeffs = $random();
	$display("State: %x", DUT.state);
	$display("Coeffs: %x", DUT.coeffs);
	
    // shift samples in
    for (n = 0; n < 20; n = n + 1) begin
		x = $random();
		repeat(2) begin
			@(negedge clk);
			start = ~start;
		end
		wait(DUT.state == 2'b00);
		y_exp = (x*DUT.coeffs[0]) + (x1*DUT.coeffs[1]) + (x2*DUT.coeffs[2]) + (x3*DUT.coeffs[2]) + (x4*DUT.coeffs[1]) + (x5*DUT.coeffs[0]);
        $display("X %x, Y %x, Exp y %x", x, y, y_exp);
		x5 = x4;
		x4 = x3;
		x3 = x2;
		x2 = x1;
		x1 = x;
	
		@(negedge clk);
    end

    $finish();
	end

endmodule

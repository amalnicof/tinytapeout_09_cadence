module tb;
   logic [7:0] x;
   logic [9:0] y;
   logic reset;
   logic clk;

`ifdef USE_SDF
   initial
     begin
        $sdf_annotate("../syn/outputs/iir_delays.sdf",tb.dut,,"sdf.log","MAXIMUM");

     end
`endif

   iir dut(.x(x), 
	   .y(y), 
	   .reset(reset), 
	   .clk(clk));
   
   always #5ns clk = ~clk;

   logic [9:0] test_y;
   
   initial
   begin
      // initialize sim
      clk = 1'b0;
      $dumpfile("trace.vcd");
      $dumpvars(0, tb);
      x = 8'b0;
      test_y = 10'd0;

      // reset
      reset = 1'b1;
      repeat(3)
         @(posedge clk);
      #1;      
      reset = 1'b0;
      $display("x %d y %d", x, y);
      repeat(2)
         @(posedge clk);
      #1;

      // test impulse response
      x = 8'd127;
      repeat(20)
	begin
           @(posedge clk);
	   #1;      
	   test_y = test_y / 2 + {x,2'b00};
	   $display("x %d y %d exp_y %d ERR %d", 
		    x, y, test_y, ~(test_y == y));
	   #1;
           x = 8'd0;
	end
      
      $finish;
   end
   
endmodule

module fir #(parameter BITS = 8, TAPS = 4) (
	input clk,
	input rst_n,
	input start,
	input [BITS-1:0] x,
	output [BITS-1:0] y
);

// handle inputs
reg [BITS-1:0] samples [0:TAPS-1];
integer i;
always_ff @(posedge clk) begin
	if (rst_n == 1'b0) begin
		for (i = 0; i < TAPS; i=i+1) begin
			samples[i] <= 'd0;
		end
	end else if (start == 1'b1) begin
		for (i = TAPS-1; i > 0; i=i-1) begin
			samples[i] <= samples[i-1];
		end
		samples[0] <= x;
	end
end

	assign y = samples[TAPS-1];

endmodule

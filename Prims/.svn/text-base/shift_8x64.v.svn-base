module shift_8x64_taps 				(clk, 
				shift,
				sr_in,
				sr_out,
				sr_tap_one,
				sr_tap_two,
				sr_tap_three
		 		);
  
	input clk, shift;

	input [7:0] sr_in;
	output [7:0] sr_tap_one, sr_tap_two, sr_tap_three, sr_out;

	reg [7:0] sr [63:0];
	integer n;

 	always@(posedge clk)
	begin
		if (shift == 1'b1)
		begin
			for (n = 63; n>0; n = n-1)
			begin
				sr[n] <= sr[n-1];
			end 

			sr[0] <= sr_in;
		end 
	end 
	
	assign sr_tap_one = sr[15];
	assign sr_tap_two = sr[31];
	assign sr_tap_three = sr[47];
	assign sr_out = sr[63];

endmodule

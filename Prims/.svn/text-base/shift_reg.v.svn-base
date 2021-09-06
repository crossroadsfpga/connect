module shift_reg 		(clk, 
                                rst_n,
				shift,
				sr_in,
				sr_out
		 		);
  
	parameter WIDTH = 64;
	parameter STAGES = 16;
	input clk, rst_n, shift;

	input [WIDTH-1:0] sr_in;
	output [WIDTH-1:0] sr_out;
	//output [7:0] sr_tap_one, sr_tap_two, sr_tap_three, sr_out;

	reg [WIDTH-1:0] sr [STAGES-1:0];
	integer n;

	// initialize
        initial begin
	    for (n = 0; n<STAGES; n = n+1)
	    begin
		    sr[n] <= 0;
	    end 
	end

 	always@(posedge clk)
	begin
	  //if(!rst_n) begin

	  //  for (n = 0; n<STAGES; n = n+1)
	  //  begin
	  //          sr[n] <= 0;
	  //  end 

	  //end else begin
		if (shift == 1'b1)
		//if (1'b1)
		begin
			for (n = STAGES-1; n>0; n = n-1)
			begin
				sr[n] <= sr[n-1];
			end 

			sr[0] <= sr_in;
		end 
	    //end
	end 
	
	assign sr_out = sr[STAGES-1];

endmodule

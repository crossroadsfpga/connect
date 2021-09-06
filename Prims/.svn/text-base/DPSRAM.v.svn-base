module DPSRAM (
			      Rd,
						IdxR,
			      DoutR, 

     			  We,
			      IdxW,
			      DinW, 
				    clk,
			      rst_n
		      );

	// synthesis attribute BRAM_MAP of DPSRAM is "yes";

   parameter 	WIDTH = 1;
   parameter    ADDR_BITS = 9;
   parameter	DEPTH = 1<<ADDR_BITS; 
   
	 input									Rd;
   input [ADDR_BITS-1 : 0]  IdxR;
   output [WIDTH-1 : 0] DoutR; 

   input 	                We;
   input [ADDR_BITS-1 : 0]  IdxW;
   input [WIDTH-1 : 0]      DinW; 

   input 	       clk;
   input 	       rst_n;

   reg [WIDTH-1 : 0]     mem[0 : DEPTH-1];

//   reg 		            forward;
//   reg [WIDTH-1 : 0]    forwardData;
   reg [WIDTH-1 : 0]    sramData;

   integer 	       i;
   
   initial begin
      for(i=0;i<DEPTH;i=i+1) begin
				mem[i]=0;
      end
   end
   
	always @(posedge clk) begin
		sramData <= mem[IdxR];
		//forwardData <= DinW;
		//forward <= We && (IdxR==IdxW);
	end
	//assign DoutR = forward?forwardData:sramData;
	assign DoutR = sramData;

	always @(posedge clk) begin
		/*if(!rst_n) begin
			for(i=0;i<DEPTH;i=i+1) begin
				mem[i]<=0;
			end
		end else*/ begin
			if (We) begin
				mem[IdxW] <= DinW;
			end
		end
	end
endmodule



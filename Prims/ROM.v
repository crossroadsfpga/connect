module ROM (
			      Rd,
			      IdxR,
			      DoutR, 

			      clk,
			      rst_n
		      );

	// synthesis attribute BRAM_MAP of DPSRAM is "yes";

   parameter 	WIDTH = 1;
   parameter    ADDR_BITS = 9;
   parameter	DEPTH = 1<<ADDR_BITS; 
   
   input		    Rd;
   input [ADDR_BITS-1 : 0]  IdxR;
   output [WIDTH-1 : 0]     DoutR; 

   input 	       clk;
   input 	       rst_n;

   reg [WIDTH-1 : 0]     rom[0 : DEPTH-1];

//   reg 		            forward;
//   reg [WIDTH-1 : 0]    forwardData;
   reg [WIDTH-1 : 0]    romData;

   integer 	       i;
   
//   always begin
//     rom[0] = 0;
//     rom[1] = 0;
//     rom[2] = 1;
//     rom[3] = 0;
//   end

     initial begin
       rom[0] = 0;
       rom[1] = 0;
       rom[2] = 1;
       rom[3] = 0;   
     end               
     
     always @(posedge clk) begin
   	  romData <= rom[IdxR];
   	  //forwardData <= DinW;
   	  //forward <= We && (IdxR==IdxW);
     end

   //assign DoutR = forward?forwardData:sramData;
  assign DoutR = romData;

endmodule



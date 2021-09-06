/*
 * =========================================================================
 *
 * Filename:            DPSRAM.bsv
 * Date created:        03-29-2011
 * Last modified:       03-29-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Dual-port memory that efficiently maps to BRAMs. (will infer RAMB18E/RAMB36E primitives)
 * Bluespec BRAMCore package only infers RAMB36E primitives)
 * Requires DPSRAM.v file. (see bottom)
 * 
 */

// Sample instntiation
//interface BRAMTest4;
//    interface DPSRAM#(Bit#(8), Bit#(4096)) bram_ifc;
//endinterface

//(* synthesize *)
//module mkBRAMTest4( BRAMTest4 );
//  
//  DPSRAM#(Bit#(8), Bit#(4096)) bram <- mkDPSRAM();
//  interface bram_ifc = bram;
//
//endmodule

interface DPSRAM#(type index_t, type data_t);
	method Action read(index_t idx_r);
	method data_t value();
	method Action write(index_t idx_w, data_t din_w);	
	//method Action	write( )
endinterface

import "BVI" DPSRAM = 
module mkDPSRAM (DPSRAM#(index_t, data_t))
	provisos(Bits#(data_t, data_width_t),
					 Bits#(index_t, index_width_t),
					 Arith#(index_t),
					 Bounded#(index_t),
					 Literal#(index_t),
					 Eq#(index_t));

	parameter WIDTH	= valueof(data_width_t);
	parameter ADDR_BITS = valueof(index_width_t);

	default_clock( clk );                                                            
	default_reset( rst_n ); 

	schedule (read, value, write) CF (read, value, write);
	/*schedule write CF read;
	schedule write CF write;
	schedule read  CF read;*/

	method read(IdxR)          enable(Rd);
	method DoutR value;
	method write(IdxW, DinW)   enable(We);
endmodule


///////////////////////////////////
// DPSRAM Verilog module
///////////////////////////////////

//module DPSRAM (
//                              Rd,
//                                                IdxR,
//                              DoutR,
//
//                          We,
//                              IdxW,
//                              DinW,
//                                    clk,
//                              rst_n
//                      );
//
//        // synthesis attribute BRAM_MAP of DPSRAM is "yes";
//
//   parameter    WIDTH = 1;
//   parameter    ADDR_BITS = 9;
//   parameter    DEPTH = 1<<ADDR_BITS;
//
//         input                                                                  Rd;
//   input [ADDR_BITS-1 : 0]  IdxR;
//   output [WIDTH-1 : 0] DoutR;
//
//   input                        We;
//   input [ADDR_BITS-1 : 0]  IdxW;
//   input [WIDTH-1 : 0]      DinW;
//
//   input               clk;
//   input               rst_n;
//
//   reg [WIDTH-1 : 0]     mem[0 : DEPTH-1];
//
////   reg                            forward;
////   reg [WIDTH-1 : 0]    forwardData;
//   reg [WIDTH-1 : 0]    sramData;
//
//   integer             i;
//
//   initial begin
//      for(i=0;i<DEPTH;i=i+1) begin
//                                mem[i]=0;
//      end
//   end
//
//        always @(posedge clk) begin
//                sramData <= mem[IdxR];
//                //forwardData <= DinW;
//                //forward <= We && (IdxR==IdxW);
//        end
//        //assign DoutR = forward?forwardData:sramData;
//        assign DoutR = sramData;
//
//        always @(posedge clk) begin
//                /*if(!rst_n) begin
//                        for(i=0;i<DEPTH;i=i+1) begin
//                                mem[i]<=0;
//                        end
//                end else*/ begin
//                        if (We) begin
//                                mem[IdxW] <= DinW;
//                        end
//                end
//        end
//endmodule


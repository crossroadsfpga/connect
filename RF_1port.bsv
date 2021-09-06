/*
 * =========================================================================
 *
 * Filename:            RF_1port.bsv
 * Date created:        05-11-2011
 * Last modified:       05-11-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Single-port register file that efficiently maps to LUT RAM.
 * Requires RegFile_1port.v file. (see bottom)
 * 
 */

import Vector::*;

//////////////////////////////////////////////////////////////////
// Single-port register file implementation that maps to LUT RAM
//////////////////////////////////////////////////////////////////

interface RF_1port#(type index_t, type data_t);
  method Action write(index_t idx_w, data_t din_w);
  method data_t read(index_t idx_r);
endinterface

import "BVI" RegFile_1port =
module mkRF_1port (RF_1port#(index_t, data_t))
        provisos(Bits#(data_t, data_width_t),
                                         Bits#(index_t, index_width_t),
                                         Arith#(index_t),
                                         Bounded#(index_t),
                                         Literal#(index_t),
                                         Eq#(index_t));

        parameter data_width = valueof(data_width_t);
        parameter addr_width  = valueof(index_width_t);

        default_clock( CLK );
        default_reset( rst_n );

        schedule (write, read) CF (write, read);

        method  write(ADDR_IN, D_IN)                enable(WE);
	method  D_OUT read(ADDR_OUT );

endmodule


///////////////////////////////////
// RegFile_16ports Verilog module
///////////////////////////////////

// Multi-ported Register File
//module RegFile_1port(CLK, rst_n,
//               ADDR_IN, D_IN, WE,
//               ADDR_OUT, D_OUT
//               );
//
//   // synopsys template   
//   parameter                   data_width = 1;
//   parameter                   addr_width = 1;
//   parameter                   depth = 1<<addr_width;
//   //parameter                   lo = 0;
//   //parameter                   hi = 1;
//   
//   input                       CLK;
//   input                       rst_n;
//   input [addr_width - 1 : 0]  ADDR_IN;
//   input [data_width - 1 : 0]  D_IN;
//   input                       WE;
//   
//   input [addr_width - 1 : 0]  ADDR_OUT;
//   output [data_width - 1 : 0] D_OUT;
//   
//
//   //reg [data_width - 1 : 0]    arr[lo:hi];
//   reg [data_width - 1 : 0]    arr[0 : depth-1];
//   
//   
////`ifdef BSV_NO_INITIAL_BLOCKS
////`else // not BSV_NO_INITIAL_BLOCKS
////   // synopsys translate_off
////   initial
////     begin : init_block
////        integer                     i; 		// temporary for generate reset value
////        for (i = lo; i <= hi; i = i + 1) begin
////           arr[i] = {((data_width + 1)/2){2'b10}} ;
////        end 
////     end // initial begin   
////   // synopsys translate_on
////`endif // BSV_NO_INITIAL_BLOCKS
//
//
//   always@(posedge CLK)
//     begin
//        if (WE)
//          arr[ADDR_IN] <= `BSV_ASSIGNMENT_DELAY D_IN;
//     end // always@ (posedge CLK)
//
//   assign D_OUT  = arr[ADDR_OUT ];
//
//endmodule


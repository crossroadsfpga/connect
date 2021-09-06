/*
 * =========================================================================
 *
 * Filename:            RF_16ports.bsv
 * Date created:        03-29-2011
 * Last modified:       03-29-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * 16-port register file that efficiently maps to LUT RAM.
 * Unused ports should get pruned out by synthesis tool.
 * Requires RegFile_16ports.v file. (see bottom)
 * 
 */

import Vector::*;

//////////////////////////////////////////////////////////////////
// 16-port register file implementation that maps to LUT RAM
//////////////////////////////////////////////////////////////////

interface RegFileSingleReadPort#(type index_t, type data_t);
  method data_t read(index_t idx_r);
endinterface

interface RF_16ports#(type index_t, type data_t);
  method Action write(index_t idx_w, data_t din_w);
  interface Vector#(16, RegFileSingleReadPort#(index_t, data_t)) read_ports;
endinterface

module mkRF_16ports (RF_16ports#(index_t, data_t))
        provisos(Bits#(data_t, data_width_t),
                                         Bits#(index_t, index_width_t),
                                         Arith#(index_t),
                                         Bounded#(index_t),
                                         Literal#(index_t),
                                         Eq#(index_t));

  Vector#(16, RegFileSingleReadPort#(index_t, data_t)) read_ports_ifaces;
  RegFile_16ports#(index_t, data_t) reg_file <- mkRegFile_16ports();


  for (Integer i=0; i < 16; i=i+1) begin
    let ifc = 
      interface RegFileSingleReadPort#(index_t)
	method data_t read(index_t idx_r);
	  case(i)
	   0: return reg_file.read_0(idx_r);
	   1: return reg_file.read_1(idx_r);
	   2: return reg_file.read_2(idx_r);
	   3: return reg_file.read_3(idx_r);
	   4: return reg_file.read_4(idx_r);
	   5: return reg_file.read_5(idx_r);
	   6: return reg_file.read_6(idx_r);
	   7: return reg_file.read_7(idx_r);
	   8: return reg_file.read_8(idx_r);
	   9: return reg_file.read_9(idx_r);
	   10: return reg_file.read_10(idx_r);
	   11: return reg_file.read_11(idx_r);
	   12: return reg_file.read_12(idx_r);
	   13: return reg_file.read_13(idx_r);
	   14: return reg_file.read_14(idx_r);
	   15: return reg_file.read_15(idx_r);
          endcase
        endmethod
      endinterface;
    read_ports_ifaces[i] = ifc;
  end

  interface read_ports = read_ports_ifaces;

  method Action write(index_t idx_w, data_t din_w);
    reg_file.write(idx_w, din_w);
  endmethod
  
endmodule

////////////////////////////////////////////////////////////////

interface RegFile_16ports#(type index_t, type data_t);
  method Action write(index_t idx_w, data_t din_w);
  method data_t read_0(index_t idx_r);
  method data_t read_1(index_t idx_r);
  method data_t read_2(index_t idx_r);
  method data_t read_3(index_t idx_r);
  method data_t read_4(index_t idx_r);
  method data_t read_5(index_t idx_r);
  method data_t read_6(index_t idx_r);
  method data_t read_7(index_t idx_r);
  method data_t read_8(index_t idx_r);
  method data_t read_9(index_t idx_r);
  method data_t read_10(index_t idx_r);
  method data_t read_11(index_t idx_r);
  method data_t read_12(index_t idx_r);
  method data_t read_13(index_t idx_r);
  method data_t read_14(index_t idx_r);
  method data_t read_15(index_t idx_r);
endinterface

import "BVI" RegFile_16ports =
module mkRegFile_16ports (RegFile_16ports#(index_t, data_t))
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

        schedule (write, read_0, read_1, read_2, read_3, read_4, read_5, read_6, read_7, read_8, read_9, read_10, read_11, read_12, read_13, read_14, read_15) CF (write, read_0, read_1, read_2, read_3, read_4, read_5, read_6, read_7, read_8, read_9, read_10, read_11, read_12, read_13, read_14, read_15);

        method  write(ADDR_IN, D_IN)                enable(WE);
	method D_OUT_1   read_0(ADDR_1 );
	method D_OUT_2   read_1(ADDR_2 );
	method D_OUT_3   read_2(ADDR_3 );
	method D_OUT_4   read_3(ADDR_4 );
	method D_OUT_5   read_4(ADDR_5 );
	method D_OUT_6   read_5(ADDR_6 );
	method D_OUT_7   read_6(ADDR_7 );
	method D_OUT_8   read_7(ADDR_8 );
	method D_OUT_9   read_8(ADDR_9 );
	method D_OUT_10  read_9(ADDR_10);
	method D_OUT_11 read_10(ADDR_11);
	method D_OUT_12 read_11(ADDR_12);
	method D_OUT_13 read_12(ADDR_13);
	method D_OUT_14 read_13(ADDR_14);
	method D_OUT_15 read_14(ADDR_15);
	method D_OUT_16 read_15(ADDR_16);

endmodule


///////////////////////////////////
// RegFile_16ports Verilog module
///////////////////////////////////

// Multi-ported Register File
//module RegFile_16ports(CLK, rst_n,
//               ADDR_IN, D_IN, WE,
//               ADDR_1, D_OUT_1,
//               ADDR_2, D_OUT_2,
//               ADDR_3, D_OUT_3,
//               ADDR_4, D_OUT_4,
//               ADDR_5, D_OUT_5,
//               ADDR_6, D_OUT_6,
//               ADDR_7, D_OUT_7,
//               ADDR_8, D_OUT_8,
//               ADDR_9, D_OUT_9,
//               ADDR_10, D_OUT_10,
//               ADDR_11, D_OUT_11,
//               ADDR_12, D_OUT_12,
//               ADDR_13, D_OUT_13,
//               ADDR_14, D_OUT_14,
//               ADDR_15, D_OUT_15,
//               ADDR_16, D_OUT_16
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
//   input [addr_width - 1 : 0]  ADDR_1;
//   output [data_width - 1 : 0] D_OUT_1;
//   
//   input [addr_width - 1 : 0]  ADDR_2;
//   output [data_width - 1 : 0] D_OUT_2;
//   
//   input [addr_width - 1 : 0]  ADDR_3;
//   output [data_width - 1 : 0] D_OUT_3;
//   
//   input [addr_width - 1 : 0]  ADDR_4;
//   output [data_width - 1 : 0] D_OUT_4;
//   
//   input [addr_width - 1 : 0]  ADDR_5;
//   output [data_width - 1 : 0] D_OUT_5;
//
//   input [addr_width - 1 : 0]  ADDR_6;
//   output [data_width - 1 : 0] D_OUT_6;
//   
//   input [addr_width - 1 : 0]  ADDR_7;
//   output [data_width - 1 : 0] D_OUT_7;
//   
//   input [addr_width - 1 : 0]  ADDR_8;
//   output [data_width - 1 : 0] D_OUT_8;
//   
//   input [addr_width - 1 : 0]  ADDR_9;
//   output [data_width - 1 : 0] D_OUT_9;
//   
//   input [addr_width - 1 : 0]  ADDR_10;
//   output [data_width - 1 : 0] D_OUT_10;
//
//   input [addr_width - 1 : 0]  ADDR_11;
//   output [data_width - 1 : 0] D_OUT_11;
//   
//   input [addr_width - 1 : 0]  ADDR_12;
//   output [data_width - 1 : 0] D_OUT_12;
//   
//   input [addr_width - 1 : 0]  ADDR_13;
//   output [data_width - 1 : 0] D_OUT_13;
//   
//   input [addr_width - 1 : 0]  ADDR_14;
//   output [data_width - 1 : 0] D_OUT_14;
//   
//   input [addr_width - 1 : 0]  ADDR_15;
//   output [data_width - 1 : 0] D_OUT_15;
//
//   input [addr_width - 1 : 0]  ADDR_16;
//   output [data_width - 1 : 0] D_OUT_16;
//   
//   // synthesis attribute ram_style of arr is distributed
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
//   assign D_OUT_1  = arr[ADDR_1 ];
//   assign D_OUT_2  = arr[ADDR_2 ];
//   assign D_OUT_3  = arr[ADDR_3 ];
//   assign D_OUT_4  = arr[ADDR_4 ];
//   assign D_OUT_5  = arr[ADDR_5 ];
//   assign D_OUT_6  = arr[ADDR_6 ];
//   assign D_OUT_7  = arr[ADDR_7 ];
//   assign D_OUT_8  = arr[ADDR_8 ];
//   assign D_OUT_9  = arr[ADDR_9 ];
//   assign D_OUT_10 = arr[ADDR_10];
//   assign D_OUT_11 = arr[ADDR_11];
//   assign D_OUT_12 = arr[ADDR_12];
//   assign D_OUT_13 = arr[ADDR_13];
//   assign D_OUT_14 = arr[ADDR_14];
//   assign D_OUT_15 = arr[ADDR_15];
//   assign D_OUT_16 = arr[ADDR_16];
//
//
//endmodule


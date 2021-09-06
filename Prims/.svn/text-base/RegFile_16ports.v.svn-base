/*
 * =========================================================================
 *
 * Filename:            RegFile_16ports.v
 * Date created:        03-29-2011
 * Last modified:       03-29-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * 16-ported register file that maps to LUT RAM.
 * 
 */

// Multi-ported Register File
module RegFile_16ports(CLK, rst_n,
               ADDR_IN, D_IN, WE,
               ADDR_1, D_OUT_1,
               ADDR_2, D_OUT_2,
               ADDR_3, D_OUT_3,
               ADDR_4, D_OUT_4,
               ADDR_5, D_OUT_5,
               ADDR_6, D_OUT_6,
               ADDR_7, D_OUT_7,
               ADDR_8, D_OUT_8,
               ADDR_9, D_OUT_9,
               ADDR_10, D_OUT_10,
               ADDR_11, D_OUT_11,
               ADDR_12, D_OUT_12,
               ADDR_13, D_OUT_13,
               ADDR_14, D_OUT_14,
               ADDR_15, D_OUT_15,
               ADDR_16, D_OUT_16
               );

   // synopsys template   
   parameter                   data_width = 1;
   parameter                   addr_width = 1;
   parameter                   depth = 1<<addr_width;
   //parameter                   lo = 0;
   //parameter                   hi = 1;
   
   input                       CLK;
   input                       rst_n;
   input [addr_width - 1 : 0]  ADDR_IN;
   input [data_width - 1 : 0]  D_IN;
   input                       WE;
   
   input [addr_width - 1 : 0]  ADDR_1;
   output [data_width - 1 : 0] D_OUT_1;
   
   input [addr_width - 1 : 0]  ADDR_2;
   output [data_width - 1 : 0] D_OUT_2;
   
   input [addr_width - 1 : 0]  ADDR_3;
   output [data_width - 1 : 0] D_OUT_3;
   
   input [addr_width - 1 : 0]  ADDR_4;
   output [data_width - 1 : 0] D_OUT_4;
   
   input [addr_width - 1 : 0]  ADDR_5;
   output [data_width - 1 : 0] D_OUT_5;

   input [addr_width - 1 : 0]  ADDR_6;
   output [data_width - 1 : 0] D_OUT_6;
   
   input [addr_width - 1 : 0]  ADDR_7;
   output [data_width - 1 : 0] D_OUT_7;
   
   input [addr_width - 1 : 0]  ADDR_8;
   output [data_width - 1 : 0] D_OUT_8;
   
   input [addr_width - 1 : 0]  ADDR_9;
   output [data_width - 1 : 0] D_OUT_9;
   
   input [addr_width - 1 : 0]  ADDR_10;
   output [data_width - 1 : 0] D_OUT_10;

   input [addr_width - 1 : 0]  ADDR_11;
   output [data_width - 1 : 0] D_OUT_11;
   
   input [addr_width - 1 : 0]  ADDR_12;
   output [data_width - 1 : 0] D_OUT_12;
   
   input [addr_width - 1 : 0]  ADDR_13;
   output [data_width - 1 : 0] D_OUT_13;
   
   input [addr_width - 1 : 0]  ADDR_14;
   output [data_width - 1 : 0] D_OUT_14;
   
   input [addr_width - 1 : 0]  ADDR_15;
   output [data_width - 1 : 0] D_OUT_15;

   input [addr_width - 1 : 0]  ADDR_16;
   output [data_width - 1 : 0] D_OUT_16;
   
   //reg [data_width - 1 : 0]    arr[lo:hi];
   reg [data_width - 1 : 0]    arr[0 : depth-1];
   
   
//`ifdef BSV_NO_INITIAL_BLOCKS
//`else // not BSV_NO_INITIAL_BLOCKS
//   // synopsys translate_off
//   initial
//     begin : init_block
//        integer                     i; 		// temporary for generate reset value
//        for (i = lo; i <= hi; i = i + 1) begin
//           arr[i] = {((data_width + 1)/2){2'b10}} ;
//        end 
//     end // initial begin   
//   // synopsys translate_on
//`endif // BSV_NO_INITIAL_BLOCKS

// initialize
   integer 	       i;
   initial begin
      for(i=0;i<depth;i=i+1) begin
	 arr[i]=0;
      end
   end

   always@(posedge CLK)
     begin
        if (WE)
          arr[ADDR_IN] <= `BSV_ASSIGNMENT_DELAY D_IN;
     end // always@ (posedge CLK)

   assign D_OUT_1  = arr[ADDR_1 ];
   assign D_OUT_2  = arr[ADDR_2 ];
   assign D_OUT_3  = arr[ADDR_3 ];
   assign D_OUT_4  = arr[ADDR_4 ];
   assign D_OUT_5  = arr[ADDR_5 ];
   assign D_OUT_6  = arr[ADDR_6 ];
   assign D_OUT_7  = arr[ADDR_7 ];
   assign D_OUT_8  = arr[ADDR_8 ];
   assign D_OUT_9  = arr[ADDR_9 ];
   assign D_OUT_10 = arr[ADDR_10];
   assign D_OUT_11 = arr[ADDR_11];
   assign D_OUT_12 = arr[ADDR_12];
   assign D_OUT_13 = arr[ADDR_13];
   assign D_OUT_14 = arr[ADDR_14];
   assign D_OUT_15 = arr[ADDR_15];
   assign D_OUT_16 = arr[ADDR_16];


endmodule


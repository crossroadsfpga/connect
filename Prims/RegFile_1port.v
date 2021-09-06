///////////////////////////////////
// RegFile_1ports Verilog module
///////////////////////////////////

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

// Multi-ported Register File
//(* ram_style = "distributed" *)
//(* ram_extract = "no" *)
module RegFile_1port(CLK, rst_n,
               ADDR_IN, D_IN, WE,
               ADDR_OUT, D_OUT
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
   
   input [addr_width - 1 : 0]  ADDR_OUT;
   output [data_width - 1 : 0] D_OUT;

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


   always@(posedge CLK)
     begin
        if (WE)
          arr[ADDR_IN] <= `BSV_ASSIGNMENT_DELAY D_IN;
     end // always@ (posedge CLK)

   assign D_OUT  = arr[ADDR_OUT ];

endmodule


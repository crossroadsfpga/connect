module RegFileLoadSyn
		  (CLK, RST_N,
                   ADDR_IN, D_IN, WE,
                   ADDR_1, D_OUT_1
                   );

   parameter                   file = "";
   parameter                   addr_width = 1;
   parameter                   data_width = 1;
   parameter                   lo = 0;
   parameter                   hi = 1;
   parameter                   binary = 0;
   
   input                       CLK;
   input                       RST_N;
   input [addr_width - 1 : 0]  ADDR_IN;
   input [data_width - 1 : 0]  D_IN;
   input                       WE;
   
   input [addr_width - 1 : 0]  ADDR_1;
   output [data_width - 1 : 0] D_OUT_1;
   
   reg [data_width - 1 : 0]    arr[lo:hi];
   
   initial
     begin : init_block
           $readmemh(file, arr, lo, hi);
     end

   always@(posedge CLK)
     begin
        if (WE && RST_N)
          arr[ADDR_IN] <= D_IN;
     end // always@ (posedge CLK)

   assign D_OUT_1 = arr[ADDR_1];

endmodule

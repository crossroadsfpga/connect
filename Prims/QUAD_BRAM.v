/**
 *
 * Copyright (c) 2006-2008 The University of Texas All Rights Reserved.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 * 
 * The GNU Public License is available in the file LICENSE, or you can
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA, or you can find it on the World Wide Web at
 * http://www.fsf.org.
 * 
 * Authors: Eric Johnson, and Prof. Derek Chiou
 * 
 * The authors are with the Department of Electrical and Computer Engineering,
 * The University of Texas at Austin, Austin, TX 78712 USA.
 * 
 * They can be reached at dejohnso@ece.utexas.edu, derek@ece.utexas.edu
 * 
 * More information about related work can be found at
 * http://users.ece.utexas.edu/~derek/FAST.html
 * 
 **/


module dual_ported_bram (clka, clkb, ena, enb, wea, web, addra, addrb, dia, dib, doa, dob);

   parameter DATA_WIDTH = 36;
   parameter ADDR_WIDTH = 9;
   parameter DEPTH = 1 << ADDR_WIDTH;
   
   input clka, clkb, ena, enb, wea, web;
   input [ADDR_WIDTH-1:0] addra, addrb;
   input [DATA_WIDTH-1:0] 	  dia, dib;
   output [DATA_WIDTH-1:0] 	  doa, dob;
   reg [DATA_WIDTH-1:0] 	  ram [DEPTH-1:0];
   reg [DATA_WIDTH-1:0] 	  doa, dob;
   
   always @(posedge clka) begin
      if (ena) begin
	 if (wea)
	   ram[addra] <= dia;
	 doa <= ram[addra];
      end
   end

   always @(posedge clkb) begin
      if (enb) begin
	 if (web)
	   ram[addrb] <= dib;
	 dob <= ram[addrb];
      end
   end

endmodule

module BRAM (CLK, RST_N, RD_ADDRA, RD_ADDRB, REA, REB, WR_ADDRA, WR_ADDRB, WEA, WEB, DIA, DIB, DOA, DOB);

   parameter DATA_WIDTH = 36;
   parameter ADDR_WIDTH = 9;
   parameter DEPTH = 1 << ADDR_WIDTH;

   input     CLK, RST_N;
   input     REA, REB;
   input     WEA, WEB;
   input [ADDR_WIDTH-1:0] RD_ADDRA, RD_ADDRB;
   input [ADDR_WIDTH-1:0] WR_ADDRA, WR_ADDRB;
   input [DATA_WIDTH-1:0] DIA, DIB;
   output [DATA_WIDTH-1:0] DOA, DOB;

   wire 		  CLK, RST_N;
   wire 		  REA, REB;
   wire 		  WEA, WEB;
   wire [ADDR_WIDTH-1:0]  RD_ADDRA, RD_ADDRB;
   wire [ADDR_WIDTH-1:0]  WR_ADDRA, WR_ADDRB;
   wire [DATA_WIDTH-1:0]  DIA, DIB;
   wire [DATA_WIDTH-1:0]  DOA, DOB;

   wire 		  ENA, ENB;
   wire [ADDR_WIDTH-1:0]  ADDRA, ADDRB;

   assign 		  ENA = 1;
   assign 		  ENB = 1;

   assign 		  ADDRA = (WEA) ? WR_ADDRA : RD_ADDRA;
   assign 		  ADDRB = (WEB) ? WR_ADDRB : RD_ADDRB;
   
   dual_ported_bram #(.DATA_WIDTH(DATA_WIDTH),
		      .ADDR_WIDTH(ADDR_WIDTH),
		      .DEPTH(DEPTH)) ram(CLK, CLK, ENA, ENB, WEA, WEB, ADDRA, ADDRB, DIA, DIB, DOA, DOB);
   
endmodule

module QUAD_BRAM (CLK, CLK2X, RST_N, RD_ADDRA, RD_ADDRB, RD_ADDRC, RD_ADDRD, REA, REB, REC, RED, WR_ADDRA, WR_ADDRB, WR_ADDRC, WR_ADDRD, WEA, WEB, WEC, WED, DIA, DIB, DIC, DID, DOA, DOB, DOC, DOD);

   parameter DATA_WIDTH = 36;
   parameter ADDR_WIDTH = 9;
   parameter DEPTH = 1 << ADDR_WIDTH;

   input     CLK, CLK2X, RST_N;
   input     REA, REB, REC, RED;
   input     WEA, WEB, WEC, WED;
   input [ADDR_WIDTH-1:0] RD_ADDRA, RD_ADDRB, RD_ADDRC, RD_ADDRD;
   input [ADDR_WIDTH-1:0] WR_ADDRA, WR_ADDRB, WR_ADDRC, WR_ADDRD;
   input [DATA_WIDTH-1:0] 	  DIA, DIB, DIC, DID;
   output [DATA_WIDTH-1:0] 	  DOA, DOB, DOC, DOD;

   //wire versions of inputs and outputs
   wire     CLK, CLK2X, RST_N;
   wire     REA, REB, REC, RED;
   wire     WEA, WEB, WEC, WED;
   wire [ADDR_WIDTH-1:0] RD_ADDRA, RD_ADDRB, RD_ADDRC, RD_ADDRD;
   wire [ADDR_WIDTH-1:0] WR_ADDRA, WR_ADDRB, WR_ADDRC, WR_ADDRD;
   wire [DATA_WIDTH-1:0] 	  DIA, DIB, DIC, DID;
   reg [DATA_WIDTH-1:0] 	  DOA, DOB, DOC, DOD;

   //create some intermediate wires
   wire [DATA_WIDTH-1:0] 	  DI_A, DI_B;
   wire [DATA_WIDTH-1:0]        DO_A, DO_B;
   wire 		  WE_A, WE_B;
   wire 		  EN_A,EN_B;
   wire [ADDR_WIDTH-1:0]  ADDRA, ADDRB, ADDRC, ADDRD, ADDR_A, ADDR_B;

   assign 		  EN_A = 1;
   assign 		  EN_B = 1;
   assign 		  DI_A = (CLK) ? DIA : DIC;
   assign 		  DI_B = (CLK)? DIB : DID;
   assign 		  WE_A = (CLK) ? WEA : WEC;
   assign 		  WE_B = (CLK) ? WEB : WED;

   assign 		  ADDRA = (WEA) ? WR_ADDRA : RD_ADDRA;
   assign 		  ADDRB = (WEB) ? WR_ADDRB : RD_ADDRB;
   assign 		  ADDRC = (WEC) ? WR_ADDRC : RD_ADDRC;
   assign 		  ADDRD = (WED) ? WR_ADDRD : RD_ADDRD;
   
   assign 		  ADDR_A = (CLK) ? ADDRA : ADDRC;
   assign 		  ADDR_B = (CLK) ? ADDRB : ADDRD;

   always @(posedge CLK) begin
      DOA <= DO_A;
      DOB <= DO_B;
   end
   always @(negedge CLK) begin
      DOC <= DO_A;
      DOD <= DO_B;
   end

   dual_ported_bram #(.DATA_WIDTH(DATA_WIDTH),
		      .ADDR_WIDTH(ADDR_WIDTH),
		      .DEPTH(DEPTH)) ram(CLK2X,CLK2X,EN_A,EN_B,WE_A,WE_B,ADDR_A,ADDR_B,DI_A,DI_B,DO_A,DO_B);

endmodule


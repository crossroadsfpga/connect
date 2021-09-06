import Vector::*;
interface XbarVerilog#(numeric type n, 
                       numeric type nvc, 
		       numeric type cut,
		       numeric type dwidth,
		       numeric type buffer_depth);

    (* always_ready *)
    method Action iports(Vector#(n, Bool) i_valid,
		         Vector#(n, Bool) i_prio,
			 Vector#(n, Bool) i_tail,
			 Vector#(n, Bit#(TLog#(n))) i_dst,
			 Vector#(n, Bit#(TLog#(nvc))) i_vc,
			 Vector#(n, Bit#(dwidth)) i_data);

    (* always_ready *) method Vector#(n, Bool) o_valid;
    (* always_ready *) method Vector#(n, Bool) o_prio;
    (* always_ready *) method Vector#(n, Bool) o_tail;
    (* always_ready *) method Vector#(n, Bit#(TLog#(n))) o_dst;
    (* always_ready *) method Vector#(n, Bit#(TLog#(nvc))) o_vc;
    (* always_ready *) method Vector#(n, Bit#(dwidth)) o_data;

    (* always_ready *) method Vector#(n, Bit#(TLog#(nvc))) i_cred;
    (* always_ready *) method Vector#(n, Bool) i_cred_valid;
    (* always_ready *) method Action o_cred(Vector#(n, Bool) en);

endinterface

import "BVI" Xbar = module mkXbarVerilog(XbarVerilog#(n, nvc, cut, dwidth, buffer_depth));

    default_clock clk(CLK, (*unused*) clk_gate);

    parameter N		    = fromInteger(valueOf(n));
    parameter NUM_VCS	    = fromInteger(valueOf(nvc));
    parameter CUT	    = fromInteger(valueOf(cut));
    parameter DATA	    = fromInteger(valueOf(dwidth));
    parameter BUFFER_DEPTH  = fromInteger(valueOf(buffer_depth));

    method iports(i_valid, i_prio, i_tail, i_dst, i_vc, i_data) enable((*inhigh*)True);
    method o_valid o_valid;
    method o_prio o_prio;
    method o_tail o_tail;
    method o_dst o_dst;
    method o_vc o_vc;
    method o_data o_data;
    method i_cred i_cred;
    method i_cred_valid i_cred_valid;
    method o_cred(o_cred_en) enable((*inhigh*)True2);

    schedule (iports, o_valid, o_prio, o_tail, o_dst, o_vc, o_data, i_cred, i_cred_valid, o_cred) CF
             (iports, o_valid, o_prio, o_tail, o_dst, o_vc, o_data, i_cred, i_cred_valid, o_cred);

endmodule

/*
(* synthesize *)
module mkXbarVerilogSynth(XbarVerilog#(4,2,1,32,16));
    let xbar <- mkXbarVerilog;
    return xbar;
endmodule
*/

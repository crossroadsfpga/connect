/* =========================================================================
 *
 * Filename:            RouterTb.bsv
 * Date created:        06-08-2011
 * Last modified:       06-08-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Router Testbench module. Also includes synthesizable template.
 *
 * =========================================================================
 */

`include "inc.v"
import Router::*;
import NetworkTypes::*;
import StmtFSM::*;   // for testbench

//////////////////////////////////////////////////////////
// VCRouter_multi_flit_bufs Testbench
(* synthesize *)
module mkRouterTb(Empty);
  String name = "mkRouterTb";
  Reg#(Bit#(64)) cycles <- mkReg(0);
  Reg#(Bit#(64)) total_cycles <- mkReg(20);
  Router r <- mkRouter(4);
  Integer test_cycles = 20;

  // Functions for sending flits/credits
  function Action sendFlit(InPort inp, Maybe#(Flit_t) fl);
    action inp.putFlit(fl); endaction
  endfunction

  function Action sendCredits(OutPort outp, Credit_t cr);
    action outp.putCredits(cr); endaction
  endfunction

  function Action printFlit(Flit_t fl);
    //$display("-->Flit {dst:%0d, vc:%0d, is_tail:%0d}", fl.dst, fl.vc, fl.is_tail);
    $display("-->Flit {dst:%0d, vc:%0d}", fl.dst, fl.vc);
  endfunction
  
  rule countCycle(True);
    cycles<=cycles+1;
    if(cycles >= total_cycles) $finish(0);
    //$display("------------------------------------------------<%0d>",cycles);
  endrule

  // Stmts for scanning flits and credits at out_ports/in_ports
  Stmt scan_outports = seq
    action
      `BLUE;
      $display("--------------------------- Start of cycle -------------------------------------<%0d>",cycles);
      `WHITE;
      for(Integer o=0; o < valueOf(NumOutPorts); o=o+1) begin
	let fl <- r.out_ports[o].getFlit();
	if(isValid(fl)) begin
	  `DBG(("[%0d] Read Flit (data:%x) on out_port %0d", cycles, fl.Valid.data, o));
	  //printFlit(fl.Valid);
	end else begin
	  //`DBG(("[%0d] No Flit on out_port %d", cycles, o));
	end
      end
    endaction
  endseq;

  Stmt scan_credits = seq
    action
      for(Integer i=0; i < valueOf(NumInPorts); i=i+1) begin
	let cr <- r.in_ports[i].getCredits();
	if(isValid(cr)) begin
	  `DBG(("[%0d] Upstream credits from input %0d for VC:%0d", cycles, i, cr.Valid));
	end
      end
    endaction
  endseq;

  Stmt scan_outputs = par
    scan_outports;
    scan_credits;
  endpar;

  ////////////////////////////////////////
  // Test sequence

  Stmt test_seq = seq

    par
      //`DBG(("Sending Flits -------------------------------------<%0d>",cycles));
      sendFlit(r.in_ports[2], tagged Valid Flit_t{is_tail:True, data:32'hbbbbbbb0, dst:3, vc:1} );
      sendFlit(r.in_ports[3], tagged Valid Flit_t{is_tail:False, data:32'haaaaaaa0, dst:0, vc:1} );
      //sendFlit(mcr.in_ports[3], tagged Valid Flit_t{is_tail:False, dst:2, vc:0} );
      scan_outputs;
    endpar
    par
      sendFlit(r.in_ports[0], tagged Valid Flit_t{is_tail:True, data:32'hccccccc0, dst:2, vc:1} );
      //sendFlit(r.in_ports[1], tagged Valid Flit_t{is_tail:True, data:0, dst:1, vc:1} );
      sendCredits(r.out_ports[3], tagged Valid fromInteger(1));
      //sendFlit(mcr.in_ports[3], tagged Valid Flit_t{is_tail:False, dst:2, vc:0} );
      scan_outputs;
    endpar
    par
      sendFlit(r.in_ports[3], tagged Valid Flit_t{is_tail:False, data:32'haaaaaaa1, dst:0, vc:1} );
      sendFlit(r.in_ports[2], tagged Valid Flit_t{is_tail:True, data:32'hddddddd0, dst:3, vc:0} );
      scan_outputs;
      sendCredits(r.out_ports[1], tagged Valid fromInteger(1));
    endpar

    par
      sendFlit(r.in_ports[3], tagged Valid Flit_t{is_tail:True, data:32'haaaaaaa2, dst:0, vc:1} );
      scan_outputs;
    endpar

    scan_outputs;
    scan_outputs;
    scan_outputs;
    scan_outputs;
    scan_outputs;
    scan_outputs;


//    noAction;
    noAction;
    //while(True) noAction;
  endseq;


//  Stmt test_seq = seq
//
//    par
//      `DBG(("Sending Flits -------------------------------------<%0d>",cycles));
//      sendFlit(r.in_ports[1], tagged Valid Flit_t{is_tail:True, data:0, dst:1, vc:1} );
//      //sendFlit(mcr.in_ports[3], tagged Valid Flit_t{is_tail:False, dst:2, vc:0} );
//      scan_outputs;
//    endpar
//    par
//      `DBG(("Sending Flits -------------------------------------<%0d>",cycles));
//      sendFlit(r.in_ports[1], tagged Valid Flit_t{is_tail:True, data:0, dst:1, vc:1} );
//      sendCredits(r.out_ports[1], tagged Valid fromInteger(1));
//      //sendFlit(mcr.in_ports[3], tagged Valid Flit_t{is_tail:False, dst:2, vc:0} );
//      scan_outputs;
//    endpar
//    par
//      sendCredits(r.out_ports[1], tagged Valid fromInteger(1));
//    endpar
//
//    scan_outputs;
//    $display("test %d", cycles);
//    scan_outputs;
//    $display("test %d", cycles);
//    scan_outputs;
//    $display("test %d", cycles);
//    scan_outputs;
//    $display("test %d", cycles);
//    scan_outputs;
//
//    noAction;
//    noAction;
//    noAction;
//    noAction;
//    noAction;
//    noAction;
//    noAction;
//    noAction;
//    noAction;
//    noAction;
//    noAction;
//    //while(True) noAction;
//  endseq;
  
  mkAutoFSM(test_seq);

endmodule

////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////
// Router for synthesis
// VCRouter_multi_flit_bufs for Synthesis test
(* synthesize *)
//module mkVCRouter_multi_flit_bufs_Synth(Router);
module mkRouterSynth(Router);
  Router r_ifc <- mkRouter(0);
  return r_ifc;
endmodule



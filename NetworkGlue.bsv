/* =========================================================================
 *
 * Filename:            NetworkGlue.bsv
 * Date created:        04-23-2011
 * Last modified:       04-23-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Module to connect routers with other routers.
 * 
 * =========================================================================
 */

import NetworkTypes::*;
import Router::*;
`include "inc.v"

////////////////////////////////////////////////////////////////////////
// ConnectPorts Interface
// Interface is only used to check activity for termination condition
////////////////////////////////////////////////////////////////////////
interface ConnectPorts;
  method Bool saw_activity();
endinterface

module mkConnectPorts#(Router r_out, Integer port_out, Router r_in, Integer port_in)(ConnectPorts);
  ConnectPorts connectPorts_ifc;
  if (`PIPELINE_LINKS) begin
    connectPorts_ifc <- mkConnectPorts_wReg(r_out, port_out, r_in, port_in);
  end else begin
    connectPorts_ifc <- mkConnectPorts_noReg(r_out, port_out, r_in, port_in);
  end
  return connectPorts_ifc;
endmodule


module mkConnectPorts_noReg#(Router r_out, Integer port_out, Router r_in, Integer port_in)(ConnectPorts);

  PulseWire                flits_activity       <- mkPulseWire();
  PulseWire                credits_activity     <- mkPulseWireOR();


  (* fire_when_enabled *)
  rule makeFlitLink(True);
    let out_port_ifc = r_out.out_ports[port_out];
    let in_port_ifc = r_in.in_ports[port_in];
    let fl <- out_port_ifc.getFlit();
    in_port_ifc.putFlit(fl); //  _ifc.put(r0_ifc.get);
    if(isValid(fl)) begin 
      flits_activity.send();
    end
  endrule

  (* fire_when_enabled *)
  rule makeCreditLink(True);
    let out_port_ifc = r_out.out_ports[port_out];
    let in_port_ifc = r_in.in_ports[port_in];
    let cr <- in_port_ifc.getCredits();
    out_port_ifc.putCredits(cr);
    if(isValid(cr)) begin
      credits_activity.send();
    end
  endrule

  method Bool saw_activity();
    //return (flits_activity || credits_activity);
    return (flits_activity);
  endmethod
endmodule


// Only offers very minor frequency improvement 
module mkConnectPorts_wReg#(Router r_out, Integer port_out, Router r_in, Integer port_in)(ConnectPorts);

  PulseWire                flits_activity       <- mkPulseWire();
  PulseWire                credits_activity     <- mkPulseWireOR();
  
  Reg#(Credit_t)           credit_reg           <- mkReg(Invalid);
  Reg#(Maybe#(Flit_t))     fl_reg               <- mkReg(Invalid);


  (* fire_when_enabled *)
  rule makeFlitLink(True);
    let out_port_ifc = r_out.out_ports[port_out];
    let in_port_ifc = r_in.in_ports[port_in];
    let fl <- out_port_ifc.getFlit();
    fl_reg <= fl;
    in_port_ifc.putFlit(fl_reg); //  _ifc.put(r0_ifc.get);
    if(isValid(fl)) begin 
      flits_activity.send();
    end
  endrule

  (* fire_when_enabled *)
  rule makeCreditLink(True);
    let out_port_ifc = r_out.out_ports[port_out];
    let in_port_ifc = r_in.in_ports[port_in];
    let cr <- in_port_ifc.getCredits();
    credit_reg <= cr;
    out_port_ifc.putCredits(credit_reg);
    if(isValid(cr)) begin
      credits_activity.send();
    end
  endrule

  method Bool saw_activity();
    //return (flits_activity || credits_activity);
    return (flits_activity);
  endmethod
endmodule




////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////
// Older Code
/////////////////////////////////////////////////////


//module connectPortsOld#(MCRouter r_out, Integer port_out, MCRouter r_in, Integer port_in)(Empty);
//
//  (* fire_when_enabled *)
//  rule makeFlitLink(True);
//    let out_port_ifc = r_out.out_ports[port_out];
//    let in_port_ifc = r_in.in_ports[port_in];
//    let fl <- out_port_ifc.getFlit();
//    in_port_ifc.putFlit(fl); //  _ifc.put(r0_ifc.get);
//  endrule
//
//  (* fire_when_enabled *)
//  rule makeCreditLink(True);
//    let out_port_ifc = r_out.out_ports[port_out];
//    let in_port_ifc = r_in.in_ports[port_in];
//    let cr <- in_port_ifc.getCredits();
//    out_port_ifc.putCredits(cr);
//    //if (isValid(cr)) begin
//    //  `DBG_REF(("--------> Credits from in_port %0d to out_port %0d for vc %0d", port_in, port_out, cr.Valid));
//    //end
//    //in_port_ifc.putFlit(out_port_ifc.getFlit()); //  _ifc.put(r0_ifc.get);
//  endrule
//
//endmodule


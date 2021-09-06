/* =========================================================================
 *
 * Filename:            NetworkGlueSimple.bsv
 * Date created:        09-18-2011
 * Last modified:       09-18-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Module to connect routers with other routers.
 * 
 * =========================================================================
 */

`include "inc.v"
import NetworkTypes::*;
//import RouterSimple::*;
import Vector::*;

`ifdef USE_VOQ_ROUTER
  import VOQRouterSimple::*;
`elsif USE_IQ_ROUTER
  import IQRouterSimple::*;
`else
  import RouterSimple::*;
`endif


////////////////////////////////////////////////////////////////////////
// ConnectPorts Interface
// Interface is only used to check activity for termination condition
////////////////////////////////////////////////////////////////////////
interface ConnectPorts;
  method Bool saw_activity();
endinterface

module mkConnectPorts#(RouterSimple r_out, Integer port_out, RouterSimple r_in, Integer port_in)(ConnectPorts);
  ConnectPorts connectPorts_ifc;
  if (`PIPELINE_LINKS) begin
    connectPorts_ifc <- mkConnectPorts_wReg(r_out, port_out, r_in, port_in);
  end else begin
    connectPorts_ifc <- mkConnectPorts_noReg(r_out, port_out, r_in, port_in);
  end
  return connectPorts_ifc;
endmodule


module mkConnectPorts_noReg#(RouterSimple r_out, Integer port_out, RouterSimple r_in, Integer port_in)(ConnectPorts);

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
    let cr <- in_port_ifc.getNonFullVCs();
    out_port_ifc.putNonFullVCs(cr);
  endrule

  method Bool saw_activity();
    return (flits_activity);
  endmethod
endmodule


// Only offers very minor frequency improvement 
module mkConnectPorts_wReg#(RouterSimple r_out, Integer port_out, RouterSimple r_in, Integer port_in)(ConnectPorts);

  PulseWire                flits_activity       <- mkPulseWire();
  PulseWire                credits_activity     <- mkPulseWireOR();
  
  Reg#(Vector#(NumVCs, Bool))  credit_reg       <- mkReg(unpack(0));
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
    let cr <- in_port_ifc.getNonFullVCs();
    credit_reg <= cr;
    out_port_ifc.putNonFullVCs(credit_reg);
  endrule

  method Bool saw_activity();
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


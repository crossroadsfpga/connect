/* =========================================================================
 *
 * Filename:            NetworkSimple.bsv
 * Date created:        09-19-2011
 * Last modified:       09-19-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Top-level module that instantinates and connects routers to implement 
 * the entire network. Exposes InPort/OutPort interfaces to hook up the nodes
 * that are will be connected to the network.
 * 
 * =========================================================================
 */

`include "inc.v"

import Assert::*;
import ConfigReg::*;
import Vector::*;
import BRAMFIFO::*;
import FIFOF::*;
//import Clocks::*;
import NetworkTypes::*;

`ifdef IDEAL
  import NetworkIdeal::*;
`else
  import NetworkGlueSimple::*;
  `ifdef USE_VOQ_ROUTER
    import VOQRouterSimple::*;
  `elsif USE_IQ_ROUTER
    import IQRouterSimple::*;
  `else
    import RouterSimple::*;
  `endif
`endif


(* synthesize *)
module mkNetworkSimple(NetworkSimple);
`ifdef IDEAL
    let net <- mkNetworkIdealSimple();
`else
    let net <- mkNetworkRealSimple();
`endif
    return net;
endmodule


`ifndef IDEAL

module mkNetworkRealSimple(NetworkSimple);

  String name = "Simple Network";

  // Vector of input and output interfaces to connect network clients
  Vector#(NumUserSendPorts, InPortSimple)  send_ports_ifaces;
  Vector#(NumUserRecvPorts, OutPortSimple) recv_ports_ifaces;
  Vector#(NumUserRecvPorts, RecvPortInfo) recv_ports_info_ifaces;
  //Vector#(NumRouters, RouterInfo) router_info_ifaces;
  
  function get_rt( Integer i );
  `ifdef USE_VOQ_ROUTER
      return mkVOQRouterSimple(i); 
  `elsif USE_IQ_ROUTER
      return mkIQRouterSimple(i); 
  `else
      return mkRouterSimple(i);
  `endif
  endfunction
  
  function get_port_info_ifc( Integer id );
    let recv_port_info_ifc =
      interface RecvPortInfo
        method UserRecvPortID_t getRecvPortID;
          return fromInteger(id);
	endmethod
      endinterface;
    return recv_port_info_ifc;
  endfunction

//  function get_router_info_ifc( Integer id );
//    let router_info_ifc =
//      interface RouterInfo
//        method RouterID_t getRouterID;
//        //method UserPortID_t getRouterID;
//          return fromInteger(id);
//	endmethod
//      endinterface;
//    return router_info_ifc;
//  endfunction



  // Declare router and traffic source interfaces
  Vector#(NumRouters, RouterSimple)            routers <- genWithM( get_rt );
  //Vector#(NumRouters, RouterSimple)            routers;
  Vector#(NumLinks, ConnectPorts)        links;

  /////////////////////////////////////////////////
  // Include the generated "links" file here
  /////////////////////////////////////////////////
  // Make connections between routers
  `include `NETWORK_LINKS_FILE
 
  //`include "conf_links.bsv"
  //`include "net_configs/n1.txt.links.bsv"

  // TODO: Let gen_network.py create this
  // Expose InPort and OutPort interfaces to be used by network clients
  for(Integer r = 0; r< valueOf(NumRouters); r=r+1) begin
    //send_ports_ifaces[r]  = routers[r].in_ports[0];
    //recv_ports_ifaces[r]  = routers[r].out_ports[0];
    //router_info_ifaces[r] = routers[r].rt_info;
    //user_port_info_ifaces[r] = get_port_info_ifc(r);
    //router_info_ifaces[r] = get_router_info_ifc(r);
  end

//  if(NumLinks > 0) begin
//    rule printLinkUtil(`DUMP_LINK_UTIL);
//      //cycle_count <= cycle_count + 1;
//      for(Integer l = 0; l < valueOf(NumLinks); l=l+1) begin
//	if(links[l].saw_activity()) begin
//	  $display("strace noc_link:%0d evt:saw_activity", l);
//	end
//	//link_util_counters[l] <= link_util_counters[l] + 1;
//      end
//    endrule
//  end

  interface send_ports  = send_ports_ifaces;
  interface recv_ports  = recv_ports_ifaces;
  //interface router_info = router_info_ifaces; 
  interface recv_ports_info = recv_ports_info_ifaces; 

endmodule

`endif

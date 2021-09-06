/* =========================================================================
 *
 * Filename:            NetworkSimpleTb.bsv
 * Date created:        09-19-2012
 * Last modified:       09-22-2012
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Simple testbench for NetworkSimple.  
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

//`ifdef USE_VOQ_ROUTER
//  import VOQRouterSimple::*;
//`else
//  import RouterSimple::*;
//`endif

import NetworkGlueSimple::*;
import NetworkSimple::*;
import StmtFSM::*;			// just for creating a test sequence
import FShow::*;


module mkNetworkSimpleTb(Empty);
  String name = "NetworkSimpleTb ";
  // instantiate network
  NetworkSimple net <- mkNetworkSimple();

  Reg#(Bit#(32)) cycle <- mkConfigReg(0);

  (* no_implicit_conditions *)
  rule cycle_count(True);
    $display("[cycle %08d] ----------------------------------------------- ", cycle);
    //for(Integer r=0; r < valueOf(NumRouters); r=r+1) begin
    //  $write(" %0d", credits[r][0]);
    //end
    //$write("\n");
    cycle <= cycle + 1;
  endrule

  // 
  (* fire_when_enabled *)
  //rule printstats (cycle == fromInteger(valueOf(NumCyclesToTest)));
  rule printstats (True);
    Bit#(64) total_delay = unpack(0);
    Bit#(64) total_pkt_cnt = unpack(0);
    for(Integer r=0; r < valueOf(NumUserRecvPorts); r=r+1) begin
      let fl <- net.recv_ports[r].getFlit();
      if(isValid(fl)) begin
        $display("RecvPort:",r," Incoming Flit:",fshow(fl.Valid));
      end

      // don't provide credits to test backpressure!
      //net.recv_ports[r].putNonFullVCs(unpack(0));

      //$display("router %0d delay_sum %0d pkt_cnt %0d", r, delay_sum[r], pkt_cnt[r]);
      //total_delay = total_delay + extend(delay_sum[r]);
      //total_pkt_cnt = total_pkt_cnt + extend(pkt_cnt[r]);
    end

    for(Integer s=0; s < valueOf(NumUserSendPorts); s=s+1) begin
      let nonFullVCs <- net.send_ports[s].getNonFullVCs();
      if(!nonFullVCs[0]) begin // some port is full
	$display("SendPort:",s," input buffer full!");
      end

      //$display("router %0d delay_sum %0d pkt_cnt %0d", r, delay_sum[r], pkt_cnt[r]);
      //total_delay = total_delay + extend(delay_sum[r]);
      //total_pkt_cnt = total_pkt_cnt + extend(pkt_cnt[r]);
    end
    
    //$display("total_delay_sum %0d total_pkt_cnt %0d", total_delay, total_pkt_cnt);
  endrule



  function Action sendFlit(UserSendPortID_t src, UserRecvPortID_t dst, Bool is_tail, VC_t vc, FlitData_t data);
    action
      Maybe#(Flit_t) fl = tagged Valid Flit_t{is_tail:is_tail, dst:dst, vc:vc, data:data};
      $display("SendPort ",src," is sending Flit: ",fshow(fl));
      net.send_ports[src].putFlit(fl);

      // Don't provide credits
      //for(Integer r=0; r < valueOf(NumUserRecvPorts); r=r+1) begin
      //  net.recv_ports[r].putNonFullVCs(unpack(0));
      //end

    endaction
  endfunction

  function Action noCredits();
    action
      for(Integer r=0; r < valueOf(NumUserRecvPorts); r=r+1) begin
        net.recv_ports[r].putNonFullVCs(unpack(0));
      end
    endaction
  endfunction

  rule provideCredits(True);
    // provide credits
    for(Integer r=0; r < valueOf(NumUserRecvPorts); r=r+1) begin
      net.recv_ports[r].putNonFullVCs(unpack(1));
    end
  endrule

  Stmt fsm = seq
    action
      //sendFlit(0,0,True,0,00000000);
      //sendFlit(1,1,True,0,11000000);
      //noCredits();
      //sendFlit(2,2,True,0,22000000);
      //sendFlit(3,3,True,0,33000000);
      //net.send_ports[0].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd0), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[1].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[2].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd2), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[3].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd3), vc:truncate(64'd0), data:unpack(0)} );
      $display("Pipeline Stages: %d", getPipeLineStages());
    endaction
    action
      sendFlit(0,1,True,0,01000000);
      //sendFlit(2,9,True,0,29000000);
      //net.send_ports[0].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[1].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[2].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[3].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
    endaction
    action
      sendFlit(0,1,True,0,01000001);
      //net.send_ports[0].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[1].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[2].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[3].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
    endaction
    action
      sendFlit(0,1,True,0,01000002);
      //net.send_ports[0].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[1].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[2].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[3].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
    endaction
      sendFlit(0,1,True,0,01000003);
      sendFlit(0,1,True,0,01000004);
      sendFlit(0,1,True,0,01000005);
      sendFlit(0,1,True,0,01000006);
      sendFlit(0,1,True,0,01000007);
      //sendFlit(0,1,True,0,01000008);
      //sendFlit(0,1,True,0,0);
      //sendFlit(0,1,True,0,0);
      //sendFlit(0,1,True,0,0);
      //sendFlit(0,1,True,0,0);
      //sendFlit(0,1,True,0,0);
      repeat (50)     
      action 
      noAction;
      endaction     
      noAction;
      noAction;
       
  endseq;

  mkAutoFSM(fsm);

endmodule

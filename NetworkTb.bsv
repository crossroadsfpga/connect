/* =========================================================================
 *
 * Filename:            NetworkTb.bsv
 * Date created:        09-21-2012
 * Last modified:       09-21-2012
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Simple testbench for Network.  
 * 
 * =========================================================================
 */

import Assert::*;
import ConfigReg::*;
import Vector::*;
import BRAMFIFO::*;
import FIFOF::*;
//import Clocks::*;
import NetworkTypes::*;

import Router::*;
import NetworkGlueSimple::*;
import Network::*;
import StmtFSM::*;			// just for creating a test sequence
import FShow::*;

`include "inc.v"

module mkNetworkTb(Empty);
  String name = "NetworkSimpleTb";
  // instantiate network
  Network net <- mkNetwork();

  Reg#(Bit#(32)) cycles <- mkConfigReg(0);

  (* no_implicit_conditions *)
  rule cycle_count(True);
    $display("[cycle %08d] ----------------------------------------------- ", cycles);
    //for(Integer r=0; r < valueOf(NumRouters); r=r+1) begin
    //  $write(" %0d", credits[r][0]);
    //end
    //$write("\n");
    cycles <= cycles + 1;
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
        //$display("RecvPort:",r," Incoming Flit:",fshow(fl.Valid));
//	let tmp = $format("RecvPort:",r," Incoming Flit:",fshow(fl.Valid));
//        `DISP_CYCLES((tmp)); 
        `DISP_CYCLES(( $format("RecvPort:",r," Incoming Flit:",fshow(fl.Valid)) )); 
	//$display("RecvPort:",r," Incoming Flit:",fshow(fl.Valid));
      end

      // don't provide credits to test backpressure!
      //net.recv_ports[r].putNonFullVCs(unpack(0));

      //$display("router %0d delay_sum %0d pkt_cnt %0d", r, delay_sum[r], pkt_cnt[r]);
      //total_delay = total_delay + extend(delay_sum[r]);
      //total_pkt_cnt = total_pkt_cnt + extend(pkt_cnt[r]);
    end

    // for(Integer s=0; s < valueOf(NumUserSendPorts); s=s+1) begin
    //   let nonFullVCs <- net.send_ports[s].getNonFullVCs();
    //   if(!nonFullVCs[0]) begin // some port is full
    //     $display("SendPort:",s," input buffer full!");
    //   end

    //   //$display("router %0d delay_sum %0d pkt_cnt %0d", r, delay_sum[r], pkt_cnt[r]);
    //   //total_delay = total_delay + extend(delay_sum[r]);
    //   //total_pkt_cnt = total_pkt_cnt + extend(pkt_cnt[r]);
    // end
    
    //$display("total_delay_sum %0d total_pkt_cnt %0d", total_delay, total_pkt_cnt);
  endrule


  function Action sendFlit(UserSendPortID_t src, UserRecvPortID_t dst, Bool is_tail, VC_t vc, FlitData_t data);
    action
      Maybe#(Flit_t) fl = tagged Valid Flit_t{is_tail:is_tail, dst:dst, vc:vc, data:data};
      //let tmp = $format("SendPort ",src," is sending Flit: ",fshow(fl));
      //`DISP_CYCLES((tmp)); 
      `DISP_CYCLES(( "SendPort ",src," is sending Flit: ",fshow(fl) ));
      net.send_ports[src].putFlit(fl);
    endaction
  endfunction

  Stmt fsm = seq
    action
      sendFlit(0,0,True,0,'h00000000);
      sendFlit(1,1,True,0,'h11000000);
      sendFlit(2,2,True,0,'h22000000);
      sendFlit(3,3,True,0,'h33000000);
      //net.send_ports[0].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd0), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[1].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[2].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd2), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[3].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd3), vc:truncate(64'd0), data:unpack(0)} );
    endaction
    action
      sendFlit(0,1,True,0,'h01000000);
      sendFlit(2,9,True,0,'h29000000);
      //net.send_ports[0].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[1].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[2].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[3].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
    endaction
    action
      sendFlit(0,1,True,0,'h01000001);
      //net.send_ports[0].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[1].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[2].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[3].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
    endaction
    action
      sendFlit(0,1,True,0,'h01000002);
      //net.send_ports[0].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[1].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[2].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
      //net.send_ports[3].putFlit( tagged Valid Flit_t{is_tail:True, dst:truncate(64'd1), vc:truncate(64'd0), data:unpack(0)} );
    endaction

      sendFlit(0,1,True,0,'h01000003);
      sendFlit(0,1,True,0,'h01000004);
      sendFlit(0,1,True,0,'h01000005);
      sendFlit(0,1,True,0,'h01000006);
      sendFlit(0,1,True,0,'h01000007);
      sendFlit(0,1,True,0,'h01000008);
      sendFlit(0,1,True,0,'h01000009);
      sendFlit(0,1,True,0,'h01000010);
      sendFlit(0,1,True,0,'h01000011);
      sendFlit(0,1,True,0,'h01000012);
      sendFlit(0,1,True,0,'h01000013);
      sendFlit(0,1,True,0,'h01000014);
      sendFlit(0,1,True,0,'h01000015);
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

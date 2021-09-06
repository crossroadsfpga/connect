/* =========================================================================
 *
 * Filename:            NetworkTestHarness.bsv
 * Date created:        09-08-2011
 * Last modified:       09-16-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Router test harness. Feeds traffic to network.
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
import Network::*;
import RegFile::*;
import StmtFSM::*;			// just for creating a test sequence

`include "inc.v"

//`define NPKTS  10
//`define NFLITS 100000
`define NCYCLES 1100000
`define NWARMUP  100000
`define TRACE_FILE_PREFIX "traffic"

//typedef `NPKTS    NumPktsToTest;
//typedef `NFLITS   NumFlitsToTest;
typedef `NCYCLES  NumCyclesToTest;
typedef `NWARMUP  NumCyclesToWarm;
typedef NumCyclesToTest NumFlitsToTest;

typedef Bit#(32) TimeStamp_t;  // time-stamp

interface NetworkTestHarness;

endinterface

typedef struct {
  Bool        is_head;    // indicates head flit
  Bool        is_tail;    // indicates tail flit - these flits are used to measure delay
  Bit#(8)     src;        // Packet Source.      (will be truncated to match RouterID_t)
  Bit#(8)     dst;        // Packet Destination. (will be truncated to match RouterID_t)
  Bit#(4)     vc;         // VC to use.          (will be truncated to match VC_t)
  TimeStamp_t ts;         // Injection Time-stamp. (32-bits)
  //Bit#(8)     num_flits;  // Number of flits in packet. (will be truncated to match FlitID_t)
} TraceEntry_t
deriving (Bits, Eq);

//module mkTrafficDrivers#(Integer id)(Empty);
module mkNetworkTestHarness(Empty);
  String name = "NetworkTestHarness";

  // instantiate network
  Network net <- mkNetwork();

  Vector#(NumUserRecvPorts, Reg#( Bit#(64) ))			    pkt_cnt    <- replicateM(mkConfigReg(0));
  Vector#(NumUserRecvPorts, Reg#( Bit#(64) ))                     delay_sum  <- replicateM(mkConfigReg(0));

  // credits
  Vector#(NumUserSendPorts, Vector#(NumVCs, Reg#(Bit#(TLog#(TAdd#(FlitBufferDepth,1))))))   credits;
  //Vector#(NumRouters, Vector#(NumVCs, Reg#(Bool) ))    credits          <- replicateM(mkReg(True));  // start with credits for all VCs.
  Vector#(NumUserSendPorts, Vector#(NumVCs, Wire#(Bool)))    credits_set; //     <- replicateM(mkDWire(False));
  Vector#(NumUserSendPorts, Vector#(NumVCs, Wire#(Bool)))   credits_clear; //   <- replicateM(mkDWire(False));
  //Wire#(Bool) reset_stats <- mkDWire(False);

  for(Integer r = 0; r< valueOf(NumUserSendPorts); r=r+1) begin
    credits[r]        <- replicateM(mkConfigReg(fromInteger(valueOf(FlitBufferDepth))));   // start with credits for all ouputs/VCs
    credits_set[r]    <- replicateM(mkDWire(False));
    credits_clear[r]  <- replicateM(mkDWire(False));
  end

  // Rule to update credits. Credits get replenished from out_ports and are spent when sending flits.
  (* no_implicit_conditions *)
  rule update_credits (True);   // turn off credits for debugging
    for(Integer r=0; r<valueOf(NumUserSendPorts); r=r+1) begin
      for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
	if ( credits_set[r][v] && !credits_clear[r][v] ) begin   // I only received a credit
	  //credits[o][v] <= True;
	  credits[r][v] <= credits[r][v] + 1;
	  if(credits[r][v]+1 > fromInteger(valueof(FlitBufferDepth))) begin
	    `DBG(("Credit overflow at router %0d VC %0d", r, v));
	  end
	end else if (!credits_set[r][v] && credits_clear[r][v]) begin   // I only spent a credit
	  //credits[o][v] <= False;
	  credits[r][v] <= credits[r][v] - 1;
	  if(credits[r][v] == 0) begin
	    `DBG(("Credit underflow at router %0d VC %0d", r, v));
	  end
	end
      end
    end
    //`DBG_DETAIL_ID(("credits:%b", readVReg(concat(credits)) ));  // flatten the array to print
  endrule

  function get_trace( Integer id );
    String traffic_file = strConcat( strConcat(`TRACE_FILE_PREFIX, integerToString(id)), ".rom");
    //$display("Loading router %d trace from %s", id, traffic_file);
    return mkRegFileFullLoad(traffic_file);
    //RegFile#(Bit#(TLog#(NumPktsToTest)), TraceEntry_t)  traffic <- mkRegFileFullLoad(traffic_file);
    //return traffic;
  endfunction
 
  Vector#(NumUserSendPorts,  RegFile#(Bit#(TLog#(NumFlitsToTest)), TraceEntry_t)   )  traces <- genWithM( get_trace );
  Vector#(NumUserSendPorts,  Reg#(Bit#(64)) )                                            cur_trace <- replicateM(mkConfigReg(0));
 
  //for(i<=0; i < fromInteger(valueOf(NumFlitsToTest)); i<=i+1) seq
  //  String traffic_file = strConcat( strConcat(`NETWORK_ROUTING_FILE_PREFIX, integerToString(id)), ".rom");
  //  RegFile#(Bit#(TLog#(NumPktsToTest)), TraceEntry_t)  traffic <- mkRegFileFullLoad(traffic_file);

  //function Action send_flit()
  //endfunction 
  Reg#(Bit#(64)) i <- mkReg(0);
  //Reg#(Bit#(64)) r <- mkReg(0);
  
  Reg#(Bit#(32)) cycle <- mkConfigReg(0);

  (* no_implicit_conditions *)
  rule cycle_count(True);
    //$display("[cycle %08d] ----------------------------------------------- ", cycle);
    //for(Integer r=0; r < valueOf(NumRouters); r=r+1) begin
    //  $write(" %0d", credits[r][0]);
    //end
    //$write("\n");
    cycle <= cycle + 1;
  endrule
 
//  (* no_implicit_conditions *)
//  rule monitor_warmup(True);
//     if (cycle == fromInteger(valueOf(NumCyclesToWarm))) begin
//      $display("Warmup done finished @ cycle %0d. Reseting stats.", cycle);
//      reset_stats <= True;
//      for(Integer r=0; r < valueOf(NumRouters); r=r+1) begin
//	delay_sum[r] <= 0;
//	pkt_cnt[r] <= 0;
//      end
//    end else begin
//  endrule

  (* no_implicit_conditions *)
  rule drain_flits(True);
    for(Integer r=0; r < valueOf(NumUserRecvPorts); r=r+1) begin
      let in_pckt <- net.recv_ports[r].getFlit();
      if(isValid(in_pckt)) begin  // received a valid packet
        let p = in_pckt.Valid;
	net.recv_ports[r].putCredits( tagged Valid p.vc );  // send a credit back
      end

      if (cycle == fromInteger(valueOf(NumCyclesToWarm))) begin
        $display("Warmup done finished @ cycle %0d. Reseting stats.", cycle);
	delay_sum[r] <= 0;
	pkt_cnt[r] <= 0;
      end else begin  // only update stats if not resetting.
        if(isValid(in_pckt)) begin  // received a valid flit
          let p = in_pckt.Valid;
	  if (p.is_tail) begin  // valid flit is a tail
	    delay_sum[r] <= delay_sum[r] + extend(cycle-p.data);  // data carries injection timestamp
	    pkt_cnt[r]   <= pkt_cnt[r] + 1;
	  end
	end
      end
    end

    //   for(Integer r=0; r < valueOf(NumRouters); r=r+1) begin
    //    let in_pckt <- net.recv_ports[r].getFlit();
    //    if(isValid(in_pckt)) begin  // received a valid packet
    //      let p = in_pckt.Valid;
    //      net.recv_ports[r].putCredits( tagged Valid p.vc );  // send a credit back
    //      if(p.is_tail) begin  // if this is a tail add it to the total delay.
    //        delay_sum[r] <= delay_sum[r] + extend(cycle-p.data);  // data carries injection timestamp
    //        pkt_cnt[r]   <= pkt_cnt[r] + 1;
    //      end
    //    end else begin
    //      net.recv_ports[r].putCredits( Invalid );  // send a credit back
    //    end
    //  end
  endrule

  Stmt fsm = seq
    // For each router
    repeat( fromInteger(valueOf(NumCyclesToTest)) ) seq
    //for(i<=0; i < fromInteger(valueOf(NumCyclesToTest)); i<=i+1) seq
    //for(f<=0; f < fromInteger(valueOf(NumFlitsToTest)); f<=f+1) seq
      //for(r<=0; r < fromInteger(valueOf(NumRouters)); r<=r+1) par
	// Try to send a flit
	action
	  for(Integer r=0; r < valueOf(NumUserSendPorts); r=r+1) begin
	    TraceEntry_t te = traces[r].sub(truncate(cur_trace[r]));
	    //$display("[%02d] curr_te: %x", r, te);
	   
	    // check for credits and check if cycle count has passed departure time!
	    if(credits[r][te.vc] > 0 && cycle >= te.ts) begin

	      VC_t vc = truncate(te.vc);
	      net.send_ports[r].putFlit( tagged Valid Flit_t{is_tail:te.is_tail, dst:truncate(te.dst), vc:vc, data:te.ts} );
	      credits_clear[r][vc] <= True;

	      cur_trace[r] <= cur_trace[r] + 1;
	      //$display("Sending flit (t:%d) from %d to %d @ cycle %d (ts: %d)", te.is_tail, r, te.dst, cycle, te.ts);
	      //TrafficEntry_t te = traffic.sub(truncate(i));
	      //send_trace(tr.ts, tr.src, tr.dst);
	    end else begin
	      net.send_ports[r].putFlit( Invalid );
	      //if (cycle < te.ts) begin
	      //  $display("Not ready to send flit yet (dep_time: %d, cur_time:%d)", te.ts, cycle);
	      //end
	      //if (credits[r][te.vc] == 0) begin
	      //  $display("Out of credits (router: %d, VC: %d)", r, te.vc);
	      //end
	    end


	  end
	endaction
      //endpar
    endseq
  
  endseq;

  rule handle_incoming_credits(True); 
    // keep track of credits
    for(Integer r=0; r < valueOf(NumUserSendPorts); r=r+1) begin
      let cr_in <- net.send_ports[r].getCredits();
      if(isValid(cr_in)) begin
	credits_set[r][cr_in.Valid] <= True;
	//$display("Cycle: %0d: Received credit at router %0d for vc %0d", cycle, r, cr_in.Valid);
      end
    end
  endrule

  mkAutoFSM(fsm);


  (* fire_when_enabled *)
  rule printstats (cycle == fromInteger(valueOf(NumCyclesToTest)));
    Bit#(64) total_delay = unpack(0);
    Bit#(64) total_pkt_cnt = unpack(0);
    for(Integer r=0; r < valueOf(NumUserRecvPorts); r=r+1) begin
      $display("router %0d delay_sum %0d pkt_cnt %0d", r, delay_sum[r], pkt_cnt[r]);
      total_delay = total_delay + extend(delay_sum[r]);
      total_pkt_cnt = total_pkt_cnt + extend(pkt_cnt[r]);
    end
    $display("total_delay_sum %0d total_pkt_cnt %0d", total_delay, total_pkt_cnt);
  endrule




//     (* fire_when_enabled *)
//     rule printstats (cycle == fromInteger(valueOf(NumCyclesToTest)));
//      for(Integer r=0; r < valueOf(NumRouters); r=r+1) begin
//       $display("router %0d delay_sum %0d pkt_cnt %0d", r, delay_sum[r], pkt_cnt[r]);
//       //prstat();
//     end
//   //    for(Integer r=0; r < valueOf(NumRouters); i=i+1) begin
//   //      sinks[i].prstat();
//   //    end 
//     endrule

//  method Action prstat();
//    $display("total_delay %0d\npkt_cnt %0d", delay_sum, pkt_cnt);
//  endmethod

endmodule

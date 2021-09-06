/* =========================================================================
 *
 * Filename:            TrafficSource.bsv
 * Date created:        03-04-2012
 * Last modified:       03-05-2012
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Traffic Source used to inject packets into the network.
 * 
 * =========================================================================
 */

import Assert::*;
import ConfigReg::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import RegFile::*;
import LFSR::*;
import GetPut::*;
import FShow::*;

import NetworkTypes::*;

`include "inc.v"

// Types
typedef Bit#(TLog#(256)) Load_t;
typedef Bit#(TLog#(512)) PktSize_t;

////////////////////////////////
// TrafficSource Interface
////////////////////////////////
interface TrafficSource;
  interface OutPort out_port;   // this is connected with the injection port of a router
  method Action  setLoad(Load_t new_load);
  method Action  setMaxPktSize(PktSize_t new_max_pkt_size);
  method Action  set_enabled(Bool new_enabled);
  method Action  set_pkts_to_send(Bit#(64) new_pkts_to_send);
  method Bool    is_finished();   // return True if finished
  interface Put#(Bool) setFixedPktSize;
  //method  Bool    is_initDone();
  //method  Action  setTrafficEntryAndInit(TrafficEntryID_t tr_id, TrafficEntry_t tr, Bool init);
  //method  Action  setPacketsToSend(HalfNumPackets_t num_pcks_lo_hi, Bool is_lo);
endinterface


////////////////////////////////////////////////
// Traffic source implementation
////////////////////////////////////////////////
(* synthesize *)
module mkTrafficSource#(UserRecvPortID_t id) (TrafficSource);
  String name = "TrafficSource";
  Bit#(8) errorCode = 0;
  
  // State and wires
  Reg#(Bool)         enabled      <- mkConfigReg(False);  // only send packets if TrafficSource is enabled
  Reg#(Bool)         finished     <- mkConfigReg(False);  // only send packets if TrafficSource is enabled
  Reg#(Bit#(64))     pkts_sent    <- mkConfigReg(0);


  Reg#(Load_t)    load         <- mkConfigReg(0);
  Reg#(PktSize_t) max_pkt_size <- mkConfigReg(1);
  Reg#(Bit#(64))  pkts_to_send <- mkConfigReg(0);
  Reg#(Bool)      fix_pkt_size <- mkConfigReg(True); // default behavior is to send fixed size packets of size max_pkt_size

  Reg#(PktSize_t) flits_left_to_send <- mkConfigReg(0);
  Reg#(Flit_t)    flit_of_curr_pkt  <- mkConfigRegU();


  // LFSRs for load, packet size, destination and VC
  LFSR#(Bit#(8)) load_lfsr      <- mkLFSR_8;
  LFSR#(Bit#(16)) pkt_size_lfsr <- mkLFSR_16;
  LFSR#(Bit#(8))  dest_lfsr     <- mkLFSR_8;
  LFSR#(Bit#(8))  vc_lfsr       <- mkLFSR_8;

  (* no_implicit_conditions *)
  rule check_if_finished (True);
    if(pkts_sent >= pkts_to_send) begin
      finished <= True;
      enabled  <= False;
      `DBG_ID(("Finished after sending %0d packets. Disabling traffic source.", pkts_sent));     
    end
  endrule

  (* no_implicit_conditions *)
  rule advance_lfsrs (True);// advance LFSR
    load_lfsr.next();     
    pkt_size_lfsr.next();
    dest_lfsr.next();
    vc_lfsr.next();
  endrule

//  rule inject_traffic (enabled);
//    if( truncate(load_lfsr.value) <= load ) begin  // inject flit
//      //if(truncate(dest_lfsr.value) > 
//      //UserRevcPort_t dest = truncate(dest_lfsr.value);
//      UserRevcPort_t dest = dest_lfsr.value / NumUserRecvPorts;
//
//    end
//    load_lfsr.next(); // advance LFSR
//  endrule

  Vector#(NumVCs, Reg#(Bit#(TLog#(TAdd#(FlitBufferDepth,1)))))   credits       <- replicateM(mkConfigReg(fromInteger(valueOf(FlitBufferDepth))));
  Vector#(NumVCs, Wire#(Bool))					 credits_set   <- replicateM(mkDWire(False));
  Vector#(NumVCs, Wire#(Bool))					 credits_clear <- replicateM(mkDWire(False));
  //Wire#(Bool) reset_stats <- mkDWire(False);

  ///////////////////////////////////////////////////////////////////////////////////////////////////////
  // Rule to update credits. Credits get replenished from out_ports and are spent when sending flits.
  (* no_implicit_conditions *)
  rule update_credits (True); 
    for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
      if ( credits_set[v] && !credits_clear[v] ) begin          // I only received a credit
	credits[v] <= credits[v]+1;
	if(credits[v]+1 > fromInteger(valueof(FlitBufferDepth))) begin
          `DBG_ID(("Credit overflow at VC %0d", v));
	end
      end else if (!credits_set[v] && credits_clear[v]) begin   // I only spent a credit
	credits[v] <= credits[v]-1;
	if(credits[v] == 0) begin
	  `DBG_ID(("Credit underflow at VC %0d", v));
	end
      end
    end
  endrule

  // Rule for debugging
  rule dbg (`EN_DBG_RULE);
    if(errorCode != 0) begin // error
      $display("Error (errorCode:%d)", errorCode);
      $stop;
    end
  endrule


  ////////////////////////////////////////////////////
  // Interface Implementation
  let ifc =
    interface OutPort
      method ActionValue#(Maybe#(Flit_t)) getFlit();
	let flit_to_send = Invalid;
	// Only send flits if enabled
	`DBG_ID(("load_lfsr value: %0d", load_lfsr.value));
	if( enabled ) begin
	  if( flits_left_to_send > 0 ) begin // in the middle of sending multi-flit packet
	    let fl = flit_of_curr_pkt;
	    if(flits_left_to_send == 1) begin // last flit
	      fl.is_tail = True;    // set is_tail
	      pkts_sent           <= pkts_sent + 1; 
	    end
	    flit_to_send = tagged Valid fl;
	    flits_left_to_send <= flits_left_to_send - 1;
	  end else if( truncate(load_lfsr.value) <= load ) begin  // inject flit
	    //if(truncate(dest_lfsr.value) > 
	    //UserRevcPort_t dest = truncate(dest_lfsr.value);
	    // Note: very slight bias towards 0. To fix replace with "(dest_lfsr.value + fromInteger(valueOf(NumUserRecvPorts)) % fromInteger(valueOf(NumUserRecvPorts)))
	    UserRecvPortID_t dest = truncate(dest_lfsr.value % fromInteger(valueOf(NumUserRecvPorts))); 
	    VC_t               vc = truncate(vc_lfsr.value);

	    // Define packet size
	    PktSize_t remaining_flits = max_pkt_size-1;  // assumes fixed packet size, all packets have size max_pkt_size
	    if (!fix_pkt_size) begin  // all packets have size max_pkt_size
	      remaining_flits = truncate(pkt_size_lfsr.value % extend(max_pkt_size)); 
	    end

	    // Set tail bit
	    let is_tail = False; // set is tail to False for multi-flit packets
	    if(remaining_flits == 0) begin // single-flit packet
	      is_tail = True;    // set to true for single flit packets
	      pkts_sent          <= pkts_sent + 1; 
	    end

	    // Prepare flit to send
	    flit_to_send          = tagged Valid Flit_t{is_tail: is_tail, dst: dest, vc:vc, data:unpack(0)};
	    flit_of_curr_pkt     <= flit_to_send.Valid; // remember to generate rest of flits
	    flits_left_to_send   <= remaining_flits;

	    // Clear credit for this flit
	    credits_clear[vc]    <= True;

	    `DBG_ID(("Sending packet to %0d on VC %0d", dest, vc));
	  end
	end
	return flit_to_send;
      endmethod

      method Action putCredits(Credit_t cr_in);
	if(isValid(cr_in)) begin
	  credits_set[cr_in.Valid] <= True;
	end
      endmethod
    endinterface;

  interface out_port = ifc;
  
  interface setFixedPktSize = toPut(asReg(fix_pkt_size)); 

  method    Action  setLoad(Load_t new_load);
    `DBG_ID(("Setting load to %0d", new_load));
    load <= new_load;
  endmethod

  method    Action  setMaxPktSize(PktSize_t new_max_pkt_size);
    max_pkt_size <= new_max_pkt_size;
  endmethod

  method    Action  set_enabled(new_enabled);
    enabled      <= new_enabled;
  endmethod
  

  method Action  set_pkts_to_send(Bit#(64) new_pkts_to_send);
    `DBG_ID(("Setting pkts_to_send to %0d", new_pkts_to_send));
    pkts_to_send <= new_pkts_to_send;
  endmethod

  method Bool is_finished();   // return True if finished
    return finished;
  endmethod

endmodule


////////////////////////////////////////////
// Testbench - comment this line to disable 
`define TRAFFIC_SOURCE_TB
`ifdef TRAFFIC_SOURCE_TB

import StmtFSM::*;   // for testbench

//(* synthesize, scan_insert *)
(* synthesize *)
module mkTrafficSourceTb(Empty);
  String name = "mkTrafficSourceTb";
  Reg#(Bit#(64)) cycles <- mkReg(0);
  Reg#(Bit#(64)) total_cycles <- mkReg(20);
  TrafficSource traffic_src <- mkTrafficSource(fromInteger(1));
  Integer test_cycles = 20;

  rule countCycles(True);
    cycles<=cycles+1;
    //if(cycles >= total_cycles) $finish(0);
    $display("------------------------------------------------<%0d>",cycles);
  endrule

  function Action printFlit(Flit_t fl);
    //$display("-->Flit {dst:%0d, vc:%0d, is_tail:%0d}", fl.dst, fl.vc, fl.is_tail);
    $display(" Flit {dst:%0d, vc:%0d is_tail:%0d}", fl.dst, fl.vc, fl.is_tail);
  endfunction


  Stmt scan_outport= seq
    action
      //`BLUE;
      //$display("--------------------------- Start of cycle -------------------------------------<%0d>",cycles);
      //`WHITE;
      let fl <- traffic_src.out_port.getFlit();
      if(isValid(fl)) begin
	//`DBG_CYCLES(("New Flit - dst:%0d\t vc:%0d\t is_tail:%0d\t data:%x", fl.Valid.dst, fl.Valid.vc, fl.Valid.is_tail, fl.Valid.data));
	`DBG_CYCLES(("New ", fshow(fl.Valid) ));
	//printFlit(fl.Valid);
      end else begin
	//`DBG(("[%0d] No Flit on out_port %d", cycles, o));
      end
    endaction
  endseq;


  Stmt test_seq = seq
    noAction;
    noAction;
    traffic_src.set_pkts_to_send(fromInteger(16));
    traffic_src.setMaxPktSize(fromInteger(3));
    traffic_src.setFixedPktSize.put(False);
    par
      traffic_src.setLoad(fromInteger(128));
      traffic_src.set_enabled(True);
    endpar
    //let fl = traffic_src.out_port.getFlit();
    repeat(100)
      scan_outport;
      
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    //scan_outport;
    noAction;
    $finish();

  endseq;

  mkAutoFSM(test_seq);

endmodule

`endif

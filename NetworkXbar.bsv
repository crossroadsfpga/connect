import Assert::*;
import ConfigReg::*;
import Vector::*;
import Count::*;
import FIFOF::*;
import PipelineFIFO::*;
import FIFOLevel::*;
import LUTFIFO::*;
import BRAMFIFO::*;
import Arbiters::*;
import GetPut::*;
import FIFOCountDeqBus::*;
import Strace::*;
import NetworkQueues::*;


`include "inc.v"

import NetworkTypes::*;
import NetworkExternalTypes::*;
import Xbar::*;


module mkNetworkXbar(Network);

    XbarVerilog#(NumRouters, NumVCs, NetworkCut, FlitDataWidth, FlitBufferDepth) xbar <- mkXbarVerilog;

    Vector#(NumRouters, InPort) send_ifaces;
    Vector#(NumRouters, OutPort) recv_ifaces;
    Vector#(NumRouters, RouterInfo) rt_ifaces;

    Vector#(NumRouters, PulseWire)		i_valid <- replicateM(mkPulseWire);
    Vector#(NumRouters, PulseWire)		i_prio  <- replicateM(mkPulseWire);
    Vector#(NumRouters, PulseWire)		i_tail  <- replicateM(mkPulseWire);
    Vector#(NumRouters, RWire#(RouterID_t))	i_dst	<- replicateM(mkRWire);
    Vector#(NumRouters, RWire#(VC_t))		i_vc	<- replicateM(mkRWire);
    Vector#(NumRouters, RWire#(FlitData_t))	i_data  <- replicateM(mkRWire);

    Vector#(NumRouters, PulseWire)              o_cred_en <- replicateM(mkPulseWire);

    (* fire_when_enabled *)
    rule putIface(True);
    
	Vector#(NumRouters, Bool) in_valid;
	Vector#(NumRouters, Bool) in_prio;
	Vector#(NumRouters, Bool) in_tail;
	Vector#(NumRouters, RouterID_t) in_dst;
	Vector#(NumRouters, VC_t)       in_vc;
	Vector#(NumRouters, FlitData_t) in_data;

	Vector#(NumRouters, Bool) out_cred_en;

	for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin
	    in_valid[i] = i_valid[i];
	    in_prio[i] = i_prio[i];
	    in_tail[i] = i_tail[i];
	    in_dst[i] = validValue(i_dst[i].wget);
	    in_vc[i] = validValue(i_vc[i].wget);
	    in_data[i] = validValue(i_data[i].wget);

	    out_cred_en[i] = o_cred_en[i];
	end

	xbar.iports(in_valid, in_prio, in_tail, in_dst, in_vc, in_data);
	xbar.o_cred(out_cred_en);
 
    endrule

    let o_valid = xbar.o_valid;
    let o_prio = xbar.o_prio;
    let o_tail = xbar.o_tail;
    let o_dst = xbar.o_dst;
    let o_vc = xbar.o_vc;
    let o_data = xbar.o_data;

    let i_cred = xbar.i_cred;
    let i_cred_valid = xbar.i_cred_valid;

    for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin
	let ifc = interface InPort

	    method Action putFlit(Maybe#(Flit_t) flit_in);
		if(flit_in matches tagged Valid .flit) begin
		    i_valid[i].send();
		    if(flit.prio) i_prio[i].send();
		    if(flit.is_tail) i_tail[i].send();
		    i_dst[i].wset(flit.dst);
		    i_vc[i].wset(flit.vc);
		    i_data[i].wset(flit.data);
		end
	    endmethod

	    method ActionValue#(Credit_t) getCredits;
		actionvalue
		    if(i_cred_valid[i]) return Valid(i_cred[i]);
		    else return Invalid;
		endactionvalue
	    endmethod

	endinterface;
	send_ifaces[i] = ifc;
    end

     // From outQs to output

    for(Integer o=0; o < valueOf(NumRouters); o=o+1) begin

	let ifc = interface OutPort

	    method ActionValue#(Maybe#(Flit_t)) getFlit();
		actionvalue

		    Maybe#(Flit_t) flitOut = Invalid;

		    if(o_valid[o]) begin
			flitOut = Valid(Flit_t{ prio:    o_prio[o],
			                        is_tail: o_tail[o],
						dst:     o_dst[o],
						vc:      o_vc[o],
						data:    o_data[o] });
		    end

		    return flitOut;
		endactionvalue
	    endmethod

	    method Action putCredits(Credit_t cr_in);
		if(isValid(cr_in)) begin
		    o_cred_en[o].send();
		end
	    endmethod

	endinterface;

	recv_ifaces[o] = ifc;
    end 

    for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin

	let ifc = interface RouterInfo
	    method RouterID_t getRouterID();
		return fromInteger(i);
	    endmethod
	endinterface;

	rt_ifaces[i] = ifc;
    end

    interface send_ports = send_ifaces;
    interface recv_ports = recv_ifaces;
    interface router_info = rt_ifaces; 
 
endmodule
 
/*
typedef struct {
    Bool prio;
    Flit_t flit;
    Bit#(32) tag;
} TaggedFlit
    deriving(Bits, Eq);
 

(* synthesize *)
module mkNetworkQueueWithDeqBus(FIFOCountDeqBus#(TaggedFlit, FlitBufferDepth, NumRouters));
    let q <- mkFIFOCountDeqBus();
    return q;
endmodule

(* synthesize *)
module mkNetworkXbarQueue(FIFOCountIfc#(TaggedFlit, FlitBufferDepth));
    let q <- mkLUTFIFO(False);
    return q;
endmodule

(* synthesize *)
module mkNetworkDummyQueue(FIFOCountDeqBus#(TaggedFlit, FlitBufferDepth, NumRouters));
    interface FIFOCountIfc fifo;
	method notEmpty = False;
	method notFull = True;
    endinterface
    method deq_happened = False;
endmodule 

(* noinline *)
function Maybe#(Bit#(TLog#(TMul#(XbarLanes,NumRouters)))) mkNetworkXbarEncoder( Vector#(TMul#(XbarLanes,NumRouters), Bool) vec );
  Maybe#(Bit#(TLog#(TMul#(XbarLanes,NumRouters)))) choice = Invalid;
  //for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
  for(Integer i=valueOf(TMul#(XbarLanes,NumRouters))-1; i >= 0; i=i-1)  // I want the lowest to have highest priority
  begin
    if(vec[i]) begin
      choice = Valid(fromInteger(i));
    end
  end
  return choice;
endfunction
 

(* synthesize *)
module mkNetworkXbarArbiter( Arbiter#(TMul#(XbarLanes,NumRouters)) );
    let arb <- mkRoundRobinArbiter();
    rule alwaysToggle(True);
	arb.next();
    endrule
    method select = arb.select;
    method next = noAction;
endmodule

(* synthesize *)
module mkNetworkXbarCounter( Count#(Bit#(TLog#(TAdd#(FlitBufferDepth,1))),1) );
    let counter <- mkCount(valueOf(FlitBufferDepth));
    return counter;
endmodule

interface XbarOutputQueue;
    method Vector#(NumRouters, Bool) send_creds();
    interface Vector#(NumRouters, Put#(Flit_t)) send_ifaces;
    interface OutPort recv_iface;
endinterface




module mkNetworkXbar(Network);

    Vector#(TMul#(XbarLanes,NumRouters), 
	FIFOCountDeqBus#(TaggedFlit, FlitBufferDepth, NumRouters))   inQs	      <- replicateM(mkNetworkQueueWithDeqBus);

    Vector#(TMul#(XbarLanes,NumRouters),
	FIFOCountDeqBus#(TaggedFlit, FlitBufferDepth, NumRouters))   dummyQs	      <- replicateM(mkNetworkDummyQueue);

    Vector#(NumRouters, FIFOF#(TaggedFlit))	       		 outQs	      <- replicateM(mkPipelineFIFO(False)); //mkNetworkXbarQueue);
    Vector#(NumRouters, Arbiter#(TMul#(XbarLanes,NumRouters)))	 arbiters     <- replicateM(mkNetworkXbarArbiter);
    Vector#(NumRouters,
	Count#(Bit#(TLog#(TAdd#(FlitBufferDepth,1))),1))	 out_credits  <- replicateM(mkNetworkXbarCounter);
    Vector#(NumRouters, Reg#(Credit_t))				 vc_type      <- replicateM(mkReg(Invalid));

    Vector#(NumRouters, Reg#(Bit#(32)))				 strace_tags;
    for(Integer i=0; i < valueOf(NumRouters); i=i+1)
	strace_tags[i] <- mkReg(fromInteger(i)*65536);

    Vector#(NumRouters, InPort) send_ifaces;
    Vector#(NumRouters, OutPort) recv_ifaces;
    Vector#(NumRouters, RouterInfo) rt_ifaces;

    rule stats(True);
	for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin
	    Bool raise=False;
	    for(Integer k=0; k < valueOf(XbarLanes); k=k+1) begin
		if(inQs[i*valueOf(XbarLanes)+k].fifo.notEmpty)
		    raise = True;
	    end
	    if(raise) $display("strace time=%0d component=noc inst=0 evt=raises val=1", $time);
	end
    endrule

    for(Integer o=0; o < valueOf(NumRouters); o=o+1) begin
	let arbiter = arbiters[o];
	rule moveToOutput(True);
	    arbiter.next();

	    Vector#(TMul#(XbarLanes,NumRouters),
	            FIFOCountDeqBus#(TaggedFlit, FlitBufferDepth, NumRouters)) validQs;

	    for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin
		for(Integer k=0; k < valueOf(XbarLanes); k=k+1) begin
		    if(o < valueOf(NetworkCut)) begin
			if(i >= valueOf(NetworkCut)) 
			    validQs[i*valueOf(XbarLanes)+k] = inQs[i*valueOf(XbarLanes)+k];
			else
			    validQs[i*valueOf(XbarLanes)+k] = dummyQs[i*valueOf(XbarLanes)+k];
		    end
		    else begin
			if(i < valueOf(NetworkCut))
			    validQs[i*valueOf(XbarLanes)+k] = inQs[i*valueOf(XbarLanes)+k];
			else
			    validQs[i*valueOf(XbarLanes)+k] = dummyQs[i*valueOf(XbarLanes)+k];
		    end
		end
	    end

	    Vector#(TMul#(XbarLanes,NumRouters), Bool) raises = unpack(0);
	    for(Integer i=0; i < valueOf(TMul#(XbarLanes,NumRouters)); i=i+1) begin
		let inQ = validQs[i].fifo;
		raises[i] = inQ.notEmpty && (inQ.first.flit.dst == fromInteger(o));
	    end

	    let msel = mkNetworkXbarEncoder(arbiter.select(raises));
	    if(msel matches tagged Valid .sel) begin
		if(outQs[o].notFull) begin
		    let flitOut = validQs[sel].fifo.first;
		    outQs[o].enq(flitOut);
		    validQs[sel].deq[o].deq();
		    $display("strace time=%0d component=noc inst=0 evt=grants val=1", $time);
		end
		else $display("strace time=%0d component=noc inst=0 evt=full val=1", $time);
	    end
	endrule
    end 

    // Input Requests

    for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin
	let ifc = interface InPort

	    method Action putFlit(Maybe#(Flit_t) flit_in);
		if(flit_in matches tagged Valid .flit) begin
		    let dst = flit.dst;
		    Integer sel=i;
		    // sort by destination
		    for(Integer k=0; k < valueOf(XbarLanes); k=k+1) begin
			Bit#(TLog#(XbarLanes)) tmp = truncate(dst);
			if(tmp == fromInteger(k)) sel = i*valueOf(XbarLanes) + k;
		    end

		    strace_tags[i]<=strace_tags[i]+1;

		    inQs[sel].fifo.enq(TaggedFlit{flit:flit, tag:strace_tags[i], prio:flit.prio});
		    //$display("[network] time=%0d input port %0d (sel:%0d) -> output Q %0d", $time, i, sel, dst);
		    strace_begin("noc", 0, "delay", strace_tags[i]);
		    strace("noc", 0, "num_packet");

		    // $display("[network] time=%0d input port %0d (sel:%0d) -> output Q %0d", $time, i, sel, dst);
		    if(!isValid(vc_type[i])) begin
			vc_type[i] <= Valid(flit.vc);
			// $display("[network] time=%0d setting input port %0d's vc to %0d", $time, i, flit.vc);
		    end
		    else dynamicAssert(flit.vc == validValue(vc_type[i]), "vc should be same coming in from same port"); 
		end
	    endmethod


	    method ActionValue#(Credit_t) getCredits;
		Bool send = False;
		for(Integer k=0; k < valueOf(XbarLanes); k=k+1) begin
		    if(inQs[i*valueOf(XbarLanes)+k].deq_happened) send = True;
		end
		if(send) begin
		    dynamicAssert(isValid(vc_type[i]), "error, didn't learn VC type yet");
		    // $display("[network] time=%0d returning credit to input port %0d, vc:%0d", $time, i, validValue(vc_type[i]));
		    return vc_type[i];
		end
		else begin
		    return Invalid;
		end
	    endmethod

	endinterface;
	send_ifaces[i] = ifc;
    end

     // From outQs to output

    for(Integer o=0; o < valueOf(NumRouters); o=o+1) begin

	let ifc = interface OutPort

	    method ActionValue#(Maybe#(Flit_t)) getFlit();
		actionvalue
		    Maybe#(Flit_t) flitOut = Invalid;
		    if((out_credits[o].value() != 0) && outQs[o].notEmpty) begin
			flitOut = Valid(outQs[o].first.flit);
			out_credits[o].sub(1);
			outQs[o].deq();

			if(outQs[o].first.prio) 
			    strace_end("noc", 0, "prio_delay", outQs[o].first.tag);
			else
			    strace_end("noc", 0, "delay", outQs[o].first.tag);
		    end
		    else if(outQs[o].notEmpty) begin
			$display("strace time=%0d component=noc inst=0 evt=out_stall val=1", $time);
		    end
		    return flitOut;
		endactionvalue
	    endmethod

	    method Action putCredits(Credit_t cr_in);
		if(isValid(cr_in)) out_credits[o].add(1);
	    endmethod

	endinterface;

	recv_ifaces[o] = ifc;
    end 

    for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin

	let ifc = interface RouterInfo
	    method RouterID_t getRouterID();
		return fromInteger(i);
	    endmethod
	endinterface;

	rt_ifaces[i] = ifc;
    end

    interface send_ports = send_ifaces;
    interface recv_ports = recv_ifaces;
    interface router_info = rt_ifaces; 

endmodule
*/

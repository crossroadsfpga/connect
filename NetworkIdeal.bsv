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


`include "inc.v"

import NetworkTypes::*;
import NetworkExternalTypes::*;


/*
module mkNetworkIdeal(Network);

    // Convention of outQs
    // outQs [ output port ][ input port ]

    Vector#(NumRouters, Vector#(NumRouters, FIFOCountIfc#(Flit_t, FlitBufferDepth))) outQs;
    Vector#(NumRouters, Count#(Bit#(TLog#(TAdd#(FlitBufferDepth,1))),1)) out_credits;
    Vector#(NumRouters, Vector#(NumRouters, PulseWire)) send_credits;
    Vector#(NumRouters, Reg#(Credit_t)) vc_type <- replicateM(mkReg(Invalid));
    Vector#(NumRouters, Arbiter#(NumRouters)) arbs <- replicateM(mkNetworkIdealArbiter);
	
    for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin
	Vector#(NumRouters, FIFOCountIfc#(Flit_t, FlitBufferDepth)) slice;
	if(i < valueOf(NetworkCut)) begin
	    for(Integer k=0; k < valueOf(NumRouters); k=k+1)
		slice[k] <- (k >= valueOf(NetworkCut)) ? mkNetworkIdealQueue : mkNetworkDummyQueue;
	end
	else begin
	    for(Integer k=0; k < valueOf(NumRouters); k=k+1)
		slice[k] <- (k < valueOf(NetworkCut)) ? mkNetworkIdealQueue : mkNetworkDummyQueue; 
	end
	outQs[i] = slice;

	out_credits[i] <- mkNetworkIdealCounter;
	send_credits[i] <- replicateM(mkPulseWire);
    end

    Vector#(NumRouters, InPort) send_ifaces;
    Vector#(NumRouters, OutPort) recv_ifaces;
    Vector#(NumRouters, RouterInfo) rt_ifaces;

    // Input Requests

    for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin
	let ifc = interface InPort
	    method Action putFlit(Maybe#(Flit_t) flit_in);
		if(flit_in matches tagged Valid .flit) begin
		    let dst = flit.dst;
		    $display("[network] input port %0d -> output Q %0d", i, dst);
		    outQs[dst][i].enq(flit);
		    if(!isValid(vc_type[i]))
			vc_type[i] <= Valid(flit.vc);
		    else dynamicAssert(flit.vc == validValue(vc_type[i]), "vc should be same coming in from same port"); 
		end
	    endmethod
	    method ActionValue#(Credit_t) getCredits;
		Bool send = False;
		for(Integer k=0; k < valueOf(NumRouters); k=k+1) begin
		    if(send_credits[k][i]) send = True;
		end
		if(send) begin
		    dynamicAssert(isValid(vc_type[i]), "error didnn't learn VC type yet...");
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

    for(Integer i=0; i < valueOf(NumRouters); i=i+1) begin

	let ifc = interface OutPort

	    method ActionValue#(Maybe#(Flit_t)) getFlit();
		actionvalue
		    Maybe#(Flit_t) flitOut = Invalid;
		    if(out_credits[i].value != 0) begin
			Vector#(NumRouters, Bool) raises = unpack(0);
			Maybe#(Bit#(TLog#(NumRouters))) msel = Invalid;

			for(Integer k=0; k < valueOf(NumRouters); k=k+1) begin
                            raises[k] = outQs[i][k].notEmpty;
			end

			msel = mkNetworkIdealEncoder(arbs[i].select(raises));

			if(msel matches tagged Valid .sel) begin
			    flitOut = Valid(outQs[i][sel].first);
			    outQs[i][sel].deq();
			    out_credits[i].sub(1);
			    send_credits[i][sel].send();
			end
			
		    end
		    return flitOut;
		endactionvalue
	    endmethod

	    method Action putCredits(Credit_t cr_in);
		if(isValid(cr_in)) out_credits[i].add(1);
	    endmethod

	endinterface;

	recv_ifaces[i] = ifc;
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

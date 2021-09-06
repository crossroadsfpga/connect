import Vector::*;
import FIFOF::*;
import Assert::*;
import BRAMFIFO::*;
import LUTFIFO::*;
import FIFOLevel::*;

interface DeqBus;
    method Action deq();
endinterface

interface FIFOCountDeqBus#(type data, numeric type depth, numeric type fanin);
    interface FIFOCountIfc#(data, depth) fifo;
    interface Vector#(fanin, DeqBus) deq;
    method Bool deq_happened();
endinterface

module mkFIFOCountDeqBus(FIFOCountDeqBus#(data, depth, fanin))
				    provisos(Bits#(data, data_nt),
					     Add#(1,z,data_nt));

    FIFOCountIfc#(data, depth) q	<- mkLUTFIFO(False);

    Vector#(fanin, PulseWire) deq_bus  <- replicateM(mkPulseWire);
    Vector#(fanin, DeqBus)    deq_ifcs;

    PulseWire deq_en <- mkPulseWire;

    (* fire_when_enabled *)
    rule dequeue(True);
	Bool deq = False;
	for(Integer i=0; i < valueOf(fanin); i=i+1) begin
	    if(deq_bus[i]) deq = True;
	end
	if(deq) deq_en.send();
    endrule

    (* fire_when_enabled *)
    rule forceDeq(True);
	if(deq_en) begin
	    q.deq();
	    dynamicAssert(q.notEmpty, "error popping an empty fifo");
	end 
    endrule

    for(Integer i=0; i < valueOf(fanin); i=i+1) begin
	let ifc = 
	    interface DeqBus;
		method Action deq();
		    deq_bus[i].send();
		endmethod
	    endinterface;

	deq_ifcs[i] = ifc;
    end

    interface FIFOCountIfc fifo;
	method Action enq(data din);
	    q.enq(din);
	endmethod
	method notEmpty = q.notEmpty;
	method notFull = q.notFull;
	method deq = noAction;
	method first = q.first;
	method clear = noAction;
	method count = q.count;
    endinterface

    interface deq  = deq_ifcs;

    method deq_happened() = deq_en;

endmodule

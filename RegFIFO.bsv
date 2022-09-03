import RegFile::*;
import FIFO::*;
import FIFOF::*;
import FIFOLevel::*;
import Assert::*;
import Vector::*;
import ConfigReg::*;

//import counters::*;
//import lutram::*;
//typedef Bit#(n) NumTypeParam#(numeric type n);

module mkRegFIFO#(Bool guarded)
 	(FIFOCountIfc#(value_t, depth))
	    provisos (Bits#(value_t, value_nt),
	              Literal#(value_t) );
		      

    FIFOCountIfc#(value_t, depth) fifo;
/*
    if(genC) begin
	fifo <- mkGFIFOCountWrap(guarded); 
    end
    else begin
	fifo <- mkRegFIFO_named("anonymous", guarded);
    end
*/ //comment by zhipeng for testing the synth results

    //if(genC) begin
	fifo <- mkGFIFOCountWrap(guarded); 
    //end
    //else begin
	//fifo <- mkRegFIFO_named("anonymous", guarded);
    //end
  
    return fifo;
endmodule


module mkGFIFOCountWrap#(Bool guarded) 
		    (FIFOCountIfc#(value_t, depth))
			provisos(Bits#(value_t, value_nt));

    FIFOCountIfc#(value_t, depth) fifo <- mkGFIFOCount(!guarded, !guarded, !guarded);

    RWire#(value_t)	din_w <- mkRWire();
    PulseWire		deq_w <- mkPulseWire();

    rule enq_work(isValid(din_w.wget));
	fifo.enq(validValue(din_w.wget));
    endrule

    rule deq_work(deq_w);
	fifo.deq();
    endrule

    method first = fifo.first;

    method notEmpty = fifo.notEmpty;

    method notFull = fifo.notFull;

    method Action enq(value_t din);
	din_w.wset(din);
    endmethod

    method Action deq();
	deq_w.send();
    endmethod

    method count = fifo.count;
    method clear = fifo.clear;

endmodule


module mkRegFIFO_named #(String name, Bool guarded)
	(FIFOCountIfc#(value_t, depth))
	    provisos (Bits#(value_t, value_nt),
	              Literal#(value_t),
		      Log#(depth, index_nt));

  //RegFile#(Bit#(index_nt), value_t)  mem <- mkRegFileFull();
  Vector#(depth, Reg#(value_t))            mem <- replicateM(mkConfigReg(0));
  //RegFile#(Bit#(index_nt), value_t)  mem <- mkRegFileFull();

  RWire#(value_t)           w_enq <- mkRWire;
  RWire#(void)              w_deq <- mkRWire;
  RWire#(void)              w_clr <- mkRWire;

  Reg#(Bit#(index_nt))              head <- mkReg(0);
  Reg#(Bit#(index_nt))              tail <- mkReg(0);

  //--debug--//
  Reg#(Bit#(64))          enq_cnt <- mkReg(0);
  Reg#(Bit#(64))          deq_cnt <- mkReg(0);

  Reg#(UInt#(TLog#(TAdd#(depth,1))))          size_cnt <- mkReg(0);

  staticAssert( valueOf(index_nt) > 0, "Index width must be > 0" );

//changed by zhipeng
  Bit#(index_nt) fifoSize = fromInteger(valueof(TSub#(depth,1)));

  function Bit#(index_nt) incr(Bit#(index_nt) i);
	if (i == fifoSize)
		return 0;
	else
    	return i+1;
  endfunction
//end change

  function Bit#(index_nt) decr(Bit#(index_nt) i);
    return i-1;
  endfunction

  Reg#(Bool)  full           <- mkReg(False);
  Reg#(Bool)  almost_full    <- mkReg(False);
  Reg#(Bool)  empty          <- mkReg(True);


  (* fire_when_enabled *)
  rule work (True);

    if(isValid(w_clr.wget)) begin
      head <= 0;
      tail <= 0;
      enq_cnt <= 0;
      deq_cnt <= 0;
      full <= False;
      almost_full <= False;
      empty <= True;
      size_cnt <= 0;
    end
    
    else begin

    if (isValid(w_deq.wget)) begin
      head <= incr( head );
      deq_cnt <= deq_cnt + 1;
    end

    if (isValid(w_enq.wget)) begin
      let value = validValue(w_enq.wget);
      //mem.upd( tail, value );
      mem[tail] <= value;
      tail <= incr( tail );
      enq_cnt <= enq_cnt + 1;
    end

    Bool nfull         = full;
    Bool nempty        = empty;
    Bool nalmost_full  = almost_full;
    let nsize          = size_cnt;

    if(isValid(w_deq.wget)  &&  isValid(w_enq.wget)) begin // queue remains same size, no change in status signals
      nfull         = full;
      nempty        = empty;
      nalmost_full  = almost_full;
    end
    else if(isValid(w_deq.wget)) begin
      nfull         = False;
      nalmost_full  = ( tail == head );
      nempty        = ( incr( head ) == tail );
      nsize         = size_cnt-1;
    end
    else if(isValid(w_enq.wget)) begin
      nfull         = ( incr(tail) == head );
      nalmost_full  = ( (tail+2) == head );
      nempty        = False; // if enqueuing, then definitely not empty
      nsize         = size_cnt+1;
    end

    empty        <= nempty;
    full         <= nfull;
    almost_full  <= nalmost_full || nfull;
    size_cnt     <= nsize;

    end
  endrule

  continuousAssert( ! (empty && ( enq_cnt != deq_cnt ) ), "mismatched in enq/deq count" );

  Bool logical_empty  =  (head == tail)  &&  !full; // not synthesized
  continuousAssert( empty == logical_empty, "error in empty signals" );

  let pos = getStringPosition(name);
  String pos_str = printPosition(pos); 
 
  //method value_t first();
  //  let rslt = mem[head];
  //  return rslt;
  //endmethod

  //method value_t first   =  mem.sub( head );
  method value_t first   =  mem[head]; 
  method notFull         =  !full;
  method notEmpty        =  !empty;
  //method almostFull      =  almost_full;


  method Action enq(value_t value)  if (!full || !guarded);
    w_enq.wset(value);
    if(full)
      $display("location of dfifo: ", pos_str);
    dynamicAssert( !full, "ouch, enqueuing to full FIFO" );
  endmethod

  method Action deq()  if (!empty || !guarded);
    w_deq.wset(?);
    if(empty) 
      $display("location of dfifo: ", pos_str);
    dynamicAssert( !empty, "ouch, dequeueing from empty FIFO" );
  endmethod

  method Action clear();
    w_clr.wset(?);
  endmethod

  method count() = size_cnt;

endmodule


///////////////////////////////////////////////
// LUT FIFO test

typedef 8 FIFODepth;
typedef Bit#(32) Data_t;
typedef FIFOCountIfc#(Data_t, FIFODepth) RegFIFOSynth;

(* synthesize *)
module mkRegFIFOSynth(RegFIFOSynth);
  RegFIFOSynth f <- mkRegFIFO(False);
  return f;
endmodule

/*typedef FIFOF#(Data_t) RegFIFOSynth2;
(* synthesize *)
module mkRegFIFOSynth2(RegFIFOSynth2);
  RegFIFOSynth2 f <- mkUGSizedFIFOF(4);
  return f;
endmodule
*/

/*  
module mkSizedLUTRAMFIFOF#(NumTypeParam#(t_DEPTH) dummy)
  //
  //interface:
              (FIFOF#(data_T))
  provisos
          (Bits#(data_T, data_SZ));

  LUTRAM#(Bit#(TLog#(t_DEPTH)), data_T) rs <- mkLUTRAMU();

  COUNTER#(TLog#(t_DEPTH)) head <- mkLCounter(0);
  COUNTER#(TLog#(t_DEPTH)) tail <- mkLCounter(0);

  Bool full  = head.value() == (tail.value() + 1);
  Bool empty = head.value() == tail.value();

  //method Action enq(data_T d) if (!full);
  method Action enq(data_T d);

    rs.upd(tail.value(), d);
    tail.up();

  endmethod

  //method data_T first() if (!empty);
  method data_T first();

    return rs.sub(head.value());

  endmethod

  method Action deq();

    head.up();

  endmethod

  method Action clear();

    tail.setC(0);
    head.setC(0);

  endmethod

  method Bool notEmpty();
    return !empty;
  endmethod

  method Bool notFull();
    return !full;
  endmethod

endmodule
*/


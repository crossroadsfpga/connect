/* =========================================================================
 * Filename:            MultiFIFOMem.bsv
 * Date created:        05-10-2011
 * Last modified:       05-10-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * This module implements multiple logical FIFOs hosted in a single LUTRAM 
 * memory. Only a single enqueue and dequeue operation are supported in each
 * cycle. (enqueue and dequeue do not have to be to/from the same logical FIFO)
 * Used as a building block for input queued routers.
 *
 * =========================================================================
 */

import Vector::*;
import RF_16ports::*;
import RF_1port::*;
import RegFile::*;
import ConfigReg::*;
import StmtFSM::*;			// just for creating a test sequence
import Assert::*;

`include "inc.v"

// -- MultiFIFOMem Interface --
//interface MultiFIFOMem#(Integer num_fifos, Integer fifo_depth, type fifo_data_t)
//  method Action enq(Bit#(TLog#(num_fifos)) fifo_in, fifo_data_t data_in);     // Enqueues flit into voq voq_enq
//  method ActionValue#(fifo_data_t) deq(Bit#(TLog#(num_fifos) fifo_out);  // Dequeues flit from voq voq_deq
//  method Vector#(num_fifos, Bool) notEmpty();            // Used to query which voqs have flits
//  method Vector#(num_fifos, Bool) notFull();             // Used to query which voqs are not full
//endinterface

interface MultiFIFOMem#(type fifo_data_t, numeric type num_fifos, numeric type fifo_depth);
  (* always_ready *) method Action enq(Bit#(TLog#(num_fifos)) fifo_in, fifo_data_t data_in);     // Enqueues flit into voq voq_enq
  (* always_ready *) method ActionValue#(fifo_data_t) deq(Bit#(TLog#(num_fifos)) fifo_out);  // Dequeues flit from voq voq_deq
  (* always_ready *) method Vector#(num_fifos, Bool) notEmpty();            // Used to query which voqs have flits
  (* always_ready *) method Vector#(num_fifos, Bool) notFull();             // Used to query which voqs are not full
endinterface

module mkMultiFIFOMem#( Bool storeHeadsTailsInLUTRAM, Integer full_margin)
                      ( MultiFIFOMem#(fifo_data_t, num_fifos, fifo_depth) )
  provisos( Bits#(fifo_data_t, fifo_data_width_t));
  
  staticAssert(full_margin < 4, "Full margin can only take values 0,1,2 or 3");
  //static_assert(full_margin < 3, "Full margin can only take values 0, 1 or 2");
  MultiFIFOMem#(fifo_data_t, num_fifos, fifo_depth) mf_ifc;
  if (storeHeadsTailsInLUTRAM) begin
    mf_ifc <- mkMultiFIFOMem_HeadTailsInLUTRAM(full_margin);
  end else begin
    mf_ifc <- mkMultiFIFOMem_HeadTailsInRegs(full_margin);
  end
  //MultiFIFOMemSynth mf <- mkMultiFIFOMemHeadTailsInLUTRAM();
  return mf_ifc;
endmodule
 

module mkMultiFIFOMem_HeadTailsInRegs#( Integer full_margin )
                                      (MultiFIFOMem#(fifo_data_t, num_fifos, fifo_depth))
  provisos( Bits#(fifo_data_t, fifo_data_width_t));
  String name = "MultiFIFOMem";
  
  //typedef Bit#(TLog#(num_fifos))                              FIFOIdx_t;
  //typedef Bit#(TLog#(fifo_depth))                             FIFOPtr_t;  // Pointer for individual queue
  //typedef Bit#(TAdd#( TLog#(num_queues), TLog#(queue_depth) )) FIFOMemIdx_t;     // Used to index fifoMem that hosts multiple queues

  // LUT RAM that stores multiple queues
  //RF_16ports#( Bit#(TAdd#( TLog#(num_fifos), TLog#(fifo_depth) ))  , fifo_data_t)      fifoMem     <- mkRF_16ports();
  //let hi = TMul#(num_fifos, fifo_depth);
  //RegFile#( Bit#(TAdd#( TLog#(num_fifos), TLog#(fifo_depth) ))  , fifo_data_t)      fifoMem     <- mkRegFile(0, fromInteger(valueOf(TMul#(num_fifos, fifo_depth))-1 ));
  //RegFile#( Bit#(TAdd#( TLog#(num_fifos), TLog#(fifo_depth) ))  , fifo_data_t)      fifoMem     <- mkRegFileFull();
  RF_1port#( Bit#(TAdd#( TLog#(num_fifos), TLog#(fifo_depth) ))  , fifo_data_t)      fifoMem     <- mkRF_1port();
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     heads    <- replicateM(mkConfigReg(0));
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     tails    <- replicateM(mkConfigReg(0));
  Vector#(num_fifos, Reg#(Bool))          not_empty <- replicateM(mkConfigReg(False));
  Vector#(num_fifos, Reg#(Bool))          not_full  <- replicateM(mkConfigReg(True));

  Vector#(num_fifos, Reg#(Bool))          not_full_dyn  <- replicateM(mkConfigReg(True));//added by zhipeng
  
  // Wires to have enq and deq communicate to determine which queues are empty
  Wire#(Maybe#( Bit#(TLog#(num_fifos)) ))                wrFIFO <- mkDWire(Invalid);  
  Wire#(Maybe#( Bit#(TLog#(num_fifos)) ))                rdFIFO <- mkDWire(Invalid);  
  
  // Wires to update head tail pointers
  Wire#(Bit#(TLog#(fifo_depth)))                        new_tail <- mkDWire(0);  
  Wire#(Bit#(TLog#(fifo_depth)))                        new_head <- mkDWire(0);
  
  // These "look-ahead" tail pointers are used to provide extra margin for full signal when pipelining.
  // They reduce the effective size of each fifo.
  Wire#(Bit#(TLog#(fifo_depth)))                        new_new_tail <- mkDWire(0);  
  Wire#(Bit#(TLog#(fifo_depth)))                        new_new_new_tail <- mkDWire(0);  
  Wire#(Bit#(TLog#(fifo_depth)))                        new_new_new_new_tail <- mkDWire(0);  

//added by zhipeng
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     new_tail_r    <- replicateM(mkConfigReg(0));
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     new_new_tail_r    <- replicateM(mkConfigReg(0));
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     new_new_new_tail_r    <- replicateM(mkConfigReg(0));
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     new_new_new_new_tail_r    <- replicateM(mkConfigReg(0));
//end add
  
  Wire#(Bit#(TLog#(fifo_depth)))                        cur_tail <- mkDWire(0);  
  Wire#(Bit#(TLog#(fifo_depth)))                        cur_head <- mkDWire(0);
  //Wire#(QueuePtr_t)                                   wrPtr <- mkDWire(0);  
  //Wire#(qPtr)                                      rdPtr <- mkDWire(0);  
//added by zhipeng
  Bit#(TLog#(fifo_depth)) fifoSize = fromInteger(valueof(TSub#(fifo_depth,1)));


  function Bit#(TLog#(fifo_depth)) incr(Bit#(TLog#(fifo_depth)) i);
	if (i == fifoSize)
		return 0;
	else
    	return i+1;
  endfunction
//end add

  rule update_heads_tails(True);
    // update tail
    if(isValid(wrFIFO)) begin
      tails[wrFIFO.Valid] <= new_tail;
    end
    // update head
    if(isValid(rdFIFO)) begin
      heads[rdFIFO.Valid] <= new_head;
    end

    // update not_empty not_full
    if(isValid(wrFIFO)) begin // somethine was enqueued
      let fifo_in = wrFIFO.Valid;
      if(!isValid(rdFIFO) || (isValid(rdFIFO) && fifo_in != rdFIFO.Valid)) begin // only need to update if a data wasn't dequeued from the same fifo
	not_empty[fifo_in] <= True;

//Added by zhipeng
	//no matter what margin is, the "true" full is new_tail == heads
	if(new_tail == heads[fifo_in]) begin 
		not_full_dyn[fifo_in] <= False;
	end
//end add

	if(full_margin == 0) begin // no margin, full actually corresponds to full signal
	  if(new_tail == heads[fifo_in]) begin  // I enqueued and fifo became full
	    not_full[fifo_in] <= False;
	    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
	  end
	end else if (full_margin == 1) begin // 1 cycle margin, full actually means that there is only 1 slot left
	  if(new_tail == heads[fifo_in] || new_new_tail == heads[fifo_in]) begin  // I enqueued and fifo became full or almost full
	    not_full[fifo_in] <= False;
	    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
	  end
	end else if (full_margin == 2) begin // 2 cycle margin, full actually means that there is only 2 slot left
	  if(new_tail == heads[fifo_in] || new_new_tail == heads[fifo_in] || new_new_new_tail == heads[fifo_in]) begin  // I enqueued and fifo became full or almost full
	    not_full[fifo_in] <= False;
	    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
	  end
	end else if (full_margin == 3) begin // 3 cycle margin, full actually means that there is only 2 slot left
	  if(new_tail == heads[fifo_in] || new_new_tail == heads[fifo_in] || new_new_new_tail == heads[fifo_in] || new_new_new_new_tail == heads[fifo_in]) begin  // I enqueued and fifo became full or almost full
	    not_full[fifo_in] <= False;
	    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
	  end
	end 
      end
    end

    if(isValid(rdFIFO)) begin
      let fifo_out = rdFIFO.Valid;
      if(!isValid(wrFIFO) || (isValid(wrFIFO) && fifo_out != wrFIFO.Valid)) begin // only need to update if data wasn't enqueued to the same fifo
//	not_full[fifo_out] <= True;//comment by zhipeng
		//changed by zhipeng, We can't say the fifo is not_full by just dequeuing one flit. Because of the margin.
		not_full_dyn[fifo_out] <= True;	
		if (full_margin == 0) begin 
			not_full[fifo_out] <= True;
		end else if (full_margin == 1) begin 
			if (new_head == new_new_tail_r[fifo_out]) begin
				not_full[fifo_out] <= False;
			end else begin
				not_full[fifo_out] <= True;	
			end
		end else if (full_margin == 2) begin 	
			if (new_head == new_new_tail_r[fifo_out] || new_head == new_new_new_tail_r[fifo_out] ) begin
				not_full[fifo_out] <= False;
			end else begin
				not_full[fifo_out] <= True;	
			end		
		end else if (full_margin == 3) begin 	
			if (new_head == new_new_tail_r[fifo_out] || new_head == new_new_new_tail_r[fifo_out] || new_head == new_new_new_new_tail_r[fifo_out]) begin
				not_full[fifo_out] <= False;
			end else begin
				not_full[fifo_out] <= True;	
			end		
		end				
		//end change
	if(new_head == tails[fifo_out]) begin // I just became empty
	  not_empty[fifo_out] <= False;
	  `DBG_DETAIL(("Queue %d: Became EMPTY", fifo_out ));
	end
      end
    end

  endrule

  method Action enq(Bit#(TLog#(num_fifos)) fifo_in, fifo_data_t data_in);     // Enqueues flit into fifo fifo_in
    //dynamicAssert(fifo_in < fromInteger(valueOf(num_fifos)), "fifo_in >= num_fifos: Trying to index non-existent FIFO in MultiFIFOMem!");
    if(!not_full_dyn[fifo_in]) begin
      `DBG(("2Enqueing to full FIFO - fifo_in:%d", fifo_in));
      `DBG(("Data dump of element that filled FIFO: %x", data_in));
    end
    //dynamicAssert(not_full[fifo_in], "Enqueing to full FIFO in MultiFIFOMem!");//comment by zhipeng
    dynamicAssert(not_full_dyn[fifo_in], "Enqueing to full FIFO in MultiFIFOMem!");//changed by zhipeng
    //let vcWrPtr = tails.read_ports[0].read(fl.vc);
    let fifoWrPtr = tails[fifo_in];
    let enqAddr = {fifo_in, fifoWrPtr};
    `DBG_DETAIL(("Queue %d: Enqueueing %x", fifo_in, data_in ));
    fifoMem.write(enqAddr, data_in);       // Enqueue data
    //fifoMem.upd(enqAddr, data_in);       // Enqueue data
    //tails.write(fl.vc, vcWrPtr+1); // Advance write pointer
/*
    let next_tail = fifoWrPtr+1;
    let next_next_tail = next_tail + 1;
    let next_next_next_tail = next_next_tail + 1;
    cur_tail <= fifoWrPtr;
    new_tail <= next_tail;
    new_new_tail <= next_tail+1;
    new_new_new_tail <= next_next_tail+1;
    new_new_new_new_tail <= next_next_next_tail+1;
*/ //comment by zhipeng
//changed by zhipeng
    let next_tail = incr(fifoWrPtr);
    let next_next_tail = incr(next_tail);
    let next_next_next_tail = incr(next_next_tail);
    let next_next_next_next_tail = incr(next_next_next_tail);
    cur_tail <= fifoWrPtr;
    new_tail <= next_tail;
    new_new_tail <= next_next_tail;
    new_new_new_tail <= next_next_next_tail;
    new_new_new_new_tail <= next_next_next_next_tail;

    new_tail_r[fifo_in] <= next_tail;
    new_new_tail_r[fifo_in] <= next_next_tail;
    new_new_new_tail_r[fifo_in] <= next_next_next_tail;
    new_new_new_new_tail_r[fifo_in] <= next_next_next_next_tail;
//end change
    //tails[fifo_in] <= next_tail; // Advance write pointer

    // update wire used by deq
    wrFIFO <= tagged Valid fifo_in;
    
    // update not_empty not_full
    //if(!isValid(rdFIFO) || fifo_in != rdFIFO.Valid) begin // only need to update if a data wasn't dequeued from the same fifo
    //  not_empty[fifo_in] <= True;
    //  if(next_tail == heads[fifo_in]) begin  // I enqueued and fifo became full
    //    not_full[fifo_in] <= False;
    //    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
    //  end
    //end

  endmethod
  
  method ActionValue#(fifo_data_t) deq(Bit#(TLog#(num_fifos)) fifo_out);  // Dequeues flit from fifo_out
    //dynamicAssert(fifo_out < fromInteger(valueOf(num_fifos)), "fifo_in >= num_fifos: Trying to index non-existent FIFO in MultiFIFOMem!");
    dynamicAssert(not_empty[fifo_out], "Dequeing from empty FIFO in MultiFIFOMem!");
    //let vcRdPtr = heads.read_ports[0].read(vc);
    let fifoRdPtr = heads[fifo_out];
    let deqAddr = {fifo_out, fifoRdPtr};
    //let data = fifoMem.read_ports[0].read(deqAddr);       // Dequeue data
    //let data = fifoMem.sub(deqAddr);       // Dequeue data
    let data = fifoMem.read(deqAddr);       // Dequeue data
    `DBG_DETAIL(("Queue %d: Dequeueing %x", fifo_out, data ));
    //heads.write(fl.vc, vcRdPtr+1);   // Advance read pointer
    //let next_head = fifoRdPtr+1; //comment by zhipeng
    let next_head = incr(fifoRdPtr);//changed by zhipeng
    cur_head <= fifoRdPtr;
    new_head <= next_head;
    //heads[fifo_out] <= next_head;   // Advance read pointer
  
    // update wire used by enqFlit method
    rdFIFO <= tagged Valid fifo_out;

    // update not_empty not_full
    //if(!isValid(wrFIFO) || fifo_out != wrFIFO.Valid) begin // only need to update if data wasn't enqueued to the same fifo
    //  not_full[fifo_out] <= True;
    //  if(next_head == tails[fifo_out]) begin // I just became empty
    //    not_empty[fifo_out] <= False;
    //    `DBG_DETAIL(("Queue %d: Became EMPTY", fifo_out ));
    //  end
    //end

    return data;
  endmethod

  method Vector#(num_fifos, Bool) notEmpty();            // Used to query which queues have data (i.e. are not empty)
    return readVReg(not_empty);
  endmethod

  method Vector#(num_fifos, Bool) notFull();             // Used to query which queues have space (i.e. are  not full)
    return readVReg(not_full);
  endmethod
endmodule




////////////////////////////////////////////////////////////
// More parameterized version
module mkMultiFIFOMem_HeadTailsInLUTRAM#( Integer full_margin )
                                        (MultiFIFOMem#(fifo_data_t, num_fifos, fifo_depth))
  provisos( Bits#(fifo_data_t, fifo_data_width_t));
  String name = "MultiFIFOMem";
  
  //typedef Bit#(TLog#(num_fifos))                              FIFOIdx_t;
  //typedef Bit#(TLog#(fifo_depth))                             FIFOPtr_t;  // Pointer for individual queue
  //typedef Bit#(TAdd#( TLog#(num_queues), TLog#(queue_depth) )) FIFOMemIdx_t;     // Used to index fifoMem that hosts multiple queues

  // LUT RAM that stores multiple queues
  //RF_16ports#( Bit#(TAdd#( TLog#(num_fifos), TLog#(fifo_depth) ))  , fifo_data_t)      fifoMem     <- mkRF_16ports();
  //let hi = TMul#(num_fifos, fifo_depth);
  //RegFile#( Bit#(TAdd#( TLog#(num_fifos), TLog#(fifo_depth) ))  , fifo_data_t)      fifoMem     <- mkRegFile(0, fromInteger(valueOf(TMul#(num_fifos, fifo_depth))-1 ));
  //RegFile#( Bit#(TAdd#( TLog#(num_fifos), TLog#(fifo_depth) ))  , fifo_data_t)      fifoMem     <- mkRegFileFull();
  RF_1port#( Bit#(TAdd#( TLog#(num_fifos), TLog#(fifo_depth) ))  , fifo_data_t)      fifoMem     <- mkRF_1port();

  RF_16ports#( Bit#(TLog#(num_fifos)), Bit#(TLog#(fifo_depth)) )  heads <- mkRF_16ports();
  RF_16ports#( Bit#(TLog#(num_fifos)), Bit#(TLog#(fifo_depth)) )  tails <- mkRF_16ports();
  Vector#(num_fifos, Reg#(Bool))          not_empty <- replicateM(mkConfigReg(False));
  Vector#(num_fifos, Reg#(Bool))          not_full  <- replicateM(mkConfigReg(True));
 
  Vector#(num_fifos, Reg#(Bool))          not_full_dyn  <- replicateM(mkConfigReg(True)); //added by zhipeng
  // Wires to have enq and deq communicate to determine which queues are empty
  Wire#(Maybe#( Bit#(TLog#(num_fifos)) ))                wrFIFO <- mkDWire(Invalid);  
  Wire#(Maybe#( Bit#(TLog#(num_fifos)) ))                rdFIFO <- mkDWire(Invalid);  
  
  // Wires to update head tail pointers
  Wire#(Bit#(TLog#(fifo_depth)))                        new_tail <- mkDWire(0);  
  Wire#(Bit#(TLog#(fifo_depth)))                        new_head <- mkDWire(0);
  
  // These "look-ahead" tail pointers are used to provide extra margin for full signal when pipelining.
  // They reduce the effective size of each fifo.
  Wire#(Bit#(TLog#(fifo_depth)))                        new_new_tail <- mkDWire(0);  
  Wire#(Bit#(TLog#(fifo_depth)))                        new_new_new_tail <- mkDWire(0);  
  Wire#(Bit#(TLog#(fifo_depth)))                        new_new_new_new_tail <- mkDWire(0);  

//added by zhipeng
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     new_tail_r    <- replicateM(mkConfigReg(0));
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     new_new_tail_r    <- replicateM(mkConfigReg(0));
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     new_new_new_tail_r    <- replicateM(mkConfigReg(0));
  Vector#(num_fifos, Reg#( Bit#(TLog#(fifo_depth)) ))     new_new_new_new_tail_r    <- replicateM(mkConfigReg(0));
//end add

  Wire#(Bit#(TLog#(fifo_depth)))                        cur_tail <- mkDWire(0);  
  Wire#(Bit#(TLog#(fifo_depth)))                        cur_head <- mkDWire(0);
  //Wire#(QueuePtr_t)                                   wrPtr <- mkDWire(0);  
  //Wire#(qPtr)                                      rdPtr <- mkDWire(0);  
//added by zhipeng
  Bit#(TLog#(fifo_depth)) fifoSize = fromInteger(valueof(TSub#(fifo_depth,1)));


  function Bit#(TLog#(fifo_depth)) incr(Bit#(TLog#(fifo_depth)) i);
	if (i == fifoSize)
		return 0;
	else
    	return i+1;
  endfunction
//end add

  rule update_heads_tails(True);
    // update tail
    if(isValid(wrFIFO)) begin
      tails.write(wrFIFO.Valid, new_tail);
    end
    // update head
    if(isValid(rdFIFO)) begin
      heads.write(rdFIFO.Valid, new_head);
    end

    // update not_empty not_full
    if(isValid(wrFIFO)) begin
      let fifo_in = wrFIFO.Valid;
      if(!isValid(rdFIFO) || fifo_in != rdFIFO.Valid) begin // only need to update if a data wasn't dequeued from the same fifo
	not_empty[fifo_in] <= True;
	Bit#(TLog#(fifo_depth)) cur_head;
	cur_head = heads.read_ports[0].read(fifo_in);

//added by zhipeng
	//no matter what margin is, the "true" full is new_tail == heads
	if(new_tail == cur_head) begin  //Added by zhipeng
		not_full_dyn[fifo_in] <= False;
	end
//end add

	if(full_margin == 0) begin // no margin, full actually corresponds to full signal
	  if(new_tail == cur_head) begin  // I enqueued and fifo became full
	    not_full[fifo_in] <= False;
	    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
	  end
	end else if (full_margin == 1) begin // 1 cycle margin, full actually means that there is only 1 slot left
	  if(new_tail == cur_head || new_new_tail == cur_head) begin  // I enqueued and fifo became full or almost full
	    not_full[fifo_in] <= False;
	    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
	  end
	end else if (full_margin == 2) begin // 2 cycle margin, full actually means that there is only 2 slot left
	  if(new_tail == cur_head || new_new_tail == cur_head || new_new_new_tail == cur_head) begin  // I enqueued and fifo became full or almost full
	    not_full[fifo_in] <= False;
	    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
	  end
	end else if (full_margin == 3) begin // 3 cycle margin, full actually means that there is only 2 slot left
	  if(new_tail == cur_head || new_new_tail == cur_head || new_new_new_tail == cur_head || new_new_new_new_tail == cur_head) begin  // I enqueued and fifo became full or almost full
	    not_full[fifo_in] <= False;
	    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
	  end
	end
      end
    end

    if(isValid(rdFIFO)) begin
      let fifo_out = rdFIFO.Valid;
      if(!isValid(wrFIFO) || fifo_out != wrFIFO.Valid) begin // only need to update if data wasn't enqueued to the same fifo
//	not_full[fifo_out] <= True;//comment by zhipeng
		//changed by zhipeng, We can't say the fifo is not_full by just dequeuing one flit. Because of the margin.
		not_full_dyn[fifo_out] <= True;	
		if (full_margin == 0) begin 
			not_full[fifo_out] <= True;
		end else if (full_margin == 1) begin 
			if (new_head == new_new_tail_r[fifo_out]) begin
				not_full[fifo_out] <= False;
			end else begin
				not_full[fifo_out] <= True;	
			end
		end else if (full_margin == 2) begin 	
			if (new_head == new_new_tail_r[fifo_out] || new_head == new_new_new_tail_r[fifo_out] ) begin
				not_full[fifo_out] <= False;
			end else begin
				not_full[fifo_out] <= True;	
			end		
		end else if (full_margin == 3) begin 	
			if (new_head == new_new_tail_r[fifo_out] || new_head == new_new_new_tail_r[fifo_out] || new_head == new_new_new_new_tail_r[fifo_out]) begin
				not_full[fifo_out] <= False;
			end else begin
				not_full[fifo_out] <= True;	
			end		
		end				
		//end change
	Bit#(TLog#(fifo_depth)) cur_tail;
	cur_tail = tails.read_ports[0].read(fifo_out);
	if(new_head == cur_tail) begin // I just became empty
	  not_empty[fifo_out] <= False;
	  `DBG_DETAIL(("Queue %d: Became EMPTY", fifo_out ));
	end
      end
    end

  endrule

  method Action enq(Bit#(TLog#(num_fifos)) fifo_in, fifo_data_t data_in);     // Enqueues flit into fifo fifo_in
    //dynamicAssert(fifo_in < fromInteger(valueOf(num_fifos)), "fifo_in >= num_fifos: Trying to index non-existent FIFO in MultiFIFOMem!");
   // dynamicAssert(not_full[fifo_in], "Enqueing to full FIFO in MultiFIFOMem!");//changed by zhipeng
    dynamicAssert(not_full_dyn[fifo_in], "Enqueing to full FIFO in MultiFIFOMem!");//changed by zhipeng
    //let vcWrPtr = tails.read_ports[0].read(fl.vc);

    Bit#(TLog#(fifo_depth)) fifoWrPtr;
    fifoWrPtr = tails.read_ports[1].read(fifo_in);

    let enqAddr = {fifo_in, fifoWrPtr};
    `DBG_DETAIL(("Queue %d: Enqueueing %x", fifo_in, data_in ));
    fifoMem.write(enqAddr, data_in);       // Enqueue data
    //fifoMem.upd(enqAddr, data_in);       // Enqueue data
    //tails.write(fl.vc, vcWrPtr+1); // Advance write pointer
/*
    let next_tail = fifoWrPtr+1;
    let next_next_tail = next_tail + 1;
    let next_next_next_tail = next_next_tail + 1;
    cur_tail <= fifoWrPtr;
    new_tail <= next_tail;
    new_new_tail <= next_tail+1;
    new_new_new_tail <= next_next_tail+1;
    new_new_new_new_tail <= next_next_next_tail+1;
    //tails[fifo_in] <= next_tail; // Advance write pointer
*/ //commented by zhipeng
//changed by zhipeng
    let next_tail = incr(fifoWrPtr);
    let next_next_tail = incr(next_tail);
    let next_next_next_tail = incr(next_next_tail);
    let next_next_next_next_tail = incr(next_next_next_tail);
    cur_tail <= fifoWrPtr;
    new_tail <= next_tail;
    new_new_tail <= next_next_tail;
    new_new_new_tail <= next_next_next_tail;
    new_new_new_new_tail <= next_next_next_next_tail;

    new_tail_r[fifo_in] <= next_tail;
    new_new_tail_r[fifo_in] <= next_next_tail;
    new_new_new_tail_r[fifo_in] <= next_next_next_tail;
    new_new_new_new_tail_r[fifo_in] <= next_next_next_next_tail;
//end change
    // update wire used by deq
    wrFIFO <= tagged Valid fifo_in;
    
    // update not_empty not_full
    //if(!isValid(rdFIFO) || fifo_in != rdFIFO.Valid) begin // only need to update if a data wasn't dequeued from the same fifo
    //  not_empty[fifo_in] <= True;
    //  if(next_tail == heads[fifo_in]) begin  // I enqueued and fifo became full
    //    not_full[fifo_in] <= False;
    //    `DBG_DETAIL(("Queue %d: Became FULL", fifo_in ));
    //  end
    //end

  endmethod
  
  method ActionValue#(fifo_data_t) deq(Bit#(TLog#(num_fifos)) fifo_out);  // Dequeues flit from fifo_out
    //dynamicAssert(fifo_out < fromInteger(valueOf(num_fifos)), "fifo_in >= num_fifos: Trying to index non-existent FIFO in MultiFIFOMem!");
    dynamicAssert(not_empty[fifo_out], "Dequeing from empty FIFO in MultiFIFOMem!");
    //let vcRdPtr = heads.read_ports[0].read(vc);

    Bit#(TLog#(fifo_depth)) fifoRdPtr;
    fifoRdPtr = heads.read_ports[1].read(fifo_out);

    //let fifoRdPtr = heads[fifo_out];
    let deqAddr = {fifo_out, fifoRdPtr};
    //let data = fifoMem.read_ports[0].read(deqAddr);       // Dequeue data
    //let data = fifoMem.sub(deqAddr);       // Dequeue data
    let data = fifoMem.read(deqAddr);       // Dequeue data
    `DBG_DETAIL(("Queue %d: Dequeueing %x", fifo_out, data ));
    //heads.write(fl.vc, vcRdPtr+1);   // Advance read pointer
    //let next_head = fifoRdPtr + 1;//comment by zhipeng
    let next_head = incr(fifoRdPtr);//changed by zhipeng
    cur_head <= fifoRdPtr;
    new_head <= next_head;
    //heads[fifo_out] <= next_head;   // Advance read pointer
  
    // update wire used by enqFlit method
    rdFIFO <= tagged Valid fifo_out;

    // update not_empty not_full
    //if(!isValid(wrFIFO) || fifo_out != wrFIFO.Valid) begin // only need to update if data wasn't enqueued to the same fifo
    //  not_full[fifo_out] <= True;
    //  if(next_head == tails[fifo_out]) begin // I just became empty
    //    not_empty[fifo_out] <= False;
    //    `DBG_DETAIL(("Queue %d: Became EMPTY", fifo_out ));
    //  end
    //end

    return data;
  endmethod

  method Vector#(num_fifos, Bool) notEmpty();            // Used to query which queues have data (i.e. are not empty)
    return readVReg(not_empty);
  endmethod

  method Vector#(num_fifos, Bool) notFull();             // Used to query which queues have space (i.e. are  not full)
    return readVReg(not_full);
  endmethod
endmodule





//////////////////////////////////////////////////////////
// Example instance and Testbench

//typedef 10 NumFIFOs;
//typedef 2 FIFODepth;
//typedef Bit#(128) Data_t;

typedef 1 NumFIFOs;
typedef 9 FIFODepth;
typedef Bit#(128) Data_t;

typedef MultiFIFOMem#(Data_t, NumFIFOs, FIFODepth) MultiFIFOMemSynth; 

(* synthesize *)
module mkMultiFIFOMemSynth(MultiFIFOMemSynth);
  //MultiFIFOMemSynth mf <- mkMultiFIFOMem(True );
  MultiFIFOMemSynth mf <- mkMultiFIFOMem(False , 0);
  //MultiFIFOMemSynth mf <- mkMultiFIFOMemHeadTailsInLUTRAM();
  return mf;
 
  //----- Long form isntantiation -----
  //MultiFIFOMemSynth multi_fifos_ifc();
  //mkMultiFIFOMem multi_fifos(multi_fifos_ifc);
  //return multi_fifos_ifc;
  
  //method enq = multi_fifos_ifc.enq;
  //method deq = multi_fifos_ifc.deq;
  //method notEmpty = multi_fifos_ifc.notEmpty;
  //method notFull = multi_fifos_ifc.notFull;

endmodule

module mkMultiFIFOMemTest(Empty);
  MultiFIFOMemSynth mf<- mkMultiFIFOMemSynth();

  Stmt test_seq = seq
    mf.enq(0, 128'h00000000000000000000000000000000);
    mf.enq(0, 128'h00000000000000011111111111111111);
    mf.enq(1, 128'h11111111111111100000000000000000);
    mf.enq(0, 128'h00000000000000022222222222222222);
    action Data_t test <- mf.deq(0); endaction
    mf.enq(0, 128'h00000000000000033333333333333333);
    mf.enq(1, 128'h11111111111111111111111111111111);
    mf.enq(0, 128'h00000000000000044444444444444444);
    action Data_t test <- mf.deq(0); endaction
    mf.enq(1, 128'h11111111111111122222222222222222);
    action Data_t test <- mf.deq(1); endaction
    action Data_t test <- mf.deq(1); endaction
    action Data_t test <- mf.deq(1); endaction

    noAction;
//    // -- Test Error conditions --
//    mf.enq(9, 128'h00000000000000033333333333333333);
//    mf.enq(9, 128'h00000000000000033333333333333333);
//    mf.enq(9, 128'h00000000000000033333333333333333);
//    mf.enq(9, 128'h00000000000000033333333333333333);
//    // Enqueing to full fifo
//    mf.enq(9, 128'h00000000000000033333333333333333);
//    
//    noAction;
//    // Dequing from empty fifo
//    action Data_t test <- mf.deq(5); endaction
//
//    noAction;
//    // Enqueing to non-existent fifo
//    mf.enq(10, 128'h00000000000000033333333333333333);
//

    noAction;
    noAction;
    noAction;
    noAction;
    noAction;
    noAction;
    noAction;
    //while(True) noAction;
  endseq;

  mkAutoFSM(test_seq);
endmodule

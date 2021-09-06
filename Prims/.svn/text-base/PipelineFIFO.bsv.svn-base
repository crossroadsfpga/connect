// ========== Copyright Header Begin ==========================================
//
// The ProtoFlex Project
// Copyright (C) 2006 - 2009 by Eric Chung, Michael Papamichael,
// James C. Hoe, Ken Mai, and Babak Falsafi for the ProtoFlex
// Project, Computer Architecture Lab at Carnegie Mellon,
// Carnegie Mellon University. All Rights Reserved.
// DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
//
// For more information, see the ProtoFlex Project website at:
// http://www.ece.cmu.edu/~protoflex
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//
// ========== Copyright Header End ============================================

import FIFO::*;
import FIFOF::*;
import Assert::*;
import GenReg::*;



module mkPipelineFIFO16#(Bool guarded)( FIFOF#(dtype) )
			provisos( Bits#(dtype, type_nt) );

    FIFOF#(dtype) d0 <- mkPipelineFIFO8(guarded);
    FIFOF#(dtype) d1 <- mkPipelineFIFO8(guarded);

    rule transfer(d0.notEmpty && d1.notFull);
	let x = d0.first;
	d1.enq(x);
	d0.deq();
    endrule

    method Action clear();
	dynamicAssert(False, "clear not implemented");
    endmethod

    method notEmpty = d1.notEmpty;

    method notFull = d0.notFull;

    method first() = d1.first;

    method Action enq(dtype din);
	d0.enq(din);
    endmethod

    method Action deq();
	d1.deq();
    endmethod

endmodule 

 

module mkPipelineFIFO8#(Bool guarded)( FIFOF#(dtype) )
			provisos( Bits#(dtype, type_nt) );

    FIFOF#(dtype) d0 <- mkPipelineFIFO4(guarded);
    FIFOF#(dtype) d1 <- mkPipelineFIFO4(guarded);

    rule transfer(d0.notEmpty && d1.notFull);
	let x = d0.first;
	d1.enq(x);
	d0.deq();
    endrule

    method Action clear();
	dynamicAssert(False, "clear not implemented");
    endmethod

    method notEmpty = d1.notEmpty;

    method notFull = d0.notFull;

    method first() = d1.first;

    method Action enq(dtype din);
	d0.enq(din);
    endmethod

    method Action deq();
	d1.deq();
    endmethod

endmodule 

 
module mkPipelineFIFO4#(Bool guarded)( FIFOF#(dtype) )
			provisos( Bits#(dtype, type_nt) );

    FIFOF#(dtype) d0 <- mkPipelineFIFO2(guarded);
    FIFOF#(dtype) d1 <- mkPipelineFIFO2(guarded);

    rule transfer(d0.notEmpty && d1.notFull);
	let x = d0.first;
	d1.enq(x);
	d0.deq();
    endrule

    method Action clear();
	dynamicAssert(False, "clear not implemented");
    endmethod

    method notEmpty = d1.notEmpty;

    method notFull = d0.notFull;

    method first() = d1.first;

    method Action enq(dtype din);
	d0.enq(din);
    endmethod

    method Action deq();
	d1.deq();
    endmethod

endmodule

module mkPipelineFIFO3#(Bool guarded)( FIFOF#(dtype) )
			provisos( Bits#(dtype, type_nt) );

    FIFOF#(dtype) d0 <- mkPipelineFIFO(guarded);
    FIFOF#(dtype) d1 <- mkPipelineFIFO2(guarded);

    rule transfer(d0.notEmpty && d1.notFull);
	let x = d0.first;
	d1.enq(x);
	d0.deq();
    endrule

    method Action clear();
	dynamicAssert(False, "clear not implemented");
    endmethod

    method notEmpty = d1.notEmpty;

    method notFull = d0.notFull;

    method first() = d1.first;

    method Action enq(dtype din);
	d0.enq(din);
    endmethod

    method Action deq();
	d1.deq();
    endmethod

endmodule 

 
module mkPipelineFIFO2#(Bool guarded)( FIFOF#(dtype) )
			provisos( Bits#(dtype, type_nt) );

    FIFOF#(dtype) d0 <- mkPipelineFIFO(guarded);
    FIFOF#(dtype) d1 <- mkPipelineFIFO(guarded);

    rule transfer(d0.notEmpty && d1.notFull);
	let x = d0.first;
	d1.enq(x);
	d0.deq();
    endrule

    method Action clear();
	dynamicAssert(False, "clear not implemented");
    endmethod

    method notEmpty = d1.notEmpty;

    method notFull = d0.notFull;

    method first() = d1.first;

    method Action enq(dtype din);
	d0.enq(din);
    endmethod

    method Action deq();
	d1.deq();
    endmethod

endmodule


module mkPipelineFIFO#(Bool guarded)( FIFOF#(dtype) )
                        provisos( Bits#(dtype, type_nt) );

  FIFOF#(dtype) fifo;

  if(guarded) begin
    fifo <- mkPipelineFIFO_guarded();
  end
  else begin
    fifo <- mkPipelineFIFO_unguarded();
  end

  return fifo;

endmodule




module mkPipelineFIFO_unguarded( FIFOF#(dtype) )
                        provisos( Bits#(dtype, type_nt) );

  Reg#(dtype)   data      <- mkRegU;
  Reg#(Bool)    full      <- mkGenReg(False);
  PulseWire     inDeq     <- mkPulseWire();
  PulseWire     oldFull   <- mkPulseWire();

  rule passFull( full );
    oldFull.send();
  endrule

  method Action enq( dtype din );
    full <= True;
    data <= din;
    dynamicAssert(!oldFull || inDeq, "error, enq to full pipeline fifo");
  endmethod

  method Action deq();
    full <= False;
    inDeq.send();
  endmethod

  method dtype first();
    return data;
  endmethod

  method Bool notFull() = !oldFull || inDeq;

  method Bool notEmpty() = full;

  method Action clear();
    dynamicAssert(False, "clear not implemented");
  endmethod
 

endmodule 




module mkPipelineFIFO_guarded( FIFOF#(dtype) )
                        provisos( Bits#(dtype, type_nt) );

  Reg#(dtype)   data      <- mkRegU;
  Reg#(Bool)    full      <- mkGenReg(False);
  PulseWire     inDeq     <- mkPulseWire();
  PulseWire     oldFull   <- mkPulseWire();

  rule passFull( full );
    oldFull.send();
  endrule

  method Action enq( dtype din ) if(!oldFull || inDeq);
    full <= True;
    data <= din;
    // dynamicAssert(!oldFull || inDeq, "error, enq to full pipeline fifo");
  endmethod

  method Action deq() if( full );
    full <= False;
    inDeq.send();
  endmethod

  method dtype first() if( full );
    return data;
  endmethod

  method Bool notFull() = !oldFull || inDeq;

  method Bool notEmpty() = full;

  method Action clear();
    dynamicAssert(False, "clear not implemented");
  endmethod
 
endmodule


module fifotest( FIFOF#(Bit#(32)) );
  FIFOF#(Bit#(32)) fifo <- mkPipelineFIFO(True/*guarded*/);
  
  return fifo;
endmodule

module tb_fifotest ();
  Reg#(Bit#(8)) state   <- mkReg(0);
  FIFOF#(Bit#(32)) fifo  <- mkPipelineFIFO(True/*guarded*/);


  Reg#(Bit#(32)) counter <- mkReg(0);

  rule upd_cnt( True );
    counter <= counter + 1;
  endrule


  rule enqueuing( True );
    fifo.enq(counter);
    $display(counter, " enqueuing %h", counter);
  endrule

  rule dequeuing( True );
    $display(counter, " dequeuing, head: %h", fifo.first());
    fifo.deq();
  endrule


  rule terminate( counter == 20 );
    $finish();
  endrule
  



  /*

  rule step0 (state == 0);
    fifo.enq(1);
    // $display(counter, " fifo has %0d",  fifo.first() );
    state <= 1;
  endrule
 
  rule step1_deq (state == 1);
    // $display(counter, " fifo has %0d, dequeuing",  fifo.first() );
    $display(counter, "dequeuing");
    fifo.deq();
  endrule

  rule step1_eng (state == 1);
    $display(counter, " enqueuing 2");
    fifo.enq(2);
    state <= 2;
  endrule

  rule step2_deq (state == 2);
    $display(counter, " fifo has %0d, dequeuing",  fifo.first() );
    fifo.deq();
  endrule

  rule step2_eng (state == 2);
    $display(counter, " enqueuing 3");
    fifo.enq(3);
    state <= 3;
  endrule
  
  rule step3_deq (state == 3);
    $display(counter, " fifo has %0d",  fifo.first() );
    fifo.deq();
    state <= 4;
  endrule
  
  rule step4 (state == 4);
    $finish();
  endrule
  */
  

endmodule

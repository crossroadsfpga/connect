/* =========================================================================
 *
 * Filename:            Allocators.bsv
 * Date created:        06-19-2011
 * Last modified:       06-19-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Testbench and synthesizable example for allocators.
 *
 * =========================================================================
 */ 

`include "inc.v"
import StmtFSM::*;   // for testbench

///////////////////////////////////////////////////
// Testbench
typedef 5 NumRequestors;  // n
typedef 5 NumResources;   // m

module mkSepAllocTest(Empty);  
  String name = "mkSepAllocIFTest";
  AllocatorSynth alloc <- mkSepAllocSynth();
  
  Stmt test_seq = seq
  action
    Vector#(NumRequestors, Vector#(NumResources, Bool)) ai;
    Vector#(NumRequestors, Vector#(NumResources, Bool)) ao;
    //ai = unpack(2'b1_0);
    //ai = unpack(4'b11_10);
    //ai = unpack(12'b111_110_100_010);
    //ai = unpack(12'b010_100_110_111);
    ai = unpack(25'b01001_10001_11001_11101_11001);
    alloc.next();
    ao = alloc.allocate(ai);
  endaction

  action
    Vector#(NumRequestors, Vector#(NumResources, Bool)) ai;
    Vector#(NumRequestors, Vector#(NumResources, Bool)) ao;
    //ai = unpack(2'b1_0);
    //ai = unpack(4'b11_10);
    //ai = unpack(12'b111_110_100_010);
    //ai = unpack(12'b010_101_111_111);
    ai = unpack(25'b01001_10001_11001_11101_11001);
    ao = alloc.allocate(ai);
  endaction

    //action Data_t test <- mf.deq(0); endaction
    //mf.enq(1, 128'h11111111111111122222222222222222);
    noAction;
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


typedef Allocator#(NumRequestors, NumResources) AllocatorSynth;
typedef Arbiter#(NumResources) InputArb;
typedef Arbiter#(NumRequestors) OutputArb;

typedef Vector#(NumRequestors, Arbiter#(NumResources)) InputArbs;
typedef Vector#(NumResources, Arbiter#(NumRequestors)) OutputArbs;

interface InputArbiters;
  interface Vector#(NumRequestors, Arbiter#(NumResources)) input_arbs;
endinterface

interface OutputArbiters;
  interface Vector#(NumResources, Arbiter#(NumRequestors)) output_arbs;
endinterface

(* synthesize *)
//module mkInputArb#(Bit#(TLog#(NumResources)) startAt ) (InputArb);
module mkInputArb (InputArb);
  InputArb ia <- mkRoundRobinArbiterStartAt(0);
  //InputArb ia <- mkIterativeArbiter_fromEricStartAt(0);
  return ia;
endmodule 

(* synthesize *)
//module mkOutputArb#(Bit#(TLog#(NumRequestors)) startAt) (OutputArb);
module mkOutputArb (OutputArb);
  OutputArb oa <- mkRoundRobinArbiterStartAt(0);
  //OutputArb oa <- mkIterativeArbiter_fromEricStartAt(0);
  return oa;
endmodule 

(* synthesize *)
module mkInputArbiters(InputArbiters);
  Vector#(NumRequestors, Arbiter#(NumResources)) ias;
  for(Integer i=0; i<valueOf(NumRequestors); i=i+1) begin
    ias[i] <- mkRoundRobinArbiterStartAt(i%valueOf(NumResources));
    //ias[i] <- mkIterativeArbiter_fromEricStartAt(i%valueOf(NumResources));
  end
  interface input_arbs = ias;
endmodule

(* synthesize *)
module mkOutputArbiters(OutputArbiters);
  Vector#(NumResources, Arbiter#(NumRequestors)) oas;
  for(Integer j=0; j<valueOf(NumResources); j=j+1) begin 
    oas[j] <- mkRoundRobinArbiterStartAt(j%valueOf(NumRequestors));
    //oas[j] <- mkIterativeArbiter_fromEricStartAt(j%valueOf(NumRequestors));
  end
  interface output_arbs = oas;
endmodule

module mkInputArbitersStatic(InputArbiters);
  Vector#(NumRequestors, Arbiter#(NumResources)) ias;
  for(Integer i=0; i<valueOf(NumRequestors); i=i+1) begin
    ias[i] <- mkStaticPriorityArbiterStartAt(i%valueOf(NumResources));
    //ias[i] <- mkIterativeArbiter_fromEricStartAt(i%valueOf(NumResources));
  end
  interface input_arbs = ias;
endmodule

(* synthesize *)
module mkOutputArbitersStatic(OutputArbiters);
  Vector#(NumResources, Arbiter#(NumRequestors)) oas;
  for(Integer j=0; j<valueOf(NumResources); j=j+1) begin 
    oas[j] <- mkStaticPriorityArbiterStartAt(j%valueOf(NumRequestors));
    //oas[j] <- mkIterativeArbiter_fromEricStartAt(j%valueOf(NumRequestors));
  end
  interface output_arbs = oas;
endmodule


(* synthesize *)
module mkSepAllocSynth( AllocatorSynth );  
//---------- Option 1 ---------------
//  AllocatorSynth as <- mkSepAllocIF();

//---------- Option 2 ---------------
//  Vector#(NumRequestors, Arbiter#(NumResources))  inputArbs;
//  Vector#(NumResources, Arbiter#(NumRequestors))  outputArbs;
//
//  for(Integer i=0; i<valueOf(NumRequestors); i=i+1) begin
//    //inputArbs[i] <- mkInputArb();
//    inputArbs[i] <- mkInputArb();
//  end
//  for(Integer j=0; j<valueOf(NumResources); j=j+1) begin 
//    //outputArbs[j] <- mkOutputArb(); 
//    outputArbs[j] <- mkOutputArb(); 
//  end
//  
//  AllocatorSynth as <- mkSepAllocIF_ExternalArbiters(inputArbs, outputArbs);

//---------- Option 3 ---------------
  // Static Priority
  //InputArbiters inputArbs <- mkInputArbitersStatic();
  //OutputArbiters outputArbs <- mkOutputArbitersStatic();
  
  // Round-robin
  InputArbiters inputArbs <- mkInputArbiters();
  OutputArbiters outputArbs <- mkOutputArbiters();
  
  //AllocatorSynth as <- mkSepAllocIF(inputArbs.input_arbs, outputArbs.output_arbs);
  AllocatorSynth as <- mkSepAllocIF(inputArbs.input_arbs, outputArbs.output_arbs);
 
  return as;
endmodule


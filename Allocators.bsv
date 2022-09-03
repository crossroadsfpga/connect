/* =========================================================================
 *
 * Filename:            Allocators.bsv
 * Date created:        05-20-2011
 * Last modified:       05-20-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Implements allocators. 
 *
 * =========================================================================
 */ 

`include "inc.v"
import Vector::*;
import Assert::*;
import NetworkTypes::*;
import Arbiters::*;
import ConfigReg::*;

//////////////////////////////////////////////////////////////////////////
// Allocator Interface
// n is #requestors and m is #resources
interface Allocator#(type n, type m);
  (* always_ready *) method ActionValue#( Vector#(n, Vector#(m, Bool)) ) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
  //(* always_ready *) method Vector#(n, Vector#(m, Bool)) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
  //(* always_ready *) method Action updatePipelinedAllocator( Vector#(n, Vector#(m, Bool)) alloc_input);
  (* always_ready *) method Action                       next(); // used to advance allocator state for non-static allocators
  //(* always_ready *) method Action updateAllocator( Vector#(n, Vector#(m, Bool)) alloc_input);
endinterface

//////////////////////////////////////////////////////////////////////////
// Separable allocator - Input First
// Expects two vectors of external arbiters to reduce bluespec compilation times
module mkSepAllocIF#( Vector#(n, Arbiter#(m)) inputArbs, Vector#(m, Arbiter#(n))  outputArbs, Bool pipeline) 
                   ( Allocator#(n, m) );  
  String name = "mkSepAllocIF";

  // Register used for pipelining option
  Vector#(n, Vector#(m, Reg#(Bool))) inputArbGrants_reg;
  for(Integer i=0; i<valueOf(n); i=i+1) begin
    inputArbGrants_reg[i] <- replicateM(mkConfigReg(False));
  end

  //rule update_inputArbGrants_reg(True);
  //  Vector#(n, Vector#(m, Bool)) inputArbGrants = unpack(0);
  //  for(Integer i=0; i<valueOf(n); i=i+1) begin
  //    inputArbGrants[i] = inputArbs[i].select(inputArbRequests[i]);
  //    writeVReg(inputArbGrants_reg[i], inputArbGrants[i]);
  //  end
  //endrule
  
//  method Action updatePipelinedAllocator( Vector#(n, Vector#(m, Bool)) alloc_input);
//    Vector#(n, Vector#(m, Bool)) inputArbRequests = alloc_input;
//    Vector#(n, Vector#(m, Bool)) inputArbGrants;
//    for(Integer i=0; i<valueOf(n); i=i+1) begin
//      inputArbGrants[i] = inputArbs[i].select(inputArbRequests[i]);
//      writeVReg(inputArbGrants_reg[i], inputArbGrants[i]);
//    end
//  endmethod


  method Action next(); // used to advance allocator state for non-static allocators
  //method Action updateAllocator( Vector#(n, Vector#(m, Bool)) alloc_input);
    //Vector#(n, Vector#(m, Bool)) inputArbRequests = alloc_input;
    //Vector#(n, Vector#(m, Bool)) inputArbGrants;
    //for(Integer i=0; i<valueOf(n); i=i+1) begin
    //  inputArbGrants[i] = inputArbs[i].select(inputArbRequests[i]);
    //  writeVReg(inputArbGrants_reg[i], inputArbGrants[i]);
    //end

    for(Integer i=0; i<valueOf(n); i=i+1) begin
      inputArbs[i].next(); //<- mkRoundRobinArbiterStartAt(i%m);  // start RR arbiters in staggered fashion to reduce conflicts 
    end
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      outputArbs[j].next(); // <- mkRoundRobinArbiterStartAt(j%n);  // start RR arbiters in staggered fashion to reduce conflicts 
    end
  endmethod
 
  method ActionValue#( Vector#(n, Vector#(m, Bool)) ) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
  //method Vector#(n, Vector#(m, Bool)) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
    // Perform 1st stage input allocation
    //`DBG(("\nAllocator Input: "));
    //printAllocMatrix(alloc_input);//uncomment by zhipeng
    Vector#(n, Vector#(m, Bool)) inputArbRequests = alloc_input;
    Vector#(n, Vector#(m, Bool)) inputArbGrants = unpack(0);
    for(Integer i=0; i<valueOf(n); i=i+1) begin
      inputArbGrants[i] <- inputArbs[i].select(inputArbRequests[i]);
    end

    //`DBG(("After Input Allocation: "));
    //printAllocMatrix(inputArbGrants);//uncomment by zhipeng
  
    // Perform 2nd stage output allocation
    Vector#(m, Vector#(n, Bool)) outputArbRequests = unpack(0);
    if (pipeline) begin
      Vector#(n, Vector#(m, Bool)) inputArbGrants_delayed = unpack(0);
      for(Integer i=0; i<valueOf(n); i=i+1) begin
	writeVReg(inputArbGrants_reg[i], inputArbGrants[i]);
	inputArbGrants_delayed[i] = readVReg(inputArbGrants_reg[i]);
      end
      outputArbRequests = transpose(inputArbGrants_delayed); // use result delayed by a single cycle
    end else begin
      outputArbRequests = transpose(inputArbGrants); // use same-cycle result
    end

    Vector#(m, Vector#(n, Bool)) outputArbGrants = unpack(0);
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      outputArbGrants[j] <- outputArbs[j].select(outputArbRequests[j]);
    end
    
    Vector#(n, Vector#(m, Bool)) alloc_output = transpose(outputArbGrants);
    
    //`DBG(("Allocator Output: "));
    //printAllocMatrix(alloc_output);//uncomment by zhipeng
    return alloc_output;
  endmethod

endmodule

//////////////////////////////////////////////////////////////////////////
// Separable allocator - Output First
// Expects two vectors of external arbiters to reduce bluespec compilation times
module mkSepAllocOF#( Vector#(n, Arbiter#(m)) inputArbs, Vector#(m, Arbiter#(n))  outputArbs, Bool pipeline) 
                   ( Allocator#(n, m) );  
  String name = "mkSepAllocOF";

  // Register used for pipelining option
  Vector#(m, Vector#(n, Reg#(Bool))) outputArbGrants_reg;
  for(Integer j=0; j<valueOf(m); j=j+1) begin 
    outputArbGrants_reg[j] <- replicateM(mkConfigReg(False));
  end

//  rule update_outputArbGrants_reg(True);
//    Vector#(m, Vector#(n, Bool)) outputArbGrants = unpack(0);
//    for(Integer j=0; j<valueOf(m); j=j+1) begin 
//      outputArbGrants[j] = outputArbs[j].select(outputArbRequests[j]);
//      writeVReg(outputArbGrants_reg[j], outputArbGrants[j]);
//    end
//  endrule

 
//  method Action updatePipelinedAllocator( Vector#(n, Vector#(m, Bool)) alloc_input);
//    Vector#(m, Vector#(n, Bool)) outputArbRequests = transpose(alloc_input);
//    Vector#(m, Vector#(n, Bool)) outputArbGrants;
//    for(Integer j=0; j<valueOf(m); j=j+1) begin 
//      outputArbGrants[j] = outputArbs[j].select(outputArbRequests[j]);
//      writeVReg(outputArbGrants_reg[j], outputArbGrants[j]);
//    end
//  endmethod

  method Action next(); // used to advance allocator state for non-static allocators
  //method Action updateAllocator( Vector#(n, Vector#(m, Bool)) alloc_input);
    //Vector#(m, Vector#(n, Bool)) outputArbRequests = transpose(alloc_input);
    //Vector#(m, Vector#(n, Bool)) outputArbGrants;
    //for(Integer j=0; j<valueOf(m); j=j+1) begin 
    //  outputArbGrants[j] = outputArbs[j].select(outputArbRequests[j]);
    //  writeVReg(outputArbGrants_reg[j], outputArbGrants[j]);
    //end

    for(Integer i=0; i<valueOf(n); i=i+1) begin
      inputArbs[i].next(); //<- mkRoundRobinArbiterStartAt(i%m);  // start RR arbiters in staggered fashion to reduce conflicts 
    end
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      outputArbs[j].next(); // <- mkRoundRobinArbiterStartAt(j%n);  // start RR arbiters in staggered fashion to reduce conflicts 
    end
  endmethod
 
  method ActionValue#( Vector#(n, Vector#(m, Bool)) ) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
  //method Vector#(n, Vector#(m, Bool)) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
    // Perform 1st stage output allocation
    //`DBG(("Allocator Input: "));
    //printAllocMatrix(alloc_input);
    Vector#(m, Vector#(n, Bool)) outputArbRequests = transpose(alloc_input);
    Vector#(m, Vector#(n, Bool)) outputArbGrants = unpack(0);
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      outputArbGrants[j] <- outputArbs[j].select(outputArbRequests[j]);
    end

    // Perform 2nd stage input allocation
    Vector#(n, Vector#(m, Bool)) inputArbRequests = unpack(0);
    if (pipeline) begin
      Vector#(m, Vector#(n, Bool)) outputArbGrants_delayed = unpack(0);
      for(Integer j=0; j<valueOf(m); j=j+1) begin 
	writeVReg(outputArbGrants_reg[j], outputArbGrants[j]);
	outputArbGrants_delayed[j] = readVReg(outputArbGrants_reg[j]);
      end
      inputArbRequests = transpose(outputArbGrants_delayed); // use results delayed by a single cycle
    end else begin
      inputArbRequests = transpose(outputArbGrants); // use same-cycle result
    end

    Vector#(n, Vector#(m, Bool)) inputArbGrants = unpack(0);
    //`DBG(("After Output Allocation: "));
    //printAllocMatrix(inputArbRequests);
    for(Integer i=0; i<valueOf(n); i=i+1) begin
      inputArbGrants[i] <- inputArbs[i].select(inputArbRequests[i]);
    end
        
    Vector#(n, Vector#(m, Bool)) alloc_output = inputArbGrants;
    
    //`DBG(("Allocator Output: "));
    //printAllocMatrix(alloc_output);
    return alloc_output;
  endmethod

endmodule


//////////////////////////////////////////////////////////////////////////
// iSLIP Separable allocator - Input First
// Expects two vectors of external arbiters to reduce bluespec compilation times
module mkSepAllocIFiSLIP#( Vector#(n, Arbiter#(m)) inputArbs, Vector#(m, Arbiter#(n))  outputArbs, Bool pipeline) 
                   ( Allocator#(n, m) );  
  String name = "mkSepAllocIFiSLIP";

  // Register used for pipelining option
  Vector#(n, Vector#(m, Reg#(Bool))) inputArbGrants_reg;
  for(Integer i=0; i<valueOf(n); i=i+1) begin
    inputArbGrants_reg[i] <- replicateM(mkConfigReg(False));
  end


  method Action next(); // used to advance allocator state for non-static allocators
    // see allocate method - iSLIP version updates based on allocation result
  endmethod
 
  method ActionValue#( Vector#(n, Vector#(m, Bool)) ) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
  //method Vector#(n, Vector#(m, Bool)) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
    // Perform 1st stage input allocation
    //`DBG(("\nAllocator Input: "));
    printAllocMatrix(alloc_input); //uncomment by zhipeng
    Vector#(n, Vector#(m, Bool)) inputArbRequests = alloc_input;
    Vector#(n, Vector#(m, Bool)) inputArbGrants = unpack(0);
    for(Integer i=0; i<valueOf(n); i=i+1) begin
      inputArbGrants[i] <- inputArbs[i].select(inputArbRequests[i]);
    end

    //`DBG(("After Input Allocation: "));
    printAllocMatrix(inputArbGrants);//uncomment by zhipeng
  
    // Perform 2nd stage output allocation
    Vector#(m, Vector#(n, Bool)) outputArbRequests = unpack(0);
    if (pipeline) begin
      Vector#(n, Vector#(m, Bool)) inputArbGrants_delayed = unpack(0);
      for(Integer i=0; i<valueOf(n); i=i+1) begin
	writeVReg(inputArbGrants_reg[i], inputArbGrants[i]);
	inputArbGrants_delayed[i] = readVReg(inputArbGrants_reg[i]);
      end
      outputArbRequests = transpose(inputArbGrants_delayed); // use result delayed by a single cycle
    end else begin
      outputArbRequests = transpose(inputArbGrants); // use same-cycle result
    end

    Vector#(m, Vector#(n, Bool)) outputArbGrants = unpack(0);
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      outputArbGrants[j] <- outputArbs[j].select(outputArbRequests[j]);
    end
    
    Vector#(n, Vector#(m, Bool)) alloc_output = transpose(outputArbGrants);
    Vector#(m, Bool) zeros_m = unpack(0);

    for(Integer i=0; i<valueOf(n); i=i+1) begin
      // Only advance first stage input allocator if selected input was also picked by second stage
      // if (inputArbGrants[i] == alloc_output[i]) begin
      if ((inputArbGrants[i] != zeros_m) && (inputArbGrants[i] == alloc_output[i])) begin
        inputArbs[i].next(); //<- mkRoundRobinArbiterStartAt(i%m);  // start RR arbiters in staggered fashion to reduce conflicts
      end
    end


    Vector#(n, Bool) zeros_n = unpack(0);
    for(Integer j=0; j<valueOf(m); j=j+1) begin
      if ((outputArbGrants[j] != zeros_n) && (outputArbRequests[j] == outputArbGrants[j])) begin
        outputArbs[j].next(); // <- mkRoundRobinArbiterStartAt(j%n);  // start RR arbiters in staggered fashion to reduce conflicts
      end
    end
 
    //`DBG(("Allocator Output: "));
    printAllocMatrix(alloc_output);//uncomment by zhipeng
    return alloc_output;
  endmethod

endmodule

//////////////////////////////////////////////////////////////////////////
// iSLIP Separable allocator - Output First
// Expects two vectors of external arbiters to reduce bluespec compilation times
module mkSepAllocOFiSLIP#( Vector#(n, Arbiter#(m)) inputArbs, Vector#(m, Arbiter#(n))  outputArbs, Bool pipeline) 
                   ( Allocator#(n, m) );  
  String name = "mkSepAllocOFiSLIP";

  // Register used for pipelining option
  Vector#(m, Vector#(n, Reg#(Bool))) outputArbGrants_reg;
  for(Integer j=0; j<valueOf(m); j=j+1) begin 
    outputArbGrants_reg[j] <- replicateM(mkConfigReg(False));
  end

  method Action next(); // used to advance allocator state for non-static allocators
    // see allocate method - iSLIP version updates based on allocation result
  endmethod
 
  method ActionValue#( Vector#(n, Vector#(m, Bool)) ) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
  //method Vector#(n, Vector#(m, Bool)) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
    // Perform 1st stage output allocation
    //`DBG(("Allocator Input: "));
    printAllocMatrix(alloc_input);//uncomment by zhipeng
    Vector#(m, Vector#(n, Bool)) outputArbRequests = transpose(alloc_input);
    Vector#(m, Vector#(n, Bool)) outputArbGrants = unpack(0);
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      outputArbGrants[j] <- outputArbs[j].select(outputArbRequests[j]);
    end

    // Perform 2nd stage input allocation
    Vector#(n, Vector#(m, Bool)) inputArbRequests = unpack(0);
    if (pipeline) begin
      Vector#(m, Vector#(n, Bool)) outputArbGrants_delayed = unpack(0);
      for(Integer j=0; j<valueOf(m); j=j+1) begin 
	writeVReg(outputArbGrants_reg[j], outputArbGrants[j]);
	outputArbGrants_delayed[j] = readVReg(outputArbGrants_reg[j]);
      end
      inputArbRequests = transpose(outputArbGrants_delayed); // use results delayed by a single cycle
    end else begin
      inputArbRequests = transpose(outputArbGrants); // use same-cycle result
    end

    Vector#(n, Vector#(m, Bool)) inputArbGrants = unpack(0);
    //`DBG(("After Output Allocation: "));
    printAllocMatrix(inputArbRequests);//uncomment by zhipeng
    for(Integer i=0; i<valueOf(n); i=i+1) begin
      inputArbGrants[i] <- inputArbs[i].select(inputArbRequests[i]);
    end
        
    Vector#(n, Vector#(m, Bool)) alloc_output = inputArbGrants;
    
    Vector#(m, Bool) zeros_m = unpack(0);
    
    for(Integer i=0; i<valueOf(n); i=i+1) begin
      if ((inputArbGrants[i] != zeros_m) && (inputArbRequests[i] == inputArbGrants[i])) begin
        inputArbs[i].next(); //<- mkRoundRobinArbiterStartAt(i%m);  // start RR arbiters in staggered fashion to reduce conflicts 
      end
    end

    Vector#(m, Vector#(n, Bool)) alloc_output_transposed = transpose(alloc_output);
    Vector#(n, Bool) zeros_n = unpack(0);
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      // Only advance first stage output allocator if selected output was also picked by second stage
      if ((outputArbGrants[j] != zeros_n) && (outputArbGrants[j] == alloc_output_transposed[j])) begin
        outputArbs[j].next(); // <- mkRoundRobinArbiterStartAt(j%n);  // start RR arbiters in staggered fashion to reduce conflicts 
      end
    end

    //`DBG(("Allocator Output: "));
    printAllocMatrix(alloc_output);//uncomment by zhipeng
    return alloc_output;
  endmethod

endmodule




//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////
// Router Allocator modules - Synthesizable versions for use in Router
// Specific instances for Routers
typedef Allocator#(NumInPorts, NumOutPorts) RouterAllocator;
interface RouterInputArbiters;  
  interface Vector#(NumInPorts, Arbiter#(NumOutPorts)) input_arbs;  
endinterface
interface RouterOutputArbiters; 
  interface Vector#(NumOutPorts, Arbiter#(NumInPorts)) output_arbs; 
endinterface

(* synthesize *)
module mkInputArbiter(Arbiter#(NumOutPorts));
    let arb <- mkRoundRobinArbiter();
    return arb;
endmodule

(* synthesize *)
module mkOutputArbiter(Arbiter#(NumInPorts));
    let arb <- mkRoundRobinArbiter();
    return arb;
endmodule

// Round-robin Arbiters
(* synthesize *)
module mkRouterInputArbitersRoundRobin(RouterInputArbiters);
  Vector#(NumInPorts, Arbiter#(NumOutPorts)) ias;
  for(Integer i=0; i<valueOf(NumInPorts); i=i+1) begin
    //ias[i] <- mkRoundRobinArbiterStartAt(i%valueOf(NumOutPorts));//comment zhipeng	
    ias[i] <- mkRoundRobinArbiter();//uncomment zhipeng, use the roundrobin directly
  end
  interface input_arbs = ias;
endmodule

(* synthesize *)
module mkRouterOutputArbitersRoundRobin(RouterOutputArbiters);
  Vector#(NumOutPorts, Arbiter#(NumInPorts)) oas;
  for(Integer j=0; j<valueOf(NumOutPorts); j=j+1) begin 
    //oas[j] <- mkRoundRobinArbiterStartAt(j%valueOf(NumInPorts));//comment by zhipeng
    oas[j] <- mkRoundRobinArbiter();// uncomment by zhipeng
  end
  interface output_arbs = oas;
endmodule

// Static Priority Arbiters
(* synthesize *)
module mkRouterInputArbitersStatic(RouterInputArbiters);
  Vector#(NumInPorts, Arbiter#(NumOutPorts)) ias;
  for(Integer i=0; i<valueOf(NumInPorts); i=i+1) begin
    ias[i] <- mkStaticPriorityArbiterStartAt(i%valueOf(NumOutPorts));
    //ias[i] <- mkStaticPriorityArbiterStartAt(0);
  end
  interface input_arbs = ias;
endmodule

(* synthesize *)
module mkRouterOutputArbitersStatic(RouterOutputArbiters);
  Vector#(NumOutPorts, Arbiter#(NumInPorts)) oas;
  for(Integer j=0; j<valueOf(NumOutPorts); j=j+1) begin 
    oas[j] <- mkStaticPriorityArbiterStartAt(j%valueOf(NumInPorts));
    //oas[j] <- mkStaticPriorityArbiterStartAt(0);
  end
  interface output_arbs = oas;
endmodule

(* synthesize *)
module mkSepRouterAllocator#(Bool pipeline)( RouterAllocator );  
  AllocType_t sel_alloc = `ALLOC_TYPE;
  // Arbiters
  RouterInputArbiters inputArbs;
  RouterOutputArbiters outputArbs;
  // Allocator
  RouterAllocator as;

  // Instntiate Arbiters
  if(sel_alloc == SepIFStatic || sel_alloc == SepOFStatic) begin 
    // Static priority
    inputArbs <- mkRouterInputArbitersStatic();
    outputArbs <- mkRouterOutputArbitersStatic();
  end else if (sel_alloc == SepIFRoundRobin || sel_alloc == SepOFRoundRobin) begin
    // Round robin
    inputArbs <- mkRouterInputArbitersRoundRobin();
    outputArbs <- mkRouterOutputArbitersRoundRobin();
  end else if (sel_alloc == SepIFiSLIP || sel_alloc == SepOFiSLIP) begin
    // iSLIP uses round-robin arbiters, which are rotated based on allocation result
    inputArbs <- mkRouterInputArbitersRoundRobin();
    outputArbs <- mkRouterOutputArbitersRoundRobin();
  end else begin
    staticAssert(False, "Unsupported allocator");
  end
  
  // Instantiate separable allocator
  if(sel_alloc == SepIFRoundRobin || sel_alloc == SepIFStatic) begin 
    // Input First
    as <- mkSepAllocIF(inputArbs.input_arbs, outputArbs.output_arbs, pipeline);
  end else if(sel_alloc == SepOFRoundRobin || sel_alloc == SepOFStatic) begin 
    // Output First
    as <- mkSepAllocOF(inputArbs.input_arbs, outputArbs.output_arbs, pipeline);
  end else if(sel_alloc == SepIFiSLIP) begin
    as <- mkSepAllocIFiSLIP(inputArbs.input_arbs, outputArbs.output_arbs, pipeline);
  end else if(sel_alloc == SepOFiSLIP) begin
    as <- mkSepAllocOFiSLIP(inputArbs.input_arbs, outputArbs.output_arbs, pipeline);
  end else begin
    staticAssert(False, "Unsupported allocator");
  end
  
  return as;
endmodule

// Function for printing allocation matrix
function Action printAllocMatrix(Vector#(n, Vector#(m, Bool)) am);
  action
  for(Integer i=0; i<valueOf(n); i=i+1) begin
    //noAction;
    //$display("%b", am[i]);
    $display("%b", am[i]);
  end
  $display("");//add by zhipeng, seperate diff printouts.
  endaction
endfunction

/*
//////////////////////////////////////////////////////////////////////////////////////////////
// Old modules

//////////////////////////////////////////////////////////////////////////
// Separable allocator - Input First
// For large n,m (e.g. >6) use the allocator with External arbiters below
// This one becomes too slow to compile with Bluespec
module mkSepAllocIF_OldInternalArbiters( Allocator#(n, m) );  
  String name = "mkSepAllocIF";

  Vector#(n, Arbiter#(m))  inputArbs;
  Vector#(m, Arbiter#(n))  outputArbs;

  //Instantiate Arbiters
  for(Integer i=0; i<valueOf(n); i=i+1) begin
    inputArbs[i] <- mkRoundRobinArbiterStartAt(i%valueOf(m));  // start RR arbiters in staggered fashion to reduce conflicts 
    //inputArbs[i] <- mkIterativeArbiter_fromEricStartAt(i%valueOf(m));  // start RR arbiters in staggered fashion to reduce conflicts 
    //inputArbs[i] <- mkRoundRobinArbiterStartAt(0);  // start RR arbiters in staggered fashion to reduce conflicts 
  end
  for(Integer j=0; j<valueOf(m); j=j+1) begin 
    outputArbs[j] <- mkRoundRobinArbiterStartAt(j%valueOf(n));  // start RR arbiters in staggered fashion to reduce conflicts 
    //outputArbs[j] <- mkIterativeArbiter_fromEricStartAt(j%valueOf(n));  // start RR arbiters in staggered fashion to reduce conflicts 
    //outputArbs[j] <- mkRoundRobinArbiterStartAt(0);  // start RR arbiters in staggered fashion to reduce conflicts 
  end

  method Action next(); // used to advance allocator state for non-static allocators
  //method Action updateAllocator( Vector#(n, Vector#(m, Bool)) alloc_input);
    for(Integer i=0; i<valueOf(n); i=i+1) begin
      inputArbs[i].next(); 
    end
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      outputArbs[j].next(); 
    end
  endmethod
 
  method ActionValue#( Vector#(n, Vector#(m, Bool)) ) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
  //method Vector#(n, Vector#(m, Bool)) allocate( Vector#(n, Vector#(m, Bool)) alloc_input);
    //`DBG(("\nAllocator Input: "));
    //printAllocMatrix(alloc_input);
    // Perform 1st stage input allocation
    Vector#(n, Vector#(m, Bool)) inputArbRequests = alloc_input;
    Vector#(n, Vector#(m, Bool)) inputArbGrants = unpack(0);
    for(Integer i=0; i<valueOf(n); i=i+1) begin
      inputArbGrants[i] = inputArbs[i].select(inputArbRequests[i]);
    end
    
    //`DBG(("\n After Input Allocation: "));
    //printAllocMatrix(inputArbGrants);

    // Perform 2nd stage output allocation
    Vector#(m, Vector#(n, Bool)) outputArbRequests = transpose(inputArbGrants);
    Vector#(m, Vector#(n, Bool)) outputArbGrants = unpack(0);
    for(Integer j=0; j<valueOf(m); j=j+1) begin 
      outputArbGrants[j] = outputArbs[j].select(outputArbRequests[j]);
    end
    
    Vector#(n, Vector#(m, Bool)) alloc_output = transpose(outputArbGrants);
    
    //`DBG(("Allocator Output: "));
    //printAllocMatrix(alloc_output);
    return alloc_output;
  endmethod

endmodule

*/


/* =========================================================================
 *
 * Filename:            Arbiters.bsv
 * Date created:        05-09-2011
 * Last modified:       05-09-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Implements static priority and round-robin arbiters. 
 *
 * =========================================================================
 */

import Vector::*;
import Arbiter::*;

/////////////////////////////////////////////////////////////////////////
// Encoder
function Maybe#(Bit#(m)) encoder( Vector#(n, Bool) vec )
				provisos(Log#(n, m));
  Maybe#(Bit#(m)) choice = Invalid;
  //for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
  for(Integer i=valueOf(n)-1; i >= 0; i=i-1)  // I want the lowest to have highest priority
  begin
    if(vec[i]) begin
      choice = Valid(fromInteger(i));
    end
  end
  return choice;
endfunction



/////////////////////////////////////////////////////////////////////////
// Static Priority Arbiter
// Given a bitmask that has a some bits toggled, it produces a same size
// bitmask that only has the least-significant bit toggled. If no bits
// were originally toggled, then result is same as input.
function Maybe#(Vector#(n, Bool)) static_priority_arbiter_onehot_maybe( Vector#(n, Bool) vec );
  Vector#(n, Bool) selected = unpack(0);
  Maybe#(Vector#(n, Bool)) result = Invalid;
  //for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
  for(Integer i=valueOf(n)-1; i >= 0; i=i-1)  // I want the lowest to have highest priority
  begin
    if(vec[i]) begin
      selected = unpack(0);
      selected[i] = True; //Valid(fromInteger(i));
      result = tagged Valid selected;
    end
  end
  return result;
endfunction


/////////////////////////////////////////////////////////////////////////
// Static Priority Arbiter
// Given a bitmask that has a few bits toggled, it produces a same size
// bitmask that only has the least-significant bit toggled. If no bits
// were originally toggled, then result is same as input.
function Vector#(n, Bool) static_priority_arbiter_onehot( Vector#(n, Bool) vec);
  Vector#(n, Bool) selected = unpack(0);
  //Maybe#(Bit#(m)) choice = Invalid;
  //for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
  for(Integer i=valueOf(n)-1; i >= 0; i=i-1)  // I want the lowest to have highest priority
  begin
    if(vec[i]) begin
      selected = unpack(0);
      selected[i] = True; //Valid(fromInteger(i));
    end
  end
  return selected;
endfunction


/////////////////////////////////////////////////////////////////////////
// Static Priority Arbiter that starts at specific bit
// Given a bitmask that has a few bits toggled, it produces a same size
// bitmask that only has the least-significant bit toggled. If no bits
// were originally toggled, then result is same as input.
function Vector#(n, Bool) static_priority_arbiter_onehot_start_at( Vector#(n, Bool) vec, Integer startAt);
  Vector#(n, Bool) selected = unpack(0);
  //Maybe#(Bit#(m)) choice = Invalid;
  //for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
  Integer cur = startAt;
  for(Integer i=valueOf(n)-1; i >= 0; i=i-1)  // I want the lowest to have highest priority
  begin
    if(vec[cur%valueOf(n)]) begin
      selected = unpack(0);
      selected[cur%valueOf(n)] = True; //Valid(fromInteger(i));
    end
    cur = cur+1;
  end
  return selected;
endfunction


//---------------------------------------------------------------------
//        Parameterizable n-way priority encoder.
//
//        If the "en" signal de-asserted, the output will be 0.
//        The input is a vector of booleans, with each Bool representing
//        a requestor. The output is a vector of booleans of the same
//        length.  Up to only 1 bit can be asserted (or all bits are 0)
//        at the output.  The integer input "highest priority" indicates
//        which requestor (corresponding to the input vector) gets the
//        highest priority.
//        Note: from Eric
//---------------------------------------------------------------------

function Vector#(n, Bool) priority_encoder_onehot( Integer highest_priority, Bool en, Vector#(n, Bool) vec );

  Bool selected = False;
  Vector#(n, Bool) choice = unpack(0);

  for(Integer i=highest_priority; i < valueOf(n); i=i+1) begin
    if(vec[i] && !selected) begin
      selected = True;
      choice[i] = True;
    end
  end

  // wrap around

  for(Integer i=0; i < highest_priority; i=i+1) begin
    if(vec[i] && !selected) begin
      selected = True;
      choice[i] = True;
    end
  end

  if(!en) choice = unpack(0);
  return choice;
endfunction



interface Arbiter#(type n);
  (* always_ready *) method ActionValue#(Vector#(n, Bool)) select( Vector#(n, Bool) requests );
  (* always_ready *) method Action           next();
endinterface
 
module mkStaticPriorityArbiter(Arbiter#(n));
  method ActionValue#(Vector#(n, Bool)) select( Vector#(n, Bool) requests );
    return static_priority_arbiter_onehot(requests);
  endmethod

  method Action next();
    action noAction; endaction
  endmethod

endmodule

module mkStaticPriorityArbiterStartAt#(Integer startAt) (Arbiter#(n));
  method ActionValue#(Vector#(n, Bool)) select( Vector#(n, Bool) requests );
    return static_priority_arbiter_onehot_start_at(requests, startAt);
  endmethod

  method Action next();
    action noAction; endaction
  endmethod
endmodule




//module mkRoundRobinArbiter(Arbiter#(n));
//  method ActionValue#(Vector#(n, Bool)) select( Vector#(n, Bool) requests );
//    return priority_arbiter_onehot(requests);
//  endmethod
//endmodule

// From Bill Dally, page 354 in Dally's book
(* noinline *)
function Tuple2#(Bool,Bool) gen_grant_carry(Bool c, Bool r, Bool p);
    return tuple2(r && (c || p), !r && (c || p)); // grant and carry signals
endfunction

//////////////////////////////////////////////////////
// Round-robin arbiter from Dally's book. Page 354
module mkRoundRobinArbiter( Arbiter#(n) );

  Reg#(Vector#(n, Bool)) token <- mkReg(unpack(1));

//added by zhipeng
   function Bool vec2bool( Vector#(n, Bool) grants );
	  Bit#(n) grants_bit = pack(grants);
	  Bool grants_or = unpack(|grants_bit);
	  return grants_or;

   endfunction
//end add

  method ActionValue#(Vector#(n, Bool)) select( Vector#(n, Bool) requests );
  	Vector#(n, Bool) granted_A = unpack(0);
  	Vector#(n, Bool) granted_B = unpack(0);

    /////////////////////////////////////////////////////////////////////
    // Replicated arbiters are used to avoid cyclical carry chain
    // (see page 354, footnote 2 in Dally's book)
    /////////////////////////////////////////////////////////////////////

    // Arbiter 1
    Bool carry = False;
    for(Integer i=0; i < valueOf(n); i=i+1) begin
        let gc = gen_grant_carry(carry, requests[i], token[i]);
        granted_A[i] = tpl_1(gc);
        carry = tpl_2(gc);
    end

    // Arbiter 2 (uses the carry from Arbiter 1)
    for(Integer i=0; i < valueOf(n); i=i+1) begin
        let gc = gen_grant_carry(carry, requests[i], token[i]);
        granted_B[i] = tpl_1(gc);
        carry = tpl_2(gc);
    end

    Vector#(n, Bool) winner = unpack(0);
    //Maybe#(Bit#(m)) winner = Invalid;
    for(Integer k=0; k < valueOf(n); k=k+1) begin
      if(granted_A[k] || granted_B[k]) begin
        winner = unpack(0);
	    winner[k] = True;
      end
    end
	token <= vec2bool(winner) ? rotateR(winner) : token; //Added by zhipeng
   return winner;
  endmethod

/*
Zhipeng: it's not roundrobin, it's Oblivious Arbiter
with a shift register to rotate the priority by one position
each cycle.
"A round-robin arbiter operates on the principle that a request that
was just served should have the lowest priority on the next round of arbitration"
"If a grant was issued on the current cycle, one of the g(i) line will be high,
causing p(i+1) to go high on the next cycle"
*/
/*
  method Action next();
    action
      token <= rotate( token ); // WRONG -> this should get
    endaction

  endmethod
*/ //comment by zhipeng

//added by zhipeng
  method Action next();	
    action
      //token <= vec2bool(grants) ? rotateR( grants ) : token; // WRONG -> this should get
    endaction

  endmethod
//end add

endmodule

/*
//////////////////////////////////////////////////////
// Round-robin arbiter from Dally's book. Page 354
// Modified version to initialize with custom starting priority
module mkRoundRobinArbiterStartAt#(Integer startAt)( Arbiter#(n) );

  Vector#(n, Bool) init_token = unpack(0);
  init_token[startAt] = True;
  Reg#(Vector#(n, Bool)) token <- mkReg(init_token);

  method Vector#(n, Bool) select( Vector#(n, Bool) requests );
    Vector#(n, Bool) granted_A = unpack(0);
    Vector#(n, Bool) granted_B = unpack(0);

    /////////////////////////////////////////////////////////////////////
    // Replicated arbiters are used to avoid cyclical carry chain
    // (see page 354, footnote 2 in Dally's book)
    /////////////////////////////////////////////////////////////////////

    // Arbiter 1
    Bool carry = False;
    for(Integer i=0; i < valueOf(n); i=i+1) begin
        let gc = gen_grant_carry(carry, requests[i], token[i]);
        granted_A[i] = tpl_1(gc);
        carry = tpl_2(gc);
    end

    // Arbiter 2 (uses the carry from Arbiter 1)
    for(Integer i=0; i < valueOf(n); i=i+1) begin
        let gc = gen_grant_carry(carry, requests[i], token[i]);
        granted_B[i] = tpl_1(gc);
        carry = tpl_2(gc);
    end

    Vector#(n, Bool) winner = unpack(0);
    //Maybe#(Bit#(m)) winner = Invalid;

    for(Integer k=0; k < valueOf(n); k=k+1) begin
      if(granted_A[k] || granted_B[k]) begin
        winner = unpack(0);
	winner[k] = True;
      end
    end
    return winner;
  endmethod

  method Action next();
    action
      token <= rotate( token ); // WRONG -> this should get
    endaction
  endmethod

endmodule




module mkIterativeArbiter_fromEric( Arbiter#(n) );

  Reg#(Vector#(n, Bool)) token <- mkReg(unpack(1));

  method Vector#(n, Bool) select( Vector#(n, Bool) requests );
    Vector#(n, Bool) granted = unpack(0);

    for(Integer i=0; i < valueOf(n); i=i+1) begin
      let outcome = priority_encoder_onehot( i, token[i], requests );

      for(Integer j=0; j < valueOf(n); j=j+1) begin
        granted[j] = granted[j] || outcome[j];
      end
    end

    Vector#(n, Bool) winner = unpack(0);
    //Maybe#(Bit#(m)) winner = Invalid;

    for(Integer k=0; k < valueOf(n); k=k+1) begin
      if(granted[k]) begin
        winner = unpack(0);
	winner[k] = True; 
      end
    end
    return winner;
  endmethod

  method Action next();
    action
      token <= rotate( token );
    endaction
  endmethod

endmodule

module mkIterativeArbiter_fromEricStartAt#(Integer startAt) ( Arbiter#(n) );

  //Reg#(Vector#(n, Bool)) token <- mkReg(unpack(1));
  Vector#(n, Bool) init_token = unpack(0);
  init_token[startAt] = True;
  Reg#(Vector#(n, Bool)) token <- mkReg(init_token);

  method Vector#(n, Bool) select( Vector#(n, Bool) requests );
    Vector#(n, Bool) granted = unpack(0);

    for(Integer i=0; i < valueOf(n); i=i+1) begin
      let outcome = priority_encoder_onehot( i, token[i], requests );

      for(Integer j=0; j < valueOf(n); j=j+1) begin
        granted[j] = granted[j] || outcome[j];
      end
    end

    Vector#(n, Bool) winner = unpack(0);
    //Maybe#(Bit#(m)) winner = Invalid;

    for(Integer k=0; k < valueOf(n); k=k+1) begin
      if(granted[k]) begin
        winner = unpack(0);
	winner[k] = True; 
      end
    end
    return winner;
  endmethod

  method Action next();
    action
      token <= rotate( token );
    endaction
  endmethod

endmodule
*/ //comment by zhipeng


//------ Testing ----------

(* synthesize *)
module mkTestArbiter8(Arbiter#(8));
  Arbiter#(8) arb <- mkRoundRobinArbiter();
	

   function Bool vec3bool( Integer i );

	  //if ((i == 6) || (i == 1))
      	//return True;
	  //else
		//return False;

		return True;
   endfunction

   Vector#(8, Bool) vec = map( vec3bool,  genVector );

   Reg#(int) step <- mkReg(0);
   //Vector#(8, Bool) results = arb.select(vec);
   Vector#(8, Bool) zero = unpack(0);

   rule display_select;
	  $display("step %0d", step);
	  step <= step + 1;
	   Vector#(8, Bool) results <- arb.select(vec);
		//arb.next(zero);
      for (Integer i= 0; i < 8; i=i+1)
         $display("select[%0d] = %x", i, results[i]);
	  $display(" ");
      //$display("grants_or = %b", vec2bool(results));
	  $display(" ");
   endrule	

   rule finish(step == 10);
      $finish;
   endrule
  //Arbiter#(8) arb <- mkStaticPriorityArbiter();
  //Arbiter#(8) arb <- mkStaticPriorityArbiterStartAt(2);
  //Arbiter#(8) arb <- mkRoundRobinArbiter();
  //Arbiter#(8) arb <- mkRoundRobinArbiterStartAt(2);
  //Arbiter#(8) arb <- mkIterativeArbiter_fromEric();
  //return arb;
  //method select = arb.select;
  //method next = arb.next;
endmodule

/* =========================================================================
 *
 * Filename:            Router.bsv
 * Date created:        06-19-2011
 * Last modified:       06-19-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Collection of auxiliary functions and modules.
 *
 * =========================================================================
 */

`include "inc.v"
import Vector::*;
import NetworkTypes::*;

///////////////////////////////////////////////////////////////////////////////////////////////
// Auxiliary Functions:
// Most are compiled into separate modules (noinline) to reduce Bluespec compilation times.
///////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// Priority Encoder
function Maybe#(Bit#(m)) priority_encoder( Vector#(n, Bool) vec )
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

// noninline version for OutPort
(* noinline *)
function Maybe#(OutPort_t) outport_encoder( Vector#(NumOutPorts, Bool) vec );
  return encoder(vec);

  //Maybe#(OutPort_t) choice = Invalid;
  ////for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
  //for(Integer i=valueOf(NumOutPorts)-1; i >= 0; i=i-1)  // I want the lowest to have highest priority
  //begin
  //  if(vec[i]) begin
  //    choice = Valid(fromInteger(i));
  //  end
  //end
  //return choice; 
endfunction

/////////////////////////////////////////////////////////////////////////
// Priority Selector
// Given a bitmask that has a few bits toggled, it produces a same size
// bitmask that only has the least-significant bit toggled. If not bit
// was originally toggled, then result is same as input.
function Vector#(n, Bool) priority_selector( Vector#(n, Bool) vec );
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

//////////////////////////////////////////////////////////////////////////////////////////////
// Functions to prune and expand vectors by removing/adding an element at a specific index
function Vector#(m, element_type) pruneVector(Vector#(n, element_type) expanded_vec, Integer pruneIndex)
  provisos (Add#(m,1,n));
  //Vector#(TSub#(NumOutPorts, 1), Bool) pruned_outs = unpack(0);
  Vector#(m, element_type ) pruned_vec;
  Integer p = 0;
  for(Integer e=0; e<valueOf(n); e=e+1) begin 
    if( pruneIndex != e ) begin
      pruned_vec[p] = expanded_vec[e];
      p = p + 1;
    end
  end
  return pruned_vec;
endfunction

function Vector#(n, element_type) expandVector( Vector#(m, element_type) pruned_vec, Integer expandIndex, element_type fill_value)
  provisos (Add#(m,1,n));
  Vector#(n, element_type) expanded_vec;// = unpack(default);
  Integer p = 0;
  for(Integer e=0; e<valueOf(n); e=e+1) begin 
    if( expandIndex != e ) begin
      expanded_vec[e] = pruned_vec[p];
      p = p + 1;
    end else begin
      expanded_vec[e] = fill_value;
    end
  end
  return expanded_vec;
endfunction



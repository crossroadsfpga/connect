/* =========================================================================
 *
 * Filename:            IQRouterSimple.bsv
 * Date created:        11-29-2012
 * Last modified:       11-29-2012
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Parameterized Input-Queued Router module. Used as building block for 
 *  building larger networks. Implements RouterSimple interface.
 *
 * =========================================================================
 */

`include "inc.v"

import FIFO::*;
//import FIFOF::*;
import Vector::*;
import RegFile::*;
import ConfigReg::*;
import Assert::*;

import NetworkTypes::*;
import Aux::*;
import RF_16ports::*;
import RF_16portsLoad::*;
import RegFileMultiport::*;

import FIFOLevel::*;
import MultiFIFOMem::*;
import RegFIFO::*;

// Arbiters and Allocators used for scheduling
import Arbiters::*;
import Allocators::*;

// Eventually maybe replace this with more efficient/alternative single queue implementation
typedef MultiFIFOMem#(Flit_t, 1, FlitBufferDepth) InputQueue;
(* synthesize *)
module mkInputQueue(InputQueue);
  InputQueue inputQueue_ifc;
  if ( `PIPELINE_LINKS ) begin  // Add 1 cycle margin to FIFOs for credit that might be in transit
    inputQueue_ifc <- mkMultiFIFOMem(False /*storeHeadsTailsInLUTRAM*/, 1 /* full_margin */ );
  end else begin
    inputQueue_ifc <- mkMultiFIFOMem(False /*storeHeadsTailsInLUTRAM*/, 0 /* full_margin */ );
  end
  return inputQueue_ifc;
endmodule

typedef FIFOCountIfc#(OutPort_t, FlitBufferDepth) OutPortFIFO;
(* synthesize *)
module mkOutPortFIFO(OutPortFIFO);
  //String fifo_name = strConcat( strConcat(integerToString(id1), " - "), integerToString(id2));
  //OutPortFIFO outPortFIFO_ifc <- mkRegFIFO_named(fifo_name, False);
  OutPortFIFO outPortFIFO_ifc <- mkRegFIFO(False);
  return outPortFIFO_ifc;
endmodule

//typedef RF_16portsLoad#(RouterID_t, OutPort_t)  RouteTableOld;
//typedef RegFileMultiport#(NumInPorts/*nr*/, 1/*nw*/, RouterID_t, OutPort_t)  RouteTable;
//typedef RegFileMultiport#(NumInPorts/*nr*/, 1/*nw*/, UserPortID_t, OutPort_t)  RouteTable;
typedef RegFileMultiport#(NumInPorts/*nr*/, 1/*nw*/, UserRecvPortID_t, OutPort_t)  RouteTable;
module mkRouteTable#(String route_table_file) (RouteTable);
  //RouteTable rt_ifc     <- mkRF_16portsLoad(route_table_file);
  RouteTable rt_ifc     <- mkRegFileMultiportLoad(route_table_file);
  return rt_ifc;
endmodule

(* synthesize *)
module mkRouteTableSynth(RouteTable);
  String route_table_file = strConcat( strConcat(`NETWORK_ROUTING_FILE_PREFIX, integerToString(4)), ".hex");
  //RouteTableOld rt_ifc     <- mkRF_16portsLoad(route_table_file, False);
  RouteTable rt_ifc     <- mkRegFileMultiportLoad(route_table_file);
  return rt_ifc;
endmodule

////////////////////////////////////////////////
// Router Module implementation 
////////////////////////////////////////////////
module mkIQRouterSimple#(Integer id)(RouterSimple);
  String name = "IQRouterSimple";
  Bit#(8) errorCode = 0;

  Vector#(NumInPorts, InPortSimple)   inPort_ifaces;                     // in port interfaces
`ifdef EN_DBG
  RouterCoreSimple router_core <- mkIQRouterCoreSimple(id);
`else
  RouterCoreSimple router_core <- mkIQRouterCoreSimple();
`endif
  // Route Table
  String route_table_file = strConcat( strConcat(`NETWORK_ROUTING_FILE_PREFIX, integerToString(id)), ".hex");
  //RF_16portsLoad#(RouterID_t, OutPort_t)   routeTable     <- mkRF_16portsLoad(route_table_file, /*binary*/False);
  //RouteTable                               routeTable     <- mkRouteTable(route_table_file, /*binary*/False);
  RouteTable  routeTable  <- mkRouteTable(route_table_file);

  // for debugging
  `ifdef EN_DBG
    Reg#(Cycle_t)         cycles             <- mkConfigReg(0);
    rule update_cycles(True);
      cycles <= cycles + 1;
    endrule
  `endif

  // Define input interfaces
  for(Integer i=0; i < valueOf(NumInPorts); i=i+1) begin
    let ifc =
      interface InPortSimple
	method Action putFlit(Maybe#(Flit_t) flit_in);
          Maybe#(RoutedFlit_t) rt_flit = Invalid;
	  //`DBG_ID(("Receiving Flit on in_port %0d", i));
	  if(isValid(flit_in)) begin
	    let fl_in = flit_in.Valid;
	    let out_p = routeTable.r[i].sub(fl_in.dst);
	    //let fl_in = tagged Valid Flit_t{is_tail:flit_in.Valid.is_tail, dst:flit_in.Valid.dst, out_p:out_p, vc:flit_in.Valid.vc, data:flit_in.Valid.data};
	    rt_flit = tagged Valid RoutedFlit_t{flit:fl_in, out_port:out_p};
	    //rt_flit = tagged Valid RoutedFlit_t{ flit:Flit_t{is_tail:fl_in.is_tail, dst:fl_in.dst, out_p:out_p, vc:fl_in.vc, data:fl_in.data}, out_port:out_p};
	    `DBG_ID_CYCLES(("Incoming flit on port %0d - dest:%0d, vc:%0d, data:%x", i, fl_in.dst, fl_in.vc, fl_in.data ));
      	  end
	  router_core.in_ports[i].putRoutedFlit(rt_flit);
	endmethod

	// send credits upstream
        method ActionValue#(Vector#(NumVCs, Bool)) getNonFullVCs;
	  let cr_out <- router_core.in_ports[i].getNonFullVCs();
	  return cr_out;
	endmethod

      endinterface;

    inPort_ifaces[i] = ifc;
  end

  interface in_ports = inPort_ifaces;
  interface out_ports = router_core.out_ports;
  //interface rt_info = rt_info_ifc;
   
endmodule


module mkIQRouterSimpleSynth(RouterSimple);
  let rt_synth <- mkIQRouterSimple(4);
  return rt_synth;
endmodule


////////////////////////////////////////////////
// Router Module implementation 
////////////////////////////////////////////////
//module mkRouter#(RouterID_t id) (Router);
`ifdef EN_DBG
module mkIQRouterCoreSimple#(Integer id)(RouterCoreSimple);
`else
(* synthesize *)
module mkIQRouterCoreSimple(RouterCoreSimple);
`endif

  String name = "IQRouterCoreSimple";
  Bit#(8) errorCode = 0;
  
  // Vector of input and output port interfaces
  Vector#(NumInPorts, RouterCoreInPortSimple)                                       inPort_ifaces;                     // in port interfaces
  Vector#(NumOutPorts, OutPortSimple)                                               outPort_ifaces;                    // out port interfaces

  // Router Allocator
  RouterAllocator                                                             routerAlloc    <- mkSepRouterAllocator(`PIPELINE_ALLOCATOR /*pipeline*/);

  // Router State
  Vector#(NumInPorts, InputQueue)                                             flitBuffers <- replicateM(mkInputQueue());
  //Vector#(NumInPorts, RF_16ports#(VC_t, FlitBuffer_t) )                       flitBuffers    <- replicateM(mkRF_16ports());
  Vector#(NumInPorts, OutPortFIFO)                                            outPortFIFOs;
  Vector#(NumOutPorts, Wire#(Bool))                                           simple_credits;

  Vector#(NumInPorts, Wire#(Maybe#(Flit_t)))                                  hasFlitsToSend_perIn <- replicateM(mkDWire(Invalid));
  Vector#(NumInPorts, Wire#(Maybe#(Flit_t)))                                  flitsToSend_perIn    <- replicateM(mkDWire(Invalid));
  // Used for multi-flit packets that use virtual links
  //if(`USE_VIRTUAL_LINKS) begin
    Vector#(NumOutPorts, Reg#(Bool) )                                         lockedVL;     // locked virtual link
    Vector#(NumOutPorts, Reg#(InPort_t))                                      inPortVL;     // holds current input for locked virtual channels
  //end


  // for debugging
  `ifdef EN_DBG
    Reg#(Cycle_t) cycles <- mkConfigReg(0);
    rule update_cycles(True); cycles <= cycles + 1; endrule
  `endif

  simple_credits <- replicateM(mkDWire(False));   // don't assume credits
  outPortFIFOs   <- replicateM(mkOutPortFIFO());

  lockedVL       <- replicateM(mkConfigReg(False));
  inPortVL       <- replicateM(mkConfigReg(unpack(0)));

  // -- Initialization --
  /*for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin
    //credits[o]        <- replicateM(mkConfigReg(True));   // start with credits for all ouputs/VCs
    lockedVL[o]       <- replicateM(mkConfigReg(False));
    inPortVL[o]       <- replicateM(mkConfigReg(unpack(0)));
  end*/

  // -- End of Initialization --
    
  // -- Allocation --
  // These structures get populated with the arbitration results
  // Used for faster handling of upstream credits
  //Vector#(NumInPorts, Maybe#(VC_t))          activeVC_perIn  = replicate(Invalid);      // arbitration populates this
  //Vector#(NumInPorts, Wire#(Maybe#(VC_t)))     activeIn_perIn_s0; // = replicate(Invalid);
  //Vector#(NumInPorts, Maybe#(VC_t))         activeVC_perIn_s0 = replicate(Invalid);
  //Vector#(NumInPorts, Reg#(Maybe#(VC_t)))   activeVC_perIn_reg <- replicateM(mkConfigReg(Invalid));
  //Vector#(NumInPorts, Maybe#(VC_t))         activeVC_perIn;      // this is popuated depending on allocator pipeline options
//  `ifdef RESTRICT_UTURNS
//    // pruned version
//    Vector#(NumOutPorts, Maybe#( Bit#( TLog#( TSub#(NumInPorts, 1) ) )  ))     activeIn_perOut_pruned = replicate(Invalid);
//  `else
    Vector#(NumOutPorts, Maybe#(InPort_t))     activeIn_perOut = replicate(Invalid);
//  `endif

  
  //Vector#(NumOutPorts, VC_t)                 activeVC_perOut = replicate(0);            // This is only valid if activeIn_perOut is Valid - not Maybe type to avoid spending an extra bit
  //Vector#(NumOutPorts, Maybe#(VC_t))                 activeVC_perOut = replicate(Invalid);            // This is only valid if activeIn_perOut is Valid - not Maybe type to avoid spending an extra bit


  // Input to allocator
  Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) )  eligIO = unpack(0);  

  Vector#(NumInPorts, Bool )         flitBuffers_notEmpty = unpack(0);
  Vector#(NumInPorts, OutPort_t)     outPortFIFOs_first   = unpack(0);
  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    let tmp                 = flitBuffers[i].notEmpty();
    flitBuffers_notEmpty[i] = tmp[0]; // VC is always 0 for input-queued router 
    outPortFIFOs_first[i]   = outPortFIFOs[i].first();
  end

  Vector#(NumOutPorts, Bool)      credit_values;  
  Vector#(NumOutPorts, Bool )                                      lockedVL_values;     // locked virtual link
  Vector#(NumOutPorts, InPort_t)                                   inPortVL_values;     // holds current input for locked virtual channels
  for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin
    credit_values[o] = simple_credits[o];
    //lockedVL_values[o] = readVReg(lockedVL[o]);
    //inPortVL_values[o] = readVReg(inPortVL[o]);
  end
  lockedVL_values = readVReg(lockedVL);
  inPortVL_values = readVReg(inPortVL);

  // Build eligIO and mark selected-active VC per Input (lowest VC has priority)
  // -- Option 1: cleaner, but less scalable -- is too slow when USE_VIRTUAL_LINKS is enabled
  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    let not_empty = flitBuffers_notEmpty[i];
    let out_port = outPortFIFOs_first[i];

    if(not_empty && simple_credits[out_port]) begin

      if(`USE_VIRTUAL_LINKS) begin
	let is_locked = lockedVL[out_port];
	if( !is_locked || (is_locked && inPortVL[out_port] == fromInteger(i) ) ) begin
	  eligIO[i] = replicate(False);
          eligIO[i][out_port] = True; 
	end
      end else begin
        eligIO[i][out_port] = True; 
      end

    end
  end

  // -- End Option 1 -- 

  // -- Option 2: more scalable, but harder to read -- 
//  let build_eligIO_result = build_eligIO_and_other_alloc_structs(flitBuffers_notEmpty, outPortFIFOs_first, credit_values, lockedVL_values, inPortVL_values);
//  eligIO          = tpl_1(build_eligIO_result);
//  activeVC_perIn  = tpl_2(build_eligIO_result);
//  activeVC_perOut = tpl_3(build_eligIO_result);
  // -- End Option 2 -- 

  // Perform allocation
  Vector#(NumInPorts, Bool) activeInPorts = unpack(0);
  //Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) )  selectedIO = routerAlloc.allocate(eligIO);
  Vector#(NumInPorts, Vector#(NumOutPorts, Wire#(Bool) ) )  selectedIO_s0; //= routerAlloc.allocate(eligIO);
  Vector#(NumInPorts, Vector#(NumOutPorts, Reg#(Bool) ) )   selectedIO_reg;
  Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) )         selectedIO; // this is popuated depending on allocator pipeline options

  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    selectedIO_reg[i] <- replicateM(mkConfigReg(False));
    selectedIO_s0[i] <- replicateM(mkDWire(False));
  end

  if(`PIPELINE_CORE) begin
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      selectedIO[i]     = readVReg(selectedIO_reg[i]);
      //activeVC_perIn[i] = activeVC_perIn_reg[i];
    end
  end else begin
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      selectedIO[i]     = readVReg(selectedIO_s0[i]);
      //activeVC_perIn[i] = activeVC_perIn_s0[i];
    end
  end

  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    Maybe#(OutPort_t) selectedOut = outport_encoder(selectedIO[i]);
    if (isValid(selectedOut)) begin

      if (getPipeLineStages() == 0) begin // no pipelining
	activeInPorts[i] = True;
	//InPort_t inp = fromInteger(i);
	//activeIn_perOut[selectedOut.Valid] = tagged Valid inp;
	activeIn_perOut[selectedOut.Valid] = tagged Valid fromInteger(i);

      end else begin                     // pipelining, perform extra checks, because scheduler might had used stale info
	let tmp = flitBuffers[i].notEmpty(); // double check that there is a flit - VC is always 0 for input-queued router 
	let has_flits = tmp[0]; // double check that there is a flit - VC is always 0 for input-queued router 
	let has_credits = simple_credits[selectedOut.Valid]; // double check that credits still exist. Alternatively change margin in mkMultiFIFOMem
	if (has_flits && has_credits) begin
	  activeInPorts[i] = True;
	  //InPort_t inp = fromInteger(i);
	  //activeIn_perOut[selectedOut.Valid] = tagged Valid inp;
	  activeIn_perOut[selectedOut.Valid] = tagged Valid fromInteger(i);
	end
      end

    end
  end

  rule performAllocation(True);
    let alloc_result <- routerAlloc.allocate(eligIO);
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      writeVReg(selectedIO_s0[i], alloc_result[i]);
    end
  endrule

  rule advanceAllocator(True);
    routerAlloc.next();
    if(`PIPELINE_CORE) begin
    //if(PipelineAllocator) begin
      for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
	writeVReg(selectedIO_reg[i], readVReg(selectedIO_s0[i]));
	//activeVC_perIn_reg[i] <= activeVC_perIn_s0[i];
      end
    end
  endrule

  rule gatherFlitsToSend(True);
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      if(activeInPorts[i]) begin
	let fl <- flitBuffers[i].deq(0);  // VC is always 0 for input-queued router
	//if(fl.vc != activeVC_perIn[i].Valid) begin
       	//   `DBG_ID(("Selected VC %d does not match flit VC %d for input %d", activeVC_perIn[i].Valid, fl.vc, i));
	//end 
	hasFlitsToSend_perIn[i] <= tagged Valid fl;
	//let out_port = outPortFIFOs_first[i][activeVC_perIn[i].Valid];
        outPortFIFOs[i].deq();
	//$display(" ---> Router: %0d - dequeing from outPortFIFOs[%0d][%0d]", id, i, activeVC_perIn[i].Valid);

	//if(fl.out_p != out_port) begin
       	//   `DBG_ID(("Outport mismatch! fl.out_p: %d does not match out_port %d", fl.out_p, out_port));
	//end 
	//activeVC_perOut[out_port] <= tagged Valid activeVC_perIn[i].Valid;
      end
    end
  endrule


//  ////////////////////////////////////////////////////////////////////////////////////////////// 
//  // Old MEMOCODE arbiter - performs static priority maximal matching
//  // First mask out entries that don't have credits or are ineligible to be picked - Convert to function
//  Vector#(NumVCs, Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) ) )  eligVIO = unpack(0);  //perOut_perVC_perIn;
//  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
//    let not_empty = flitBuffers[i].notEmpty();
//    for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
//      if(not_empty[v]) begin
//	let out_port = outPortFIFOs[i][v].first();
//	if(credits[out_port][v]>0) begin
//	  eligVIO[v][i][out_port] = True;
//	end
//      end
//    end
//  end
// 
//
//
//  // Arbitration - packaged main arbitration logic for each output in "noinline" function --> this reduces compilation times by 2 ORDERS OF MAGNITUDE!
//  Tuple3#( Vector#(NumInPorts, Maybe#(VC_t)),       /* activeVC_perIn */
//	   Vector#(NumOutPorts, Maybe#(InPort_t)),  /* activeIn_perOut */
//	   Vector#(NumOutPorts, VC_t)               /* activeVC_perOut */
//	 ) arb_result;
//
//  arb_result = arbitrateAll(eligVIO);
//  activeVC_perIn = tpl_1(arb_result);
//  activeIn_perOut = tpl_2(arb_result);
//  activeVC_perOut = tpl_3(arb_result);
//  
//  Vector#(NumInPorts, Bool) activeInPorts = unpack(0);
//  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
//    for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin 
//      if(isValid(activeIn_perOut[o]) && activeIn_perOut[o].Valid == fromInteger(i)) begin
//        activeInPorts[i] = True;
//      end
//    end
//  end
//
//  rule gatherFlitsToSend(True);
//    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
//      if(activeInPorts[i]) begin
//	let fl <- flitBuffers[i].deq(activeVC_perIn[i].Valid);
//	flitsToSend_perIn[i] <= tagged Valid fl;
//        outPortFIFOs[i][activeVC_perIn[i].Valid].deq();
//      end
//    end
//  endrule

  // End or Arbitration - at this point I have selected an Input and Outputs for each VC, which are kept in activeIn_perVC and activeOut_perVC. (activeIn_perVC will be Invalid if no selection was made.

  //////////////////////////////////////////
  // Rules for updating State
  //////////////////////////////////////////

  // rule to update hasFlitsVIO. Writes new incoming flits and clears entries that were sent in this cycle
  //(* no_implicit_conditions *)
//  rule update_hasFlitsVIO (True);
//    for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
//      for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
//        for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin 
//	  // Note: It's possible to only first check for set and then clear, because the signals are mutually exclusive
//	  // for all input ports except for the traffic source (because there is at least 1 cycle credit delay they never
//	  // deliver consecutive flits for the same VC and input. In the case of the traffic source, because it always 
//	  // tries to inject and has instant knowledge of credits, we are guaranteed that if set is asserted then clear will 
//	  // also be asserted. I.e. the source does not have produce any hiccups. 
//	  // The commented version of the if-else conditions also work.
//          //if ( hasFlitsVIO_set[v][i][o] && !hasFlitsVIO_clear[v][i][o]) begin // something came in on an in_port --> set
//          if ( hasFlitsVIO_set[v][i][o] ) begin // something came in on an in_port --> set
//            hasFlitsVIO[v][i][o] <= True;
//            `DBG(("Marking incoming flit for out:%0d VC:%0d from in:%0d", o, v, i));
//          //end else if ( hasFlitsVIO_clear[v][i][o] && !hasFlitsVIO_set[v][i][o]) begin  // something departed --> clear
//          end else if ( hasFlitsVIO_clear[v][i][o] ) begin  // something departed --> clear
//            `DBG(("Clearing flit for out:%0d VC:%0d from in:%0d", o, v, i));
//            hasFlitsVIO[v][i][o] <= False;
//          end
//	end
//      end
//    end
//  endrule
  
  // Rule to update credits. Credits get replenished from out_ports and are spent when sending flits.
/*  (* fire_when_enabled *)
  rule update_credits (True);   // turn off credits for debugging
    for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin
      if ( credits_set[o] && !credits_clear[o] ) begin   // I only received a credit
	//credits[o][v] <= True;
	credits[o] <= credits[o] + 1;
	if(credits[o]+1 > fromInteger(valueof(FlitBufferDepth))) begin
	  `DBG_ID(("Credit overflow at out_port %0d", o));
	end
      end else if (!credits_set[o] && credits_clear[o]) begin   // I only spent a credit
	//credits[o][v] <= False;
	credits[o] <= credits[o] - 1;
	if(credits[o] == 0) begin
	  `DBG_ID(("Credit underflow at out_port %0d", o));
	end
      end
    end
    //`DBG_DETAIL_ID(("credits:%b", readVReg(concat(credits)) ));  // flatten the array to print
  endrule
  */


  function Action printAllocMatrix(Vector#(n, Vector#(m, Bool)) am);
    action
    for(Integer i=0; i<valueOf(n); i=i+1) begin
      //noAction;
      //$display("%b", am[i]);
      //$display("%b", am[i]);
    end
    endaction
  endfunction

  // Rule for debugging
  rule dbg (`EN_DBG_RULE);
    if(errorCode != 0) begin // error
      $display("Error (errorCode:%d)", errorCode);
      $stop;
    end
  
    `DBG_ID(("Allocation input - eligIO"));
    printAllocMatrix(eligIO);
    `DBG_ID(("Allocation result - selectedIO"));
    printAllocMatrix(selectedIO);

    for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
      //`DBG_DETAIL_ID(("Cycle:%0d, hasFlitsVIO[%0d]  :%b", cycles, v, readVReg(concat(hasFlitsVIO[v])) ));  // flatten the array to print
      `DBG_DETAIL_ID(("Cycle:%0d, eligVIO[%0d]      :%b", cycles, v, eligVIO[v]));
    end

    for(Integer i=0; i < valueOf(NumInPorts); i=i+1) begin
      `DBG_ID(("selectedIO[%d]: %b - encoded: %d", i, selectedIO[i], outport_encoder(selectedIO[i]).Valid ));
    end
    `DBG_ID(("activeInPorts: %b", activeInPorts));
    for(Integer o=0; o < valueOf(NumOutPorts); o=o+1) begin
      `DBG_ID(("activeIn_perOut[%d]: %d", o, activeIn_perOut[o].Valid ));
    end
    for(Integer i=0; i < valueOf(NumInPorts); i=i+1) begin
      `DBG_ID(("hasFlitsToSend_perIn[%d]: %d", i, hasFlitsToSend_perIn[i].Valid));
      /*for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
	`DBG_ID(("outPortFIFOs[%d][%d]: %d", i, v , outPortFIFOs[i][v].first()));
      end*/
    end
    for(Integer o=0; o < valueOf(NumOutPorts); o=o+1) begin
      /*for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
        `DBG_DETAIL_ID(("Cycle:%0d, credits[Out:%0d][VC:%0d] :%d", cycles, o, v, credits[o][v]));
      end*/
      //if(isValid(activeVC_perOut[o]) && isValid(activeIn_perOut[o]) ) begin
      //$write(  "DBG:%0d, R%0d  lockedVL[%0d] :", cycles, id, o);
      //for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
      //  $write("%d ", inPortVL[o][v]);
      //end
      //$write("\n");
      if(isValid(activeIn_perOut[o])) begin  // I have a flit to send
	let active_in = activeIn_perOut[o].Valid;
	//let active_vc = activeVC_perOut[o];
	//let active_vc = activeVC_perOut[o].Valid;
    	//`DBG_DETAIL_ID(("Cycle:%0d, Arbitration Results: Output %0d - activeVC: %0d, activeIn: %0d", cycles, o, active_vc, active_in));
    	//`DBG_ID(("Cycle:%0d, Arbitration Results: Output %0d - activeVC: %0d, activeIn: %0d", cycles, o, active_vc, active_in));
      end    
      //`DBG_DETAIL_ID(("Cycle:%0d, eligOVI_reg[%0d]:%b", cycles, o, readVReg(concat(eligOVI_reg[o])) ));
    end

    `ifdef EN_DBG_DETAIL
      `DBG_DETAIL(("\nAllocator Input: "));
      printAllocMatrix(eligIO);
      `DBG_DETAIL(("\nAllocator Output: "));
      printAllocMatrix(selectedIO);
    `endif

    //`DBG((" eligVCs_perO:%b", eligVCs_perO));
  endrule


  ///////////////////////////////////////////////////////
  // Router Interface Implementation
  ///////////////////////////////////////////////////////

  // Define input interfaces
  for(Integer i=0; i < valueOf(NumInPorts); i=i+1) begin
    let ifc =
      interface RouterCoreInPortSimple
	method Action putRoutedFlit(Maybe#(RoutedFlit_t) flit_in);
	  //`DBG(("Receiving Flit on in_port %0d", i));
	  if(isValid(flit_in)) begin
	    let fl_in = flit_in.Valid.flit;
	    let out_port = flit_in.Valid.out_port;
	    //let out_port = routeTable.read_ports[i].read(fl_in.dst);
	    //flitBuffers[i].write(fl_in.vc, FlitBuffer_t{is_tail:fl_in.is_tail, data:fl_in.data, dst:fl_in.dst});
	    flitBuffers[i].enq(0, fl_in);    // VC is always 0 for input-queued router
	    outPortFIFOs[i].enq(out_port);
	    //$display(" ---> Router: %0d - enqueing to outPortFIFOs[%0d][%0d]", id, i, fl_in.vc);
	    //`DBG(("Marking incoming flit for dst:%0d VC:%0d from in:%0d (isT:%0d)", fl_in.dst, fl_in.vc, i, /*fl_in.is_head,*/ fl_in.is_tail));
	    //hasFlitsVIO_set[fl_in.vc][i][out_port] <= True;
	  end 
	endmethod

	// send credits upstream
        method ActionValue#(Vector#(NumVCs, Bool)) getNonFullVCs;
	  Vector#(NumVCs, Bool) ret = unpack(0);
	  let tmp = flitBuffers[i].notFull();
	  ret[0] = tmp[0]; // VC is always 0 for input-queued router 
	  return ret; 	
	endmethod
      endinterface;

    inPort_ifaces[i] = ifc;
  end

  // Implement output interfaces
  for(Integer o=0; o < valueOf(NumOutPorts); o=o+1) begin
    let ifc =
      interface OutPortSimple
	  method ActionValue#(Maybe#(Flit_t)) getFlit();
	    Maybe#(Flit_t) flitOut = Invalid;
	    if( isValid(activeIn_perOut[o]) ) begin  // I have a flit to send
	      let active_in  = activeIn_perOut[o].Valid;
	      //let active_vc  = activeVC_perOut[o].Valid;
	      //if(!isValid(activeVC_perOut[o])) begin
	      //  `DBG_ID(("active_vc is invalid!"));
	      //end
	      //let fb = flitBuffers[ active_in ].read_ports[o].read(active_vc);
	      //let fb <- flitBuffers[active_in].deq(active_vc); 
	      //let fb <- flitsToSend_perIn[active_in];
	      //outPortFIFOs[active_in][active_vc].deq();

              //hasFlitsVIO_clear[active_vc][active_in][o] <= True;
	      //if(fb.is_tail) begin // If you see a tail unlock VL  (also covers head/tail case)
	      //  lockedVL[o][active_vc] <= False;
	      //  //`DBG_DETAIL_ID(("UNLOCKED output %0d (was locked to in:%0d)", o, inPortVL[o][active_vc] ));
	      //end else begin // it's not a tail (i.e. head or in the middle of a packet), so lock the VL.
	      //  lockedVL[o][active_vc] <= True;
	      //  //`DBG_DETAIL_ID(("LOCKED output %0d locked to in:%0d, VC:%0d (flit %0d)", o, active_in, active_vc, fb.id  ));
	      //  inPortVL[o][active_vc] <= active_in;
	      //end
	      //flitOut = tagged Valid Flit_t{is_tail:fb.is_tail, dst:fb.dst, vc:active_vc, data:fb.data };
	      //flitOut = flitsToSend_perIn[active_in];

	      `ifdef RESTRICT_UTURNS
		// pruned version
		// Generate pruned activeIn
		dynamicAssert(active_in != fromInteger(o), "No U-turns allowed!");
		Vector#(NumInPorts, Bool) selectedInput = unpack(0);
		selectedInput[active_in] = True;
		let selectedInput_pruned = pruneVector(selectedInput, o);
		let active_in_pruned = encoder(selectedInput_pruned);
		let hasFlitsToSend_perIn_pruned = pruneVector(hasFlitsToSend_perIn, o);
		flitOut = hasFlitsToSend_perIn_pruned[active_in_pruned.Valid];
	      `else
	      //end else begin
	        // no pruning
	        flitOut = hasFlitsToSend_perIn[active_in];
	      `endif
	      //end

	      dynamicAssert(isValid(flitOut), "Output selected invalid flit!");

              if(`USE_VIRTUAL_LINKS) begin
		if(flitOut.Valid.is_tail) begin // If you see a tail unlock VL  (also covers head/tail case)
		    lockedVL[o] <= False;
		    `DBG_DETAIL_ID(("UNLOCKED output %0d (was locked to in:%0d)", o, inPortVL[o] ));
		end else begin
		    lockedVL[o] <= True;
		    `DBG_DETAIL_ID(("LOCKED output %0d locked to in:%0d", o, active_in ));
		    inPortVL[o] <= active_in;
		end
	      end

	      //dynamicAssert(flitOut.Valid.vc == active_vc, "Flit VC and active VC do not match!");
	      //if(flitOut.Valid.out_p != fromInteger(o)) begin
	      //   `DBG_ID(("Flit out_port %d does not match actual out_port %d", flitOut.Valid.out_p, o));
	      //end 

	      // clear credits
	      //credits_clear[o] <= True;  // VC is always 0 for input-queued router 

	    end

	    return flitOut;
	  endmethod

	  // receive credits from downstream routers
	  method Action putNonFullVCs(Vector#(NumVCs, Bool) nonFullVCs);
	    `DBG_DETAIL_ID(("Receiving Credit on out_port %0d", o));
	    simple_credits[o] <= nonFullVCs[0]; // VC is always 0 for input-queued router
	    `DBG_DETAIL(("Cycle: %0d: Non-full VCs for out_port %0d: %b", cycles, o, nonFullVCs));
	  endmethod

      endinterface;
    outPort_ifaces[o] = ifc;
  end

  interface in_ports = inPort_ifaces;
  interface out_ports = outPort_ifaces;
  
endmodule



/////////////////////////////////////////////////////////////////////////////////////////// 
/////////////////////////////////////////////////////////////////////////////////////////// 



//////////////////////////////////////////////////////////////
// Old Arbitration Functions
//////////////////////////////////////////////////////////////

//(* noinline *)
//function Maybe#(VC_t) pickVC( Vector#(NumVCs, Bool) eligVCs );
//  Maybe#(VC_t) sel_VC = Invalid;
//  //for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
//  for(Integer v=valueOf(NumVCs)-1; v >= 0; v=v-1)  // I want the lowest to have highest priority
//  begin
//    if(eligVCs[v]) begin
//      sel_VC = Valid(fromInteger(v));
//    end
//  end
//  return sel_VC;
//endfunction

//(* noinline *)
//function Maybe#(InPort_t) pickIn( Vector#(NumInPorts, Bool) eligIns );
//  Maybe#(InPort_t) sel_In = Invalid;
//  //for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
//  for(Integer i=valueOf(NumInPorts)-1; i >= 0; i=i-1)  // I want the lowest to have highest priority
//  begin
//    if(eligIns[i]) begin
//      sel_In = Valid(fromInteger(i));
//    end
//  end
//  return sel_In;
//endfunction

//(* noinline *)
//function Vector#(NumVCs, Vector#(NumInPorts, Bool )) maskOccupiedInputs(Vector#(NumVCs, Vector#(NumInPorts, Bool )) eligVI, Vector#(NumInPorts, Bool) freeInputs);
//  for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
//    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
//      if(freeInputs[i]) begin
//	eligVI[v][i] = False;
//      end
//    end
//  end
//  return eligVI;
//endfunction


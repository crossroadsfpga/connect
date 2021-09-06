/* =========================================================================
 *
 * Filename:            VOQRouterSimple.bsv
 * Date created:        09-18-2012
 * Last modified:       09-18-2012
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Parameterized VOQ Router module. Used as building block for building larger 
 * networks. Implements RouterSimple interface
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

//  ///////////////////////////////////////////////////////////////////////////
//  // Router Interface
//  interface VOQRouterSimple;
//    // Port Interfaces
//    interface Vector#(NumInPorts, VOQInPortSimple) in_ports;
//    interface Vector#(NumOutPorts, VOQOutPortSimple) out_ports;
//    // Used to query router info (e.g. ID)
//    //interface RouterInfo rt_info;
//    //method Action setRoutingEntry(RouterID_t dst, OutPort_t out_p);
//  endinterface
//  
//  ////////////////////////////////////////////////
//  // Simpler InPort and OutPort interfaces
//  //   - Routers only exchange notFull signals, instead of credits
//  // Implemented by routers and traffic sources                      
//  ////////////////////////////////////////////////                   
//  interface VOQInPortSimple;                             
//    (* always_ready *) method Action putFlit(Maybe#(Flit_t) flit_in);
//    (* always_ready *) method ActionValue#(Bool) getNonFull;
//  endinterface
//  
//  interface VOQOutPortSimple;
//    (* always_ready *) method ActionValue#(Maybe#(Flit_t)) getFlit();
//    (* always_ready *) method Action putNonFull(Bool putNonFull);
//  endinterface
//  
//  
//  ///////////////////////////////////////////////////////////////////////////
//  // VOQRouterCoreSimple Interface
//  interface VOQRouterCoreSimple;
//    interface Vector#(NumInPorts, VOQRouterCoreInPortSimple) in_ports;  // Same as router in_ports, but also carry routing info
//    interface Vector#(NumOutPorts, VOQOutPortSimple) out_ports;
//    //interface Vector#(NumInPorts, Client#(RouterID_t, OutPort_t)) rt;
//  endinterface
//  
//  // InPort interface for RouterCore
//  interface VOQRouterCoreInPortSimple;
//    (* always_ready *) method Action putRoutedFlit(Maybe#(RoutedFlit_t) flit_in);
//    (* always_ready *) method ActionValue#(Bool) getNonFull;
//  endinterface


//typedef RF_16portsLoad#(RouterID_t, OutPort_t)  RouteTableOld;
typedef RegFileMultiport#(NumInPorts/*nr*/, 1/*nw*/, UserRecvPortID_t, OutPort_t)  RouteTable;
module mkRouteTable#(String route_table_file) (RouteTable);
  //RouteTable rt_ifc     <- mkRF_16portsLoad(route_table_file);
  RouteTable rt_ifc     <- mkRegFileMultiportLoad(route_table_file);
  return rt_ifc;
endmodule

(* synthesize *)
module mkRouteTableSynth(RouteTable);
  String route_table_file = strConcat( strConcat(`NETWORK_ROUTING_FILE_PREFIX, integerToString(0)), ".hex");
  //RouteTableOld rt_ifc     <- mkRF_16portsLoad(route_table_file, False);
  RouteTable rt_ifc     <- mkRegFileMultiportLoad(route_table_file);
  return rt_ifc;
endmodule

typedef MultiFIFOMem#(Flit_t, NumOutPorts, FlitBufferDepth) InputVOQueues;
(* synthesize *)
module mkInputVOQueues(InputVOQueues);
  InputVOQueues inputVOQueues_ifc; 
  // not needed because I double-check credits when pipelining. Enable if the credit-check is removed.
  //inputVOQueues_ifc <- mkMultiFIFOMem(False /*storeHeadsTailsInLUTRAM*/, getPipeLineStages() /*full_margin*/);
  if ( `PIPELINE_LINKS ) begin  // Add 1 cycle margin to FIFOs for credit that might be in transit
    inputVOQueues_ifc <- mkMultiFIFOMem(False /*storeHeadsTailsInLUTRAM*/, 1 /*full_margin*/); 
  end else begin
    inputVOQueues_ifc <- mkMultiFIFOMem(False /*storeHeadsTailsInLUTRAM*/, 0 /*full_margin*/); 
  end
  return inputVOQueues_ifc;
endmodule


////////////////////////////////////////////////
// VOQ Router Module implementation 
////////////////////////////////////////////////
//module mkRouter#(RouterID_t id) (Router);
`ifdef EN_DBG
module mkVOQRouterCoreSimple#(Integer id)(RouterCoreSimple);
`else
(* synthesize *)
module mkVOQRouterCoreSimple(RouterCoreSimple);
`endif

  String name = "VOQRouterCoreSimple";
  Bit#(8) errorCode = 0;
  
  // Vector of input and output port interfaces
  Vector#(NumInPorts, RouterCoreInPortSimple)                                       inPort_ifaces;                     // in port interfaces
  Vector#(NumOutPorts, OutPortSimple)                                               outPort_ifaces;                    // out port interfaces

  // Router Allocator
  RouterAllocator                                                             routerAlloc    <- mkSepRouterAllocator(`PIPELINE_ALLOCATOR /*pipeline*/);

  // Router State
  Vector#(NumInPorts, InputVOQueues)                                          flitVOQBuffers <- replicateM(mkInputVOQueues());
  //Vector#(NumOutPorts, Vector#(NumOutPorts, Reg#(Bit#(TLog#(TAdd#(FlitBufferDepth,1))))))      credits;
  //Vector#(NumOutPorts, Reg#(Bool))      simple_credits;
  Vector#(NumOutPorts, Wire#(Bool))     simple_credits;

  Vector#(NumInPorts, Wire#(Maybe#(Flit_t)))                                  hasFlitsToSend_perIn <- replicateM(mkDWire(Invalid));
  Vector#(NumInPorts, Wire#(Maybe#(Flit_t)))                                  flitsToSend_perIn    <- replicateM(mkDWire(Invalid));
  // Used for multi-flit packets that use virtual links


    Vector#(NumOutPorts, Reg#(Bool) )                                         lockedVL;     // locked virtual link
    Vector#(NumOutPorts, Reg#(InPort_t))                                      inPortVL;     // holds current input for locked virtual channels

  // Update wires
  //Vector#(NumOutPorts, Vector#(NumVCs, Wire#(Bool) ))                         credits_set;   // to handle incoming credits
  //Vector#(NumOutPorts, Vector#(NumVCs, Wire#(Bool) ))                         credits_clear; // to clear credits due to outgoing flits

  // for debugging
  `ifdef EN_DBG
    Reg#(Cycle_t)         cycles             <- mkConfigReg(0);
    rule update_cycles(True);
      cycles <= cycles + 1;
    endrule
  `endif

  // -- Initialization --
  //simple_credits        <- replicateM(mkConfigReg(True));   // start with credits for all ouputs/VCs
  simple_credits        <- replicateM(mkDWire(False));   // don't assume credits
  for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin
    //credits[o]        <- replicateM(mkConfigReg(True));   // start with credits for all ouputs/VCs
  end

  lockedVL       <- replicateM(mkConfigReg(False));
  inPortVL       <- replicateM(mkConfigReg(unpack(0)));

  // -- End of Initialization --
    
  // -- Allocation --
  // These structures get populated with the arbitration results
  // Used for faster handling of upstream credits
  Vector#(NumInPorts, Maybe#(OutPort_t))     activeVOQ_perIn  = replicate(Invalid);      // arbitration populates this
  Vector#(NumOutPorts, Maybe#(InPort_t))     activeIn_perOut = replicate(Invalid);
  
  //Vector#(NumOutPorts, VC_t)                 activeVC_perOut = replicate(0);            // This is only valid if activeIn_perOut is Valid - not Maybe type to avoid spending an extra bit
  //Vector#(NumOutPorts, Maybe#(VC_t))                 activeVC_perOut = replicate(Invalid);            // This is only valid if activeIn_perOut is Valid - not Maybe type to avoid spending an extra bit


  // Input to allocator
  Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) )  eligIO = unpack(0);  
  Vector#(NumInPorts, Vector#(NumOutPorts, Bool) )    flitVOQBuffers_notEmpty = unpack(0);
  //Vector#(NumInPorts, Vector#(NumVCs, OutPort_t) )    outPortFIFOs_first   = unpack(0);
  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    flitVOQBuffers_notEmpty[i] = flitVOQBuffers[i].notEmpty();
    /*for(Integer v=valueOf(NumVCs)-1; v>=0; v=v-1) begin  // lowest VC has highest priority
      outPortFIFOs_first[i][v] = outPortFIFOs[i][v].first();
    end*/
  end


  // Build eligIO and mark selected-active VC per Input (lowest VC has priority)
  // -- Option 1: cleaner, but less scalable -- is too slow when USE_VIRTUAL_LINKS is enabled
  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    //let not_empty = flitBuffers[i].notEmpty();
    if(`USE_VIRTUAL_LINKS) begin
      let not_empty = flitVOQBuffers_notEmpty[i];
      for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin // filter out Outputs with no credits
	let is_locked = lockedVL[o];
	if(not_empty[o] && simple_credits[o]) begin // not empty and has credits 
	  if( !is_locked || (is_locked && inPortVL[o] == fromInteger(i) ) ) begin
	    eligIO[i] = replicate(False);
	    eligIO[i][o] = True;
	  end
	end else begin // is empty or doesn't have credits
	  eligIO[i][o] = False;
	end
      end
    end else begin
      eligIO[i] = flitVOQBuffers_notEmpty[i];
      for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin // filter out Outputs with no credits
	if(!simple_credits[o]) begin
	  eligIO[i][o] = False;
	end
      end
    end
  end
  // -- End Option 1 -- 

  // Perform allocation
  Vector#(NumInPorts, Bool) activeInPorts = unpack(0);
  //Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) )  selectedIO = routerAlloc.allocate(eligIO);
  Vector#(NumInPorts, Vector#(NumOutPorts, Wire#(Bool) ) )  selectedIO_s0; //= routerAlloc.allocate(eligIO);
  Vector#(NumInPorts, Vector#(NumOutPorts, Reg#(Bool) ) )  selectedIO_reg;
  Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) )  selectedIO; // this is popuated depending on allocator pipeline options

  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    selectedIO_reg[i] <- replicateM(mkConfigReg(False));
    selectedIO_s0[i] <- replicateM(mkDWire(False));
  end

  if(`PIPELINE_CORE) begin
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      selectedIO[i] = readVReg(selectedIO_reg[i]);
    end
  end else begin
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      selectedIO[i] = readVReg(selectedIO_s0[i]);
    end
  end

  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    Maybe#(OutPort_t) selectedOut = outport_encoder(selectedIO[i]);
    if (isValid(selectedOut)) begin
      if (getPipeLineStages() == 0) begin // no pipelining
	activeInPorts[i] = True;
	activeVOQ_perIn[i] = selectedOut;
	//InPort_t inp = fromInteger(i);
	//activeIn_perOut[selectedOut.Valid] = tagged Valid inp;
	activeIn_perOut[selectedOut.Valid] = tagged Valid fromInteger(i);

      end else begin             // pipelining, perform extra checks, because scheduler might had used stale info

	let not_empty   = flitVOQBuffers[i].notEmpty(); // double check that there is a flit
	let has_flits   = not_empty[selectedOut.Valid];
	let has_credits = simple_credits[selectedOut.Valid]; // double check that credits still exist. Alternatively change margin in mkMultiFIFOMem
	if (has_flits && has_credits) begin
	  activeInPorts[i] = True;
	  activeVOQ_perIn[i] = selectedOut;
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
      end
    end
  endrule

  rule gatherFlitsToSend(True);
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      if(activeInPorts[i]) begin
	let fl <- flitVOQBuffers[i].deq(activeVOQ_perIn[i].Valid);
	hasFlitsToSend_perIn[i] <= tagged Valid fl;
        end
    end
  endrule


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
    end
    for(Integer o=0; o < valueOf(NumOutPorts); o=o+1) begin
      for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
        `DBG_DETAIL_ID(("Cycle:%0d, credits[Out:%0d][VC:%0d] :%d", cycles, o, v, credits[o][v]));
      end
      if(isValid(activeIn_perOut[o])) begin  // I have a flit to send
	let active_in = activeIn_perOut[o].Valid;
      end    
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

  function isTrue(Bool x); return x; endfunction

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
	    flitVOQBuffers[i].enq(out_port, fl_in);
	    //outPortFIFOs[i][fl_in.vc].enq(out_port);
	    //$display(" ---> Router: %0d - enqueing to outPortFIFOs[%0d][%0d]", id, i, fl_in.vc);
	    //`DBG(("Marking incoming flit for dst:%0d VC:%0d from in:%0d (isT:%0d)", fl_in.dst, fl_in.vc, i, /*fl_in.is_head,*/ fl_in.is_tail));
	    //hasFlitsVIO_set[fl_in.vc][i][out_port] <= True;
	  end 
	endmethod

	// send credits upstream
        method ActionValue#(Vector#(NumVCs, Bool)) getNonFullVCs;
	  Vector#(NumVCs, Bool) ret = unpack(0);
	  let all_not_fulls = all(isTrue, flitVOQBuffers[i].notFull() );   // AND all not fulls
	  //return all_not_fulls;
	  if(all_not_fulls) begin
	    ret = unpack(1);
	  end
	  return ret;
	  //let not_fulls = flitVOQBuffers[i].notFull(); 
	  //let all_not_fulls = fold(\& , not_fulls);   // AND all not fulls
	  //let all_not_fulls = fold(\&, flitVOQBuffers[i].notFull());   // AND all not fulls
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
	      if(!isValid(activeIn_perOut[o])) begin
		`DBG_ID(("active_in is invalid!"));
	      end
	      flitOut = hasFlitsToSend_perIn[active_in];
	      dynamicAssert(isValid(flitOut), "Allocation selected input port with invalid flit!");

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

	    end

	    return flitOut;
	  endmethod

          // receive credits from downstream routers
          method Action putNonFullVCs(Vector#(NumVCs, Bool) nonFullVCs);
	    //`DBG_DETAIL_ID(("Receiving Credit on out_port %0d", o)); 
	    simple_credits[o] <= nonFullVCs[0];
	  endmethod
      endinterface;
    outPort_ifaces[o] = ifc;
  end

  interface in_ports = inPort_ifaces;
  interface out_ports = outPort_ifaces;
  
endmodule

////////////////////////////////////////////////
// Router Module implementation 
////////////////////////////////////////////////
module mkVOQRouterSimple#(Integer id)(RouterSimple);
  String name = "VOQRouter";
  Bit#(8) errorCode = 0;

  Vector#(NumInPorts, InPortSimple)   inPort_ifaces;                     // in port interfaces
`ifdef EN_DBG
  RouterCoreSimple router_core <- mkVOQRouterCoreSimple(id);
`else
  RouterCoreSimple router_core <- mkVOQRouterCoreSimple();
`endif
  // Route Table
  String route_table_file = strConcat( strConcat(`NETWORK_ROUTING_FILE_PREFIX, integerToString(id)), ".hex");
  //String route_table_file = strConcat( strConcat(`NETWORK_ROUTING_FILE_PREFIX, integerToString(0)), ".hex");
  //RF_16portsLoad#(RouterID_t, OutPort_t)                                      routeTable     <- mkRF_16portsLoad(route_table_file, /*binary*/False);
  //RouteTable                                      routeTable     <- mkRouteTable(route_table_file, /*binary*/False);
  RouteTable                                      routeTable     <- mkRouteTable(route_table_file);

  // for debugging
  `ifdef EN_DBG
    Reg#(Cycle_t)         cycles             <- mkConfigReg(0);
  `endif

  `ifdef EN_DBG
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
	    `DBG_ID_CYCLES(("Incoming flit on port %0d - dest:%0d, data:%x", i, fl_in.dst, fl_in.data ));
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

  // Implement RouterInfo interface
  /*let rt_info_ifc =
    interface RouterInfo
      method RouterID_t getRouterID;
	return fromInteger(id);
      endmethod
    endinterface;*/
 
  interface in_ports = inPort_ifaces;
  interface out_ports = router_core.out_ports;
  //interface rt_info = rt_info_ifc;
   
endmodule


module mkVOQRouterSynth(RouterSimple);
  let rt_synth <- mkVOQRouterSimple(4);
  return rt_synth;
endmodule



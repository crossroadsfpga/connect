/* =========================================================================
 *
 * Filename:            Router.bsv
 * Date created:        04-23-2011
 * Last modified:       06-02-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Parameterized Router module. Used as building block for building larger 
 * networks.
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

typedef MultiFIFOMem#(Flit_t, NumVCs, FlitBufferDepth) InputVCQueues;
(* synthesize *)
module mkInputVCQueues(InputVCQueues);
  InputVCQueues inputVCQueues_ifc <- mkMultiFIFOMem(False /*storeHeadsTailsInLUTRAM*/, 0 /* full_margin */ );
  return inputVCQueues_ifc;
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
module mkRouter#(Integer id)(Router);
  String name = "Router";
  Bit#(8) errorCode = 0;

  Vector#(NumInPorts, InPort)   inPort_ifaces;                     // in port interfaces
`ifdef EN_DBG
  RouterCore router_core <- mkRouterCore(id);
`else
  RouterCore router_core <- mkRouterCore();
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
    rule update_cycles(True);
      cycles <= cycles + 1;
    endrule
  `endif

  // Define input interfaces
  for(Integer i=0; i < valueOf(NumInPorts); i=i+1) begin
    let ifc =
      interface InPort
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
            //if(i==0) begin
	    //  //`DBG(("Cycle:%0d - Injected flit into router %0d - dest:%0d, tail:%0d, vc:%0d, data:%x", cycles, id, fl_in.dst, fl_in.is_tail, fl_in.vc, fl_in.data ));
	    //  `DBG_ID(("Cycle:%0d - Injected flit - dest:%0d, vc:%0d, data:%x", cycles, fl_in.dst, fl_in.vc, fl_in.data ));
	    //end else begin
	    //  //`DBG(("Cycle:%0d - Router %0d received flit through in_port %0d - dest:%0d, tail:%0d, vc:%0d, data:%x", cycles, id, i, fl_in.dst, fl_in.is_tail, fl_in.vc, fl_in.data ));
	    //  `DBG_ID(("Cycle:%0d - Received flit through in_port %0d - dest:%0d, vc:%0d, data:%x", cycles, i, fl_in.dst, fl_in.vc, fl_in.data ));
	    //end
	  end
	  router_core.in_ports[i].putRoutedFlit(rt_flit);
	endmethod

	// send credits upstream
	method ActionValue#(Credit_t) getCredits;
	  let cr_out <- router_core.in_ports[i].getCredits();
	  return cr_out;
	endmethod
      endinterface;

    inPort_ifaces[i] = ifc;
  end

  // Implement RouterInfo interface
  //let rt_info_ifc =
  //  interface RouterInfo
  //    method RouterID_t getRouterID;
  //      return fromInteger(id);
  //    endmethod
  //  endinterface;
 
  interface in_ports = inPort_ifaces;
  interface out_ports = router_core.out_ports;
  //interface rt_info = rt_info_ifc;
   
endmodule


module mkRouterSynth(Router);
  let rt_synth <- mkRouter(4);
  return rt_synth;
endmodule


//    //////////////////////////////////////////////////////////////////////////////////////
//    // noinline functions to speed up Bluespec compilation
//    // left-over code from old arbiter. not used anymore
//    (* noinline *)
//    function Tuple3#(
//    	           Vector#(NumOutPorts, Bool ),  /* eligIO_forIn */
//    		   Maybe#(VC_t),                 /* activeVC_perIn_forIn */
//    		   Vector#(NumOutPorts, VC_t)    /* activeVC_perOut */
//      ) build_eligIO_and_other_alloc_structs_perIn ( 
//                       Vector#(NumVCs, Bool)                                                          not_empty,
//    		   Vector#(NumVCs, OutPort_t)                                                     outPortFIFOs_first_forIn,
//    		   Vector#(NumOutPorts, Vector#(NumVCs, Bit#(TLog#(TAdd#(FlitBufferDepth,1)))))   credits,
//    		   Vector#(NumOutPorts, VC_t)   activeVC_perOut,
//                       // only used if Virtual Links are enabled
//                       Vector#(NumOutPorts, Vector#(NumVCs, Bool ))                             lockedVL,
//                       Vector#(NumOutPorts, Vector#(NumVCs, InPort_t))                          inPortVL,
//    		   InPort_t                                                                       cur_in
//      );
//    
//      Vector#(NumOutPorts, Bool ) eligIO_forIn = unpack(0);
//      Maybe#(VC_t) activeVC_perIn_forIn = unpack(0);
//      // Build eligIO and mark selected-active VC per Input (lowest VC has priority)
//      for(Integer v=valueOf(NumVCs)-1; v>=0; v=v-1) begin  // lowest VC has highest priority
//        if(not_empty[v]) begin
//          let out_port = outPortFIFOs_first_forIn[v];
//    
//          if(`USE_VIRTUAL_LINKS) begin
//    	if(credits[out_port][v] > 0) begin
//    	  let is_locked = lockedVL[out_port][v];
//    	  if( !is_locked || (is_locked && inPortVL[out_port][v] == cur_in ) )  begin
//    	    activeVC_perIn_forIn = tagged Valid fromInteger(v);
//    	    activeVC_perOut[out_port] = fromInteger(v);
//    	    eligIO_forIn[out_port] = True;
//    	  end
//    	end
//          end else begin
//    	if(credits[out_port][v] > 0) begin
//    	  activeVC_perIn_forIn = tagged Valid fromInteger(v);
//    	  activeVC_perOut[out_port] = fromInteger(v);
//    	  eligIO_forIn[out_port] = True;
//    	end
//          end
//    
//    
//    //      if(credits[out_port][v] > 0) begin
//    //	activeVC_perIn_forIn = tagged Valid fromInteger(v);
//    //	activeVC_perOut[out_port] = fromInteger(v);
//    //	eligIO_forIn[out_port] = True;
//    //      end
//        end
//      end
//    
//      return tuple3(eligIO_forIn, activeVC_perIn_forIn, activeVC_perOut);
//    endfunction
//    
//    (* noinline *)
//    function Tuple3#(
//    	           Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) ),  /* eligIO */
//    		   Vector#(NumInPorts, Maybe#(VC_t)),                  /* activeVC_perIn */
//    		   Vector#(NumOutPorts, VC_t)                          /* activeVC_perOut */
//      ) build_eligIO_and_other_alloc_structs ( 
//                       Vector#(NumInPorts, Vector#(NumVCs, Bool) )                                        flitBuffers_notEmpty,
//    		   Vector#(NumInPorts, Vector#(NumVCs, OutPort_t) )                                   outPortFIFOs_first,
//    		   Vector#(NumOutPorts, Vector#(NumVCs, Bit#(TLog#(TAdd#(FlitBufferDepth,1)))))       credits,
//                       // only used if Virtual Links are enabled
//                       Vector#(NumOutPorts, Vector#(NumVCs, Bool ))                             lockedVL,
//                       Vector#(NumOutPorts, Vector#(NumVCs, InPort_t))                          inPortVL
//      );
//    
//      Vector#(NumInPorts, Vector#(NumOutPorts, Bool ) )  eligIO          = unpack(0);  
//      Vector#(NumInPorts, Maybe#(VC_t))                  activeVC_perIn  = replicate(Invalid);      // arbitration populates this
//      Vector#(NumOutPorts, VC_t)                         activeVC_perOut = replicate(0);            // This is only valid if activeIn_perOut is Valid - not Maybe type to avoid spending an extra bit
//    
//      // Build eligIO and mark selected-active VC per Input (lowest VC has priority)
//      for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
//        let not_empty = flitBuffers_notEmpty[i];
//        let build_eligIO_and_other_alloc_structs_perIn_result = build_eligIO_and_other_alloc_structs_perIn(not_empty, outPortFIFOs_first[i], credits, activeVC_perOut, lockedVL, inPortVL, fromInteger(i));
//        eligIO[i]         = tpl_1(build_eligIO_and_other_alloc_structs_perIn_result);
//        activeVC_perIn[i] = tpl_2(build_eligIO_and_other_alloc_structs_perIn_result);
//        activeVC_perOut   = tpl_3(build_eligIO_and_other_alloc_structs_perIn_result);
//    
//    //    for(Integer v=valueOf(NumVCs)-1; v>=0; v=v-1) begin  // lowest VC has highest priority
//    //      if(not_empty[v]) begin
//    //	let out_port = outPortFIFOs_first[i][v];
//    //	if(credits[out_port][v] > 0) begin
//    //	  activeVC_perIn[i] = tagged Valid fromInteger(v);
//    //	  activeVC_perOut[out_port] = fromInteger(v);
//    //	  eligIO[i][out_port] = True;
//    //	end
//    //      end
//    //    end
//    
//      end
//    
//      return tuple3(eligIO, activeVC_perIn, activeVC_perOut);
//    endfunction

  
////////////////////////////////////////////////
// Router Module implementation 
////////////////////////////////////////////////
//module mkRouter#(RouterID_t id) (Router);
`ifdef EN_DBG
module mkRouterCore#(Integer id)(RouterCore);
`else
(* synthesize *)
module mkRouterCore(RouterCore);
`endif

  String name = "RouterCore";
  Bit#(8) errorCode = 0;
  
  // Vector of input and output port interfaces
  Vector#(NumInPorts, RouterCoreInPort)                                       inPort_ifaces;                     // in port interfaces
  Vector#(NumOutPorts, OutPort)                                               outPort_ifaces;                    // out port interfaces

  // Router Allocator
  RouterAllocator                                                             routerAlloc    <- mkSepRouterAllocator(`PIPELINE_ALLOCATOR /*pipeline*/);

  // Router State
  Vector#(NumInPorts, InputVCQueues)                                          flitBuffers <- replicateM(mkInputVCQueues());
  //Vector#(NumInPorts, RF_16ports#(VC_t, FlitBuffer_t) )                       flitBuffers    <- replicateM(mkRF_16ports());
  Vector#(NumInPorts, Vector#(NumVCs, OutPortFIFO))                           outPortFIFOs;
  Vector#(NumOutPorts, Vector#(NumVCs, Reg#(Bit#(TLog#(TAdd#(FlitBufferDepth,1))))))      credits;
  //Vector#(NumOutPorts, Vector#(NumVCs, Reg#(Bool) ))                          credits;

  Vector#(NumInPorts, Wire#(Maybe#(Flit_t)))                                  hasFlitsToSend_perIn <- replicateM(mkDWire(Invalid));
  Vector#(NumInPorts, Wire#(Maybe#(Flit_t)))                                  flitsToSend_perIn    <- replicateM(mkDWire(Invalid));
  // Used for multi-flit packets that use virtual links
  //if(`USE_VIRTUAL_LINKS) begin
    Vector#(NumOutPorts, Vector#(NumVCs, Reg#(Bool) ))                          lockedVL;     // locked virtual link
    Vector#(NumOutPorts, Vector#(NumVCs, Reg#(InPort_t)))                       inPortVL;     // holds current input for locked virtual channels
  //end

  // Update wires
  Vector#(NumOutPorts, Vector#(NumVCs, Wire#(Bool) ))                         credits_set;   // to handle incoming credits
  Vector#(NumOutPorts, Vector#(NumVCs, Wire#(Bool) ))                         credits_clear; // to clear credits due to outgoing flits

  // for debugging
  `ifdef EN_DBG
    Reg#(Cycle_t)         cycles             <- mkConfigReg(0);
    rule update_cycles(True);
      cycles <= cycles + 1;
    endrule
  `endif


  // -- Initialization --
  for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin
    //credits[o]        <- replicateM(mkConfigReg(True));   // start with credits for all ouputs/VCs
    credits[o]        <- replicateM(mkConfigReg(fromInteger(valueOf(FlitBufferDepth))));   // start with credits for all ouputs/VCs
    credits_set[o]    <- replicateM(mkDWire(False));
    credits_clear[o]  <- replicateM(mkDWire(False));
    lockedVL[o]       <- replicateM(mkConfigReg(False));
    inPortVL[o]       <- replicateM(mkConfigReg(unpack(0)));
  end

  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    outPortFIFOs[i] <- replicateM(mkOutPortFIFO());
  end
  // -- End of Initialization --
    
  // -- Allocation --
  // These structures get populated with the arbitration results
  // Used for faster handling of upstream credits
  //Vector#(NumInPorts, Maybe#(VC_t))          activeVC_perIn  = replicate(Invalid);      // arbitration populates this
  //Vector#(NumInPorts, Wire#(Maybe#(VC_t)))     activeIn_perIn_s0; // = replicate(Invalid);
  Vector#(NumInPorts, Maybe#(VC_t))         activeVC_perIn_s0 = replicate(Invalid);
  Vector#(NumInPorts, Reg#(Maybe#(VC_t)))   activeVC_perIn_reg <- replicateM(mkConfigReg(Invalid));
  Vector#(NumInPorts, Maybe#(VC_t))         activeVC_perIn;      // this is popuated depending on allocator pipeline options
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

  Vector#(NumInPorts, Vector#(NumVCs, Bool) )         flitBuffers_notEmpty = unpack(0);
  Vector#(NumInPorts, Vector#(NumVCs, OutPort_t) )    outPortFIFOs_first   = unpack(0);
  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    flitBuffers_notEmpty[i] = flitBuffers[i].notEmpty();
    for(Integer v=valueOf(NumVCs)-1; v>=0; v=v-1) begin  // lowest VC has highest priority
      outPortFIFOs_first[i][v] = outPortFIFOs[i][v].first();
    end
  end

  Vector#(NumOutPorts, Vector#(NumVCs, Bit#(TLog#(TAdd#(FlitBufferDepth,1)))))      credit_values;  
  Vector#(NumOutPorts, Vector#(NumVCs, Bool ))                          lockedVL_values;     // locked virtual link
  Vector#(NumOutPorts, Vector#(NumVCs, InPort_t))                       inPortVL_values;     // holds current input for locked virtual channels
  for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin
    credit_values[o] = readVReg(credits[o]);
    lockedVL_values[o] = readVReg(lockedVL[o]);
    inPortVL_values[o] = readVReg(inPortVL[o]);
  end


  // Build eligIO and mark selected-active VC per Input (lowest VC has priority)
  // -- Option 1: cleaner, but less scalable -- is too slow when USE_VIRTUAL_LINKS is enabled
  for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
    //let not_empty = flitBuffers[i].notEmpty();
    let not_empty = flitBuffers_notEmpty[i];
    for(Integer v=valueOf(NumVCs)-1; v>=0; v=v-1) begin  // lowest VC has highest priority
      if(not_empty[v]) begin
	//let out_port = outPortFIFOs[i][v].first();
	let out_port = outPortFIFOs_first[i][v];

        if(`USE_VIRTUAL_LINKS) begin
	  if(credits[out_port][v] > 0) begin
	    let is_locked = lockedVL[out_port][v];
	    if( !is_locked || (is_locked && inPortVL[out_port][v] == fromInteger(i) ) )  begin
	      activeVC_perIn_s0[i] = tagged Valid fromInteger(v);
	      //activeVC_perOut[out_port] = tagged Valid fromInteger(v);
	      //eligIO[i] = unpack(0);
	      eligIO[i] = replicate(False);
	      eligIO[i][out_port] = True;
	    end
	  end
	end else begin
	  if(credits[out_port][v] > 0) begin
	    activeVC_perIn_s0[i] = tagged Valid fromInteger(v);
	    //activeVC_perOut[out_port] = tagged Valid fromInteger(v);
	    eligIO[i] = replicate(False);
	    eligIO[i][out_port] = True;
	  end
        end

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
      activeVC_perIn[i] = activeVC_perIn_reg[i];
    end
  end else begin
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      selectedIO[i]     = readVReg(selectedIO_s0[i]);
      activeVC_perIn[i] = activeVC_perIn_s0[i];
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

	if(isValid(activeVC_perIn[i])) begin  // VC might be wrong, so double check
          let selVC = activeVC_perIn[i].Valid;           
	  let not_empty = flitBuffers[i].notEmpty(); // double check that there is a flit
	  let has_flits    = not_empty[selVC];
	  let has_credits = credits[selectedOut.Valid][selVC] > 0; // double check that credits still exist. Alternatively change margin in mkMultiFIFOMem
	  if (has_flits && has_credits) begin
	    activeInPorts[i] = True;
	    //InPort_t inp = fromInteger(i);
	    //activeIn_perOut[selectedOut.Valid] = tagged Valid inp;
	    activeIn_perOut[selectedOut.Valid] = tagged Valid fromInteger(i);
	  end
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
	activeVC_perIn_reg[i] <= activeVC_perIn_s0[i];
      end
    end
  endrule

  rule gatherFlitsToSend(True);
    for(Integer i=0; i<valueOf(NumInPorts);i=i+1) begin
      if(activeInPorts[i]) begin
	let fl <- flitBuffers[i].deq(activeVC_perIn[i].Valid);
	if(fl.vc != activeVC_perIn[i].Valid) begin
       	   `DBG_ID_CYCLES(("Selected VC %d does not match flit VC %d for input %d", activeVC_perIn[i].Valid, fl.vc, i));
	end 
	hasFlitsToSend_perIn[i] <= tagged Valid fl;
	//let out_port = outPortFIFOs_first[i][activeVC_perIn[i].Valid];
        outPortFIFOs[i][activeVC_perIn[i].Valid].deq();
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
  (* fire_when_enabled *)
  rule update_credits (True);   // turn off credits for debugging
    for(Integer o=0; o<valueOf(NumOutPorts); o=o+1) begin
      for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
	if ( credits_set[o][v] && !credits_clear[o][v] ) begin   // I only received a credit
	  //credits[o][v] <= True;
	  credits[o][v] <= credits[o][v] + 1;
	  if(credits[o][v]+1 > fromInteger(valueof(FlitBufferDepth))) begin
	    `DBG_ID_CYCLES(("Credit overflow at out_port %0d VC %0d", o, v));
	  end
	end else if (!credits_set[o][v] && credits_clear[o][v]) begin   // I only spent a credit
	  //credits[o][v] <= False;
	  credits[o][v] <= credits[o][v] - 1;
	  if(credits[o][v] == 0) begin
	    `DBG_ID_CYCLES(("Credit underflow at out_port %0d VC %0d", o, v));
	  end
	end
      end
    end
    //`DBG_DETAIL_ID(("credits:%b", readVReg(concat(credits)) ));  // flatten the array to print
  endrule


/*  rule tmp (True);
    for(Integer o=0; o < valueOf(NumOutPorts); o=o+1) begin
      for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
        `DBG_ID(("Cycle:%0d, credits[Out:%0d][VC:%0d] :%d", cycles, o, v, credits[o][v]));
      end
    end
  endrule*/


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
      for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
	`DBG_ID(("outPortFIFOs[%d][%d]: %d", i, v , outPortFIFOs[i][v].first()));
      end
    end
    for(Integer o=0; o < valueOf(NumOutPorts); o=o+1) begin
      for(Integer v=0; v<valueOf(NumVCs); v=v+1) begin
        `DBG_DETAIL_ID(("Cycle:%0d, credits[Out:%0d][VC:%0d] :%d", cycles, o, v, credits[o][v]));
      end
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
      interface RouterCoreInPort
	method Action putRoutedFlit(Maybe#(RoutedFlit_t) flit_in);
	  //`DBG(("Receiving Flit on in_port %0d", i));
	  if(isValid(flit_in)) begin
	    let fl_in = flit_in.Valid.flit;
	    let out_port = flit_in.Valid.out_port;
	    //let out_port = routeTable.read_ports[i].read(fl_in.dst);
	    //flitBuffers[i].write(fl_in.vc, FlitBuffer_t{is_tail:fl_in.is_tail, data:fl_in.data, dst:fl_in.dst});
	    flitBuffers[i].enq(fl_in.vc, fl_in);
	    outPortFIFOs[i][fl_in.vc].enq(out_port);
	    //$display(" ---> Router: %0d - enqueing to outPortFIFOs[%0d][%0d]", id, i, fl_in.vc);
	    if(i==0) begin
	      //`DBG(("Cycle:%0d - Injected flit into router %0d - dest:%0d, tail:%0d, vc:%0d, data:%x", cycles, id, fl_in.dst, fl_in.is_tail, fl_in.vc, fl_in.data ));
	      //`DBG(("Cycle:%0d - Injected flit - dest:%0d, vc:%0d, data:%x", cycles, fl_in.dst, fl_in.vc, fl_in.data ));
	    end else begin
	      //`DBG(("Cycle:%0d - Router %0d received flit through in_port %0d - dest:%0d, tail:%0d, vc:%0d, data:%x", cycles, id, i, fl_in.dst, fl_in.is_tail, fl_in.vc, fl_in.data ));
	      //`DBG(("Cycle:%0d - Received flit through in_port %0d - dest:%0d, vc:%0d, data:%x", cycles, i, fl_in.dst, fl_in.vc, fl_in.data ));
	    end
	    //`DBG(("Marking incoming flit for dst:%0d VC:%0d from in:%0d (isT:%0d)", fl_in.dst, fl_in.vc, i, /*fl_in.is_head,*/ fl_in.is_tail));
	    //hasFlitsVIO_set[fl_in.vc][i][out_port] <= True;
	  end 
	endmethod

	// send credits upstream
	method ActionValue#(Credit_t) getCredits;
	  Credit_t cr_out = Invalid;
	  if (activeInPorts[i]) begin
	    cr_out = activeVC_perIn[i];
	  end
	  return cr_out;
	endmethod
      endinterface;

    inPort_ifaces[i] = ifc;
  end

  // Implement output interfaces
  for(Integer o=0; o < valueOf(NumOutPorts); o=o+1) begin
    let ifc =
      interface OutPort
	  method ActionValue#(Maybe#(Flit_t)) getFlit();
	    Maybe#(Flit_t) flitOut = Invalid;
	    if( isValid(activeIn_perOut[o]) ) begin  // I have a flit to send
	      let active_in  = activeIn_perOut[o].Valid;
	      //let active_vc  = activeVC_perOut[o].Valid;
	      if(!isValid(activeIn_perOut[o])) begin
		`DBG_ID_CYCLES(("active_in is invalid!"));
	      end
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
              let active_vc = flitOut.Valid.vc;
	      //dynamicAssert(flitOut.Valid.vc == active_vc, "Flit VC and active VC do not match!");
	      if(flitOut.Valid.vc != active_vc) begin
		 `DBG_ID_CYCLES(("Flit VC %d does not match active VC %d for output %d", flitOut.Valid.vc, active_vc, o));
	      end 

	      //if(flitOut.Valid.out_p != fromInteger(o)) begin
	      //   `DBG_ID(("Flit out_port %d does not match actual out_port %d", flitOut.Valid.out_p, o));
	      //end 

	      dynamicAssert(isValid(flitOut), "Allocation selected input port with invalid flit!");
              if(`USE_VIRTUAL_LINKS) begin
		if(flitOut.Valid.is_tail) begin // If you see a tail unlock VL  (also covers head/tail case)
		  lockedVL[o][active_vc] <= False;
		  `DBG_DETAIL_ID(("UNLOCKED output %0d (was locked to in:%0d)", o, inPortVL[o][active_vc] ));
		end else begin // it's not a tail (i.e. head or in the middle of a packet), so lock the VL.
		  lockedVL[o][active_vc] <= True;
		  `DBG_DETAIL_ID(("LOCKED output %0d locked to in:%0d, VC:%0d", o, active_in, active_vc ));
		  inPortVL[o][active_vc] <= active_in;
		end
	      end
	      // clear credits
	      credits_clear[o][active_vc] <= True;

	    end

	    return flitOut;
	  endmethod

	  // receive credits from downstream routers
	  method Action putCredits(Credit_t cr_in);
	    `DBG_DETAIL_ID(("Receiving Credit on out_port %0d", o));
	    // only mark here - perform update in rule
	    if(isValid(cr_in)) begin
	      //`DBG_DETAIL_ID(("Cycle: %0d: Received credit on out_port %0d for vc %0d", cycles, o, cr_in.Valid));
	      `DBG_DETAIL(("Cycle: %0d: Received credit on out_port %0d for vc %0d", cycles, o, cr_in.Valid));
	       credits_set[o][cr_in.Valid] <= True;
	    end
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


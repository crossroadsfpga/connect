/* =========================================================================
 * 
 * Filename:            inc.v
 * Date created:        03-18-2011
 * Last modified:       04-05-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Generic include file for all modules
 * 
 * =========================================================================
 */

/////////////////////////////////////////////////////////////////////////
// Set default configuration files. Override these in makefile.
//`define NETWORK_PARAMETERS_FILE "test_parameters.bsv"
`ifndef NETWORK_PARAMETERS_FILE
  `define NETWORK_PARAMETERS_FILE "sample_mesh_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_4RTs_2VCs_4BD_128DW_2RTsPerRow_2RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "ring_4RTs_2VCs_4BD_128DW_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_9RTs_2VCs_4BD_128DW_3RTsPerRow_3RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_9RTs_2VCs_4BD_128DW_SepOfStaticAlloc_3RTsPerRow_3RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_9RTs_2VCs_4BD_128DW_SepOFStaticAlloc_3RTsPerRow_3RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_9RTs_2VCs_8BD_32DW_SepIFRoundRobinAlloc_3RTsPerRow_3RTsPerCol_parameters.bsv" 
  //`define NETWORK_PARAMETERS_FILE "test_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "double_ring_32RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_16RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_16RTs_4VCs_8BD_64DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_16RTs_4VCs_8BD_128DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "fully_connected_8RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_16RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "ring_64RTs_4VCs_4BD_128DW_SepOFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "torus_16RTs_2VCs_16BD_64DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "fat_tree_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "double_ring_16RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "fully_connected_16RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "fully_connected_10RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_16RTs_8VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "mesh_16RTs_2VCs_8BD_32DW_SepIFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "high_radix_special_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "uni_tree_4INs_64OUTs_8FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "uni_tree_4INs_64OUTs_8FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "uni_tree_4INs_16OUTs_4FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_parameters.bsv"
  //`define NETWORK_PARAMETERS_FILE "uni_tree_4INs_64OUTs_8FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_parameters.bsv"
`endif
`ifndef NETWORK_LINKS_FILE
  `define NETWORK_LINKS_FILE "sample_mesh_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_9RTs_2VCs_4BD_128DW_SepOfStaticAlloc_3RTsPerRow_3RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_16RTs_2VCs_8BD_64DW_SepOfStaticAllocAlloc_4RTsPerRow_4RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_9RTs_2VCs_8BD_32DW_SepIFRoundRobinAlloc_3RTsPerRow_3RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "double_ring_32RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_16RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_16RTs_4VCs_8BD_64DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_16RTs_4VCs_8BD_128DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "fully_connected_8RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_16RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "ring_64RTs_4VCs_4BD_128DW_SepOFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "torus_16RTs_2VCs_16BD_64DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "fat_tree_links.bsv"
  //`define NETWORK_LINKS_FILE "double_ring_16RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "fully_connected_16RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "fully_connected_10RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_16RTs_8VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "mesh_16RTs_2VCs_8BD_32DW_SepIFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_links.bsv"
  //`define NETWORK_LINKS_FILE "high_radix_special_links.bsv"
  //`define NETWORK_LINKS_FILE "uni_tree_4INs_16OUTs_4FANOUT_2VCs_4BD_128DW_SepIFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "uni_tree_4INs_64OUTs_8FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "uni_tree_4INs_16OUTs_4FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_links.bsv"
  //`define NETWORK_LINKS_FILE "uni_tree_4INs_64OUTs_8FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_links.bsv"

`endif
`ifndef NETWORK_ROUTING_FILE_PREFIX
  `define NETWORK_ROUTING_FILE_PREFIX "sample_mesh_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_4RTs_2VCs_4BD_128DW_2RTsPerRow_2RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "ring_4RTs_2VCs_4BD_128DW_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_16RTs_2VCs_8BD_64DW_SepOfStaticAllocAlloc_4RTsPerRow_4RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_9RTs_2VCs_4BD_128DW_3RTsPerRow_3RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_9RTs_2VCs_8BD_32DW_SepIFRoundRobinAlloc_3RTsPerRow_3RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_64RTs_2VCs_1BD_256DW_SepIFRoundRobinAlloc_8RTsPerRow_8RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "double_ring_32RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_16RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_16RTs_4VCs_8BD_64DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_16RTs_4VCs_8BD_128DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "fully_connected_8RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_16RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "ring_64RTs_4VCs_4BD_128DW_SepOFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "torus_16RTs_2VCs_16BD_64DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "fat_tree_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "double_ring_16RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "fully_connected_16RTs_2VCs_8BD_32DW_SepOFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "fully_connected_10RTs_4VCs_8BD_32DW_SepOFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_16RTs_8VCs_8BD_32DW_SepOFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "mesh_16RTs_2VCs_8BD_32DW_SepIFRoundRobinAlloc_4RTsPerRow_4RTsPerCol_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "high_radix_special_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "uni_tree_4INs_16OUTs_4FANOUT_2VCs_4BD_128DW_SepIFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "uni_tree_4INs_64OUTs_8FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "uni_tree_4INs_16OUTs_4FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_routing_"
  //`define NETWORK_ROUTING_FILE_PREFIX "uni_tree_4INs_64OUTs_8FANOUT_1VCs_4BD_128DW_SepIFRoundRobinAlloc_routing_"
`endif

`include `NETWORK_PARAMETERS_FILE

// Set default parameters
`ifndef NUM_ROUTERS
  `define NUM_ROUTERS 16
`endif
`ifndef NUM_IN_PORTS
  `define NUM_IN_PORTS 5
`endif
`ifndef NUM_OUT_PORTS
  `define NUM_OUT_PORTS 5
`endif
`ifndef CREDIT_DELAY
  `define CREDIT_DELAY 1
`endif
`ifndef NUM_VCS
  `define NUM_VCS 2
`endif
`ifndef FLIT_BUFFER_DEPTH 8
  `define FLIT_BUFFER_DEPTH 8
`endif
`ifndef FLIT_DATA_WIDTH
  `define FLIT_DATA_WIDTH 32
`endif
`ifndef NUM_LINKS
  `define NUM_LINKS 48
`endif
`ifndef IDEAL_NETWORK_CUT
  `define IDEAL_NETWORK_CUT 0
`endif
`ifndef ALLOC_TYPE
  `define ALLOC_TYPE SepOFRoundRobin
`endif
`ifndef USE_VIRTUAL_LINKS
  `define USE_VIRTUAL_LINKS False
`endif
`ifndef DUMP_LINK_UTIL
  `define DUMP_LINK_UTIL True
`endif
`ifndef PIPELINE_ALLOCATOR
  `define PIPELINE_ALLOCATOR False
`endif
`ifndef PIPELINE_CORE
  `define PIPELINE_CORE False
`endif
`ifndef PIPELINE_LINKS
  `define PIPELINE_LINKS False
`endif

//`define USE_VOQ_ROUTER True
//`define USE_IQ_ROUTER True

//`ifndef RESTRICT_UTURNS
//  `define RESTRICT_UTURNS False
//`endif

// Enables debugging messages
//`define EN_DBG True        // comment this out to disable common debugging messages

// Enables more detailed debugging messages
//`define EN_DBG_DETAIL True        // comment this out to disable common debugging messages

// If enabled will produce messages that match software reference design.
// Make sure this is commented out when synthesizing design.
//`define EN_DBG_REF True    // controls if debugging messages that compare to reference design are printed

// Colors
`define NO_COLORS 1
`ifdef NO_COLORS
  `define WHITE $write("")
  `define RED $write("")
  `define BLUE $write("")
  `define BROWN $write("")
  `define GREEN $write("")
`else 
  `define WHITE $write("%c[0m",27)
  //`define WHITE_INL [0m
  `define RED $write("%c[1;31m",27)
  `define BLUE $write("%c[1;34m",27)
  `define BROWN $write("%c[4;33m",27)
  `define GREEN $write("%c[1;32m",27)
`endif

// Debugging stuff
`ifdef EN_DBG 
  //`define EN_DBG_RULE True
  // Note: Do not use parentheses inside DBG messages. They cause conflicts with the macro definition
  //`define DBG(_str) $write("%c[1;31m[ %15s ] %c[0m",27,name,27);$display _str 
  `define DBG(_str) `RED;$write("%s",name);`WHITE;$write(" : ");$display _str 
  //`define DBG_ID(_str) $write("%c[1;31m[ %d:",27,id); $write(name," ] %c[0m",27);$display _str
  `define DBG_ID(_str) `RED;$write("%s",name);`BLUE;$write("(%0d)",id);`WHITE;$write(" : ");$display _str 
  //`define DBG_CYCLES(_str) $write("%c[1;31m[ %15s ] %c[1;34m@ %4d %c[0m:",27,name,27,cycles,27);$display _str 
  `define DBG_CYCLES(_str) `RED;$write("%s",name);`GREEN;$write(" @ %04d", cycles);`WHITE;$write(" : ");$display _str 
  //`define DBG_ID_CYCLES(_str) $write("%c[1;31m[ %d:",27,id);$write(name," ] %c[0m",27);$write("%c[1;34m @ %d ",27,cycles);$write("%c[0m :",27);$display _str
  `define DBG_ID_CYCLES(_str) `RED;$write("%s",name);`BLUE;$write("(%0d)",id);`GREEN;$write(" @ %04d", cycles);`WHITE;$write(" : ");$display _str 
  `define DBG_NONAME(_str) $display _str
`else
  //`define EN_DBG_RULE False
  `define DBG(_str) $write("") 
  `define DBG_ID(_str) $write("")
  `define DBG_CYCLES(_str) $write("")
  `define DBG_ID_CYCLES(_str) $write("")
  `define DBG_NONAME(_str) $write("")
`endif

`ifdef EN_DBG_DETAIL
  `define EN_DBG_RULE True
  // Note: Do not use parentheses inside DBG_DETAIL messages. They cause conflicts with the macro definition
  //`define DBG_DETAIL(_str) $write("%c[1;31m[ %15s ] %c[0m",27,name,27); $display _str 
  `define DBG_DETAIL(_str) `RED;$write("%20s",name);`WHITE;$write(" : ");$display _str 
  //`define DBG_DETAIL_ID(_str) $write("%c[1;31m[ %d:",27,id); $write(name," ] %c[0m",27);$display _str
  `define DBG_DETAIL_ID(_str) `RED;$write("%20s(%d)",name,id);`WHITE;$write(" : ");$display _str 
`else
  `define EN_DBG_RULE False
  `define DBG_DETAIL(_str) $write("") 
  `define DBG_DETAIL_ID(_str) $write("")
`endif

`ifdef EN_DBG_REF
  // used to print out messags that match reference design
  `define DBG_REF(_str) $display _str 
`else
  `define DBG_REF(_str) $write("") 
`endif

// Fancy display versions
`define DISP(_str) `RED;$write("%s",name);`WHITE;$write(" : ");$display _str 
`define DISP_ID(_str) `RED;$write("%s",name);`BLUE;$write("(%0d)",id);`WHITE;$write(" : ");$display _str 
`define DISP_CYCLES(_str) `RED;$write("%s",name);`GREEN;$write(" @ %04d", cycles);`WHITE;$write(" : ");$display _str 
`define DISP_ID_CYCLES(_str) `RED;$write("%s",name);`BLUE;$write("(%0d)",id);`GREEN;$write(" @ %04d", cycles);`WHITE;$write(" : ");$display _str 
`define DISP_NONAME(_str) $display _str

//`ifndef BLA
//`define BLA
//function Action dbg_cycles(Fmt msg);
//  action
//  let tmp = $format(msg);
//  `DISP_CYCLES((tmp));
//  endaction
//endfunction
//`endif

//////////////////// older stuff ///////////////////////////////
// -- Older debugging defines --
//`define EN_DBG True
//`define DBG $write("%c[1;31m[ %15s ] %c[0m",27,name,27)
//`define DBG_id $write("%c[1;31m[ %d:",27,id); $write(name," ] %c[0m",27)
//`define DBG if(!False) begin noAction; end else begin


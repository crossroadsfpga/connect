#!/usr/bin/env python
"""
SYNOPSIS
    %prog [-h,--help] [-v,--verbose] [--version]

DESCRIPTION
    This script generates configuration files that are used by the network rtl and represent different topologies and network configurations. 
    In particular these files are generated:
      - network_parameters.bsv : specifies network and router parameters. 
      - network_links.bsv      : specifies how routers are connected (i.e. topology) 
      - network_routing_X.hex  : specifies contents of router tables for router X (i.e. routing)

EXAMPLES
    %prog -t ring -n 4 -v 2 -d 8 -w 256

EXIT STATUS
    Exit codes

AUTHOR
    Michael K. Papamichael <papamix@cs.cmu.edu>

LICENSE
    Please contact the author for license information.

VERSION
    0.6"""

import sys, os, traceback, optparse
import math
import time
import re
import hashlib
#from pexpect import run, spawn


###############################################
## Opens and writes header to graphviz file
def prepare_graph_file(gv_filename, layout="invalid", custom_topology_info=None):
  """ Opens graphviz file, writes header and returns file pointer"""
  global options, args
  try: dot = open(gv_filename, 'w');
  except IOError: print "Could not open file " + gv_filename; sys.exit(-1);

  # Write header
  dot.write('digraph ' + options.topology + '_' + str(options.num_routers) + 'routers {\n');
  #dot.write('   layout = dot;\n');
  dot.write('   graph [outputorder=nodesfirst];\n')
  #dot.write('  graph [center rankdir=LR];\n');
  #dot.write('  node [shape = circle fixedsize="true" width="0.6!" height="0.6!"]\n');
  #dot.write('  node [shape = circle width="0.6" height="0.6"]\n');
  #dot.write('  node [shape = circle penwidth="4.0" fillcolor="#336699" style="filled" color="#002060"]\n');

  # Set node, edge and label styles
  dot.write('  node [shape=circle width="0.75!" height="0.75!" penwidth="3.0" color="#385D8A" fillcolor="#4F81BD" style="filled" fontname="Arial" fontcolor="#FFFFFF"]\n');
  dot.write('  edge [penwidth="2.0" color="#002060" fontname="Arial"]\n');
  endpoint_node_style = 'node [shape=Mrecord style="rounded" width="0.25!" height="0.25!" penwidth="2.0" color="#E55400" fillcolor="#FF5D00" style="filled" fontname="Arial" fontcolor="#FFFFFF"]\n';
  #dot.write('  node [shape=box width="0.25!" height="0.25!" penwidth="2.0" color="#E55400" fillcolor="#FF5D00" style="filled" fontname="Arial" fontcolor="#FFFFFF"]\n');
  #dot.write('  edge [penwidth="2.0" color="#002060" fontname="Arial" dir="both"]\n');
  #dot.write('  edge [penwidth="2.0" color="#002060" fontname="Arial" labelfontsize="18"]\n');
  #dot.write('  node [shape = circle penwidth="3.0" fillcolor="#99b2cc" style="filled" color="#1f497d" fontcolor="#FFFFFF"]\n');
  #dot.write('  node [shape = circle penwidth="3.0" fillcolor="#336699" style="filled" color="#002060" fontcolor="#FFFFFF"]\n');

  # For single switch topology only draw one router
  if (options.topology == "single_switch"):
    dot.write('node [label="R'+str(0)+'"] R'+str(0)+';\n');

    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);
      for r in range(options.num_routers):
	dot.write('node [label="N'+str(r)+'"] N'+str(r)+';\n');

  # For mesh and torus position nodes
  elif (options.topology == "mesh" or options.topology == "torus"): # arrange nodes in a grid
    rt_id = 0;
    for c in range(options.routers_per_column):
      for r in range(options.routers_per_row):
        dot.write('\nnode [label="R'+str(rt_id)+'" pos="'+str(r*1.5)+','+str(c*1.5)+'!"] R'+str(rt_id)+'\n');
        rt_id = rt_id+1
    dot.write('\n');
    
    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);
      rt_id = 0;
      for c in range(options.routers_per_column):
	for r in range(options.routers_per_row):
          dot.write('\nnode [label="N'+str(rt_id)+'" pos="'+str(r*1.5+0.75)+','+str(c*1.5+0.75)+'!"] N'+str(rt_id)+'\n');
          rt_id = rt_id+1

  # For star reduce number of endpoint nodes by one
  elif (options.topology == "star"): # arrange nodes in a tree
    for r in range(options.num_routers):
      dot.write('node [label="R'+str(r)+'"] R'+str(r)+';\n');
    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);
      for r in range(options.num_routers-1):
	dot.write('node [label="N'+str(r)+'"] N'+str(r)+';\n');

  # For Fat Tree position nodes
  elif (options.topology == "fat_tree"): # arrange nodes in a tree
    num_stages = int(math.log(options.num_routers, 2)) - 1  # counts router stages
    rts_in_stage = options.num_routers/2
    rt_id = 0;
    for stage in range(num_stages):
      if (stage < num_stages-1):  # not the top stage
        for sr in range(rts_in_stage):  # subrouter in particular stage
          dot.write('\nnode [label="R'+str(rt_id)+'" pos="'+str(sr*2)+','+str(stage*4)+'!"] R'+str(rt_id)+'\n');
          rt_id = rt_id+1
      else: # Last stage links
        #dot.write('  node [shape=square width="1!" height="1!" penwidth="3.0" color="#385D8A" fillcolor="#4F81BD" style="filled" fontname="Arial" fontcolor="#FFFFFF"]\n');
        for sr in range(rts_in_stage/2):  # subrouter in particular stage
          dot.write('\nnode [label="R'+str(rt_id)+'" pos="'+str(1+sr*4)+','+str(stage*4)+'!"] R'+str(rt_id)+'\n');
          rt_id = rt_id+1
    dot.write('\n');

    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);
      stage = 0; # bottom stage 
      for sr in range(rts_in_stage):  # subrouter in particular stage
        dot.write('\nnode [label="N'+str(sr*2)+'" pos="'+str(sr*2-0.5)+','+str(-2)+'!"] N'+str(sr*2)+'\n');
        dot.write('\nnode [label="N'+str(sr*2+1)+'" pos="'+str(sr*2+0.5)+','+str(-2)+'!"] N'+str(sr*2+1)+'\n');
	#dot.write('node [label="N'+str(r)+'"] N'+str(r)+';\n');

  # For Butterfly position nodes
  elif (options.topology == "butterfly"): # arrange nodes in left-to-right stages
    num_stages = int(math.log(options.num_routers, 2)) # counts router stages
    rts_in_stage = options.num_routers/2
    rt_id = 0;
    for stage in range(num_stages):
      for sr in range(rts_in_stage):  # subrouter in particular stage
        #dot.write('\nnode [label="R'+str(rt_id)+'" pos="'+str(sr*2)+','+str(stage*4)+'!"] R'+str(rt_id)+'\n');
        dot.write('\nnode [label="R'+str(rt_id)+'" pos="'+str(stage*4)+','+str(sr*2)+'!"] R'+str(rt_id)+'\n');
        rt_id = rt_id+1
    dot.write('\n');

    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);
      stage = 0; # bottom stage 
      for sr in range(rts_in_stage):  # subrouter in particular stage
	# left nodes
        #dot.write('\nnode [label="N'+str(sr*2)+'" pos="'+str(-2)+','+str(sr*2-0.5)+'!"] N'+str(sr*2)+'\n');
        #dot.write('\nnode [label="N'+str(sr*2+1)+'" pos="'+str(-2)+','+str(sr*2+0.5)+'!"] N'+str(sr*2+1)+'\n');
        dot.write('\nnode [label="N" pos="'+str(-2)+','+str(sr*2-0.5)+'!"] N'+str(sr*2+options.num_routers)+'\n');
        dot.write('\nnode [label="N" pos="'+str(-2)+','+str(sr*2+0.5)+'!"] N'+str(sr*2+1+options.num_routers)+'\n');
	# right nodes
	#dot.write('\nnode [label="N'+str(sr*2+options.num_routers)+'" pos="'+str(num_stages*4-2)+','+str(sr*2-0.5)+'!"] N'+str(sr*2+options.num_routers)+'\n');
        #dot.write('\nnode [label="N'+str(sr*2+1+options.num_routers)+'" pos="'+str(num_stages*4-2)+','+str(sr*2+0.5)+'!"] N'+str(sr*2+1+options.num_routers)+'\n');
	dot.write('\nnode [label="N'+str(sr*2)+'" pos="'+str(num_stages*4-2)+','+str(sr*2-0.5)+'!"] N'+str(sr*2)+'\n');
        dot.write('\nnode [label="N'+str(sr*2+1)+'" pos="'+str(num_stages*4-2)+','+str(sr*2+0.5)+'!"] N'+str(sr*2+1)+'\n');
	#dot.write('node [label="N'+str(r)+'"] N'+str(r)+';\n');

  # For Unidirectional single switch topology only draw one router
  elif (options.topology == "uni_single_switch"):
    dot.write('node [label="R'+str(0)+'"] R'+str(0)+';\n');

    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);
      for r in range(options.recv_endpoints):
	dot.write('node [label="N'+str(r)+'"] N'+str(r)+';\n');
      for r in range(options.send_endpoints):
	dot.write('node [label="N'+str(r+options.recv_endpoints)+'"] N'+str(r+options.recv_endpoints)+';\n');


  # For Unidirectional Tree position nodes
  elif (options.topology == "uni_tree" or options.topology == "uni_tree_up" or options.topology == "uni_tree_down"): # arrange nodes in a tree

    build_down_tree = True;
    if (options.topology == "uni_tree_down"):
      build_down_tree = True;
    elif (options.topology == "uni_tree_up"):
      build_down_tree = False;
    elif (options.uni_tree_inputs < options.uni_tree_outputs):
      build_down_tree = True;
    else: 
      build_down_tree = False;

    # assuming up tree
    num_root_nodes = options.uni_tree_outputs
    num_leaf_nodes = options.uni_tree_inputs
    #if(options.uni_tree_inputs < options.uni_tree_outputs): # Build down tree
    if(build_down_tree): # Build down tree
      num_root_nodes = options.uni_tree_inputs
      num_leaf_nodes = options.uni_tree_outputs

    num_stages = int(math.ceil(math.log(num_leaf_nodes, options.uni_tree_fanout))) - 1  # counts link stages
    # Find first and last router id of last stage where nodes attach
    final_stage_rt_first_id = 0
    for i in range(num_stages):
      final_stage_rt_first_id += options.uni_tree_fanout**i
    final_stage_rt_last_id = final_stage_rt_first_id * options.uni_tree_fanout

    cur_rt = 0;
    rts_in_stage = 1;
    last_stage_width = (1.0*options.uni_tree_fanout)**num_stages; #   num_leaf_nodes/(1.0*options.uni_tree_fanout);
    if(options.graph_nodes):  # Make more space to add endpoint nodes
      last_stage_width = (1.0*options.uni_tree_fanout)**(num_stages+1); #   num_leaf_nodes/(1.0*options.uni_tree_fanout);
    print "width", last_stage_width
    for stage in range(num_stages+1):
      gap = last_stage_width / (1.0*rts_in_stage)
      offset = gap/2.0
      print "offset ", offset
      for r in range(rts_in_stage):
        dot.write('\nnode [label="R'+str(cur_rt)+'" pos="'+str(offset+gap*r*1.0)+','+str((-1)*stage*2)+'!"] R'+str(cur_rt)+'\n');
        cur_rt += 1;
      rts_in_stage *= options.uni_tree_fanout; 

    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);

      for stage in range(num_stages+1):
	gap = 1.0; #last_stage_width / laste_)
	offset = 0.5 + (last_stage_width - 1.0*num_root_nodes) / 2.0
	print "gap",gap,"offset",offset
	if(stage == 0): # root
	  #if(options.uni_tree_inputs < options.uni_tree_outputs): # down tree has inputs at root
	  if(build_down_tree): # down tree has inputs at root
       	    for i in range(options.uni_tree_inputs):
	      # Leave input ports anonymous 
	      dot.write('\nnode [label="N'+ "" +'" pos="'+str(offset+gap*i*1.0)+','+str(2)+'!"] N'+str(i+options.uni_tree_outputs)+'\n');
	  else: # up tree has outputs at root
	    for o in range(options.uni_tree_outputs):
	      dot.write('\nnode [label="N'+str(o)+'" pos="'+str(offset+gap*o*1.0)+','+str(2)+'!"] N'+str(o)+'\n');
	      #dot.write('\nnode [label="R'+str(cur_rt)+'" pos="'+str(offset+gap*r*1.0)+','+str((-1)*stage*2)+'!"] R'+str(cur_rt)+'\n');

	if(stage == num_stages): # last stage
	  gap = 1.0; #last_stage_width / (1.0*rts_in_stage)
	  offset = gap/2.0
	  print "offset ", offset
	  #for r in range(rts_in_stage):
	  #if(options.uni_tree_inputs < options.uni_tree_outputs): # down tree has outputs at leafs
	  if(build_down_tree): # down tree has outputs at leafs
            if(options.uni_tree_distribute_leaves):  #distribute leaves
	      for o in range(options.uni_tree_outputs):
		rt = get_uni_tree_distributed_rt(o, num_stages, options.uni_tree_fanout);
		r_off = o/(options.uni_tree_fanout**(num_stages));
		dist = (rt*options.uni_tree_fanout+r_off);
		#dot.write('\nnode [label="N'+ "" +'" pos="'+str(offset+jump*a*1.0+b*gap)+','+str(2)+'!"] N'+str(i+options.uni_tree_outputs)+'\n');
		dot.write('\nnode [label="N'+str(o)+'" pos="'+str(offset+dist*1.0*gap)+','+str((-1)*(stage+1)*2)+'!"] N'+str(o)+'\n');
	    else:
	      for o in range(options.uni_tree_outputs):
		dot.write('\nnode [label="N'+str(o)+'" pos="'+str(offset+gap*o*1.0)+','+str((-1)*(stage+1)*2)+'!"] N'+str(o)+'\n');
		#dot.write('\nnode [label="R'+str(cur_rt)+'" pos="'+str(offset+gap*r*1.0)+','+str((-1)*stage*2)+'!"] R'+str(cur_rt)+'\n');
	  else: # up tree has inputs at leafs
            if(options.uni_tree_distribute_leaves):  #distribute leaves
	      for i in range(options.uni_tree_inputs):
		rt = get_uni_tree_distributed_rt(i, num_stages, options.uni_tree_fanout);
		r_off = i/(options.uni_tree_fanout**(num_stages));
		dist = (rt*options.uni_tree_fanout+r_off);
    		#dot.write('\nnode [label="N'+ "" +'" pos="'+str(offset+jump*a*1.0+b*gap)+','+str(2)+'!"] N'+str(i+options.uni_tree_outputs)+'\n');
		dot.write('\nnode [label="N'+ "" +'" pos="'+str(offset+dist*1.0*gap)+','+str((-1)*(stage+1)*2)+'!"] N'+str(i+options.uni_tree_outputs)+'\n');
	    else:
	      for i in range(options.uni_tree_inputs):
		dot.write('\nnode [label="N'+ "" +'" pos="'+str(offset+gap*i*1.0)+','+str((-1)*(stage+1)*2)+'!"] N'+str(i+options.uni_tree_outputs)+'\n');
		# use upper unused node IDs for the inputs ports

  # For custom topology consult topology_info
  elif (options.topology == "custom"):
    for r in range(options.num_routers):
      dot.write('node [label="R'+str(r)+'"] R'+str(r)+';\n');

    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);
      #for r in range(options.num_routers):
      for r in range( max( custom_topology_info['max_send_ports'], custom_topology_info['max_recv_ports']) ):
	dot.write('node [label="N'+str(r)+'"] N'+str(r)+';\n');

  # other topologies 
  else:
    for r in range(options.num_routers):
      dot.write('node [label="R'+str(r)+'"] R'+str(r)+';\n');

    if(options.graph_nodes):  # Add endpoint nodes
      dot.write(endpoint_node_style);
      for r in range(options.num_routers):
	dot.write('node [label="N'+str(r)+'"] N'+str(r)+';\n');

#  # Describe and rank nodes
#  if (options.topology == "mesh" or options.topology == "torus"): # arrange nodes in a grid
#    rt_id = 0;
#    for c in range(options.routers_per_column):
#      dot.write('{ node [shape=circle]\n');
#      for r in range(options.routers_per_row):
#        dot.write(' R'+str(rt_id));
#	rt_id = rt_id+1
#      dot.write('\n}\n');
#      
#  else:
#    for r in range(options.num_routers):
#      dot.write('node [label="R'+str(r)+'"] R'+str(r)+';\n');

  if (options.graph_layout == "invalid"):  # if user has not set this, set to specified layout
    options.graph_layout = layout;
  return dot


#######################################
## Single Switch
def gen_single_switch_links(links, dot_filename, dump_topology_filename):
  """Generates links for single switch topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo");

  # Expose user send/receive ports
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(0)+'].in_ports['+str(r)+'];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(0)+'].out_ports['+str(r)+'];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(0)+':'+str(r)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(0)+':'+str(r)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(0)+' [ headlabel = "' + str(r) + '" ];\n')
      dot.write('R'+str(0)+' -> N'+str(r)+' [ taillabel = "' + str(r) + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')
  
  link_id = 0; # this topology does not have any links
  
  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_single_switch_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for single switch topology"""
  global options, args

  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
  # Just a single router
  filename = options.output_dir + '/' + file_prefix + str(0) + '.hex'
  try: rt = open(filename, 'w');
  except IOError: print "Could not open file " + filename; sys.exit(-1);

  for dst in range(options.num_routers):
    out_port = dst
    rt.write('%x\n' % (out_port) );
    if options.verbose: print 'route:'+str(0)+'->'+str(dst)+':'+str(out_port)
    if options.dump_routing_file: route_dump.write('R'+str(0)+': '+str(dst)+' -> '+str(out_port)+'\n');

  rt.close();
  if options.verbose: print 'Generated routing file: ' + filename

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename

  # Hack - set num_routers to actual number of routers
  options.num_routers = 1;


#######################################
## Line
def gen_line_links(links, dot_filename, dump_topology_filename):
  """Generates links for line topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);

  # Generate graphviz .gv file
  #if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo");
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "dot");

  # Expose user send/receive ports
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r)+'].in_ports[0];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(r)+'].out_ports[0];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(r)+' [ headlabel = "' + '0' + '" ];\n')
      dot.write('R'+str(r)+' -> N'+str(r)+' [ taillabel = "' + '0' + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')
  
  link_id = -1;
  # Connect in one direction using port 1  (right)
  for r in range(options.num_routers-1):
    link_id = link_id + 1;
    next_router = (r+1)%options.num_routers;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(r)+'], 1, routers['+str(next_router)+'], 1);\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(r)+':'+str(1)+' -> '+'R'+str(next_router)+':'+str(1)+'\n')
    if options.gen_graph: dot.write('R'+str(r)+' -> R'+str(next_router)+' [ taillabel = "' + '1' + '", headlabel = "' + '1' + '" ];\n')
  # Connect in the other direction using port 2  (left)
  for r in range(1, options.num_routers):
    link_id = link_id + 1;
    prev_router = (r+options.num_routers-1)%options.num_routers;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(r)+'], 2, routers['+str(prev_router)+'], 2);\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(r)+':'+str(2)+' -> '+'R'+str(prev_router)+':'+str(2)+'\n')
    if options.gen_graph: dot.write('R'+str(r)+' -> R'+str(prev_router)+' [ taillabel = "' + '2' + '", headlabel = "' + '2' + '" ];\n')
  
  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_line_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for line topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try: rt = open(filename, 'w');
    except IOError: print "Could not open file " + filename; sys.exit(-1);

    for dst in range(options.num_routers):
      if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	rt.write('%x\n' % (0) );
	#str.format(  );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
      else:           # packet is not for me, decide which way to send
	diff = dst-src
	dist = abs(diff)
	if (diff >= 0):   # Send to the right, i.e. using out_port 1
	  out_port = 1
	  rt.write('%x\n' % (out_port) );
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
	else:             # Send to the left, i.e. using out_port 2
	  out_port = 2
	  rt.write('%x\n' % (out_port) );
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
  
    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename


#######################################
## Ring
def gen_ring_links(links, dot_filename, dump_topology_filename):
  """Generates links for ring topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);

  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo");

  # Expose user send/receive ports
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r)+'].in_ports[0];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(r)+'].out_ports[0];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(r)+' [ headlabel = "' + '0' + '" ];\n')
      dot.write('R'+str(r)+' -> N'+str(r)+' [ taillabel = "' + '0' + '" ];\n')

    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')
 
  link_id = -1;
  for r in range(options.num_routers):
    link_id = link_id + 1;
    next_router = (r+1)%options.num_routers;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(r)+'], 1, routers['+str(next_router)+'], 1);\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(r)+':'+str(1)+' -> '+'R'+str(next_router)+':'+str(1)+'\n')
    if options.gen_graph: dot.write('R'+str(r)+' -> R'+str(next_router)+' [ taillabel = "' + '1' + '", headlabel = "' + '1' + '" ];\n')
  
  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_ring_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for ring topology"""
  global options, args

  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try:
      rt = open(filename, 'w')
    except IOError:
      print "Could not open file " + filename
      sys.exit(-1)

    for dst in range(options.num_routers):
      if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	rt.write('%x\n' % (0) );
	#str.format(  );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
      else:           # packet is not for me, send to next router, i.e. out_port 1
        #next_router = (src+1)%options.num_routers;
	rt.write('%x\n' % (1) );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'1'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(1)+'\n');
  
    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename


#######################################
## Double-Ring
def gen_double_ring_links(links, dot_filename, dump_topology_filename):
  """Generates links for double-ring topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);

  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo"); 

  # Expose user send/receive ports
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r)+'].in_ports[0];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(r)+'].out_ports[0];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(r)+' [ headlabel = "' + '0' + '" ];\n')
      dot.write('R'+str(r)+' -> N'+str(r)+' [ taillabel = "' + '0' + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')
 
  link_id = -1;
  # Connect in one direction using port 1 (clockwise)
  for r in range(options.num_routers):
    link_id = link_id + 1;
    next_router = (r+1)%options.num_routers;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(r)+'], 1, routers['+str(next_router)+'], 1);\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(r)+':'+str(1)+' -> '+'R'+str(next_router)+':'+str(1)+'\n')
    if options.gen_graph: dot.write('R'+str(r)+' -> R'+str(next_router)+' [ taillabel = "' + '1' + '", headlabel = "' + '1' + '" ];\n')
  # Connect in the other direction using port 2 (counter-clockwise)
  for r in range(options.num_routers):
    link_id = link_id + 1;
    prev_router = (r+options.num_routers-1)%options.num_routers;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(r)+'], 2, routers['+str(prev_router)+'], 2);\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(r)+':'+str(2)+' -> '+'R'+str(prev_router)+':'+str(2)+'\n')
    if options.gen_graph: dot.write('R'+str(r)+' -> R'+str(prev_router)+' [ taillabel = "' + '2' + '", headlabel = "' + '2' + '" ];\n')
  
  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_double_ring_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for double-ring topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try:
      rt = open(filename, 'w')
    except IOError:
      print "Could not open file " + filename
      sys.exit(-1)

    for dst in range(options.num_routers):
      if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	rt.write('%x\n' % (0) );
	#str.format(  );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
      else:           # packet is not for me, decide which way to send
	diff = dst-src
	dist = abs(diff)
	if (diff >= 0 and dist <= options.num_routers/2) or (diff < 0 and dist > options.num_routers/2) :   # Send clockwise, i.e. using out_port 1
	  out_port = 1
	  rt.write('%x\n' % (out_port) );
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
	else:                                         # Send counter-clockwise, i.e. using out_port 1
	  out_port = 2
	  rt.write('%x\n' % (out_port) );
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
  
    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename

#######################################
## Star
def gen_star_links(links, dot_filename, dump_topology_filename):
  """Generates links for star topology"""
  global options, args
  
  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo");  # neato also works well for small networks
  
  # Expose user send/receive ports
  for r in range(options.num_routers-1):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r+1)+'].in_ports[0];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(r+1)+'].out_ports[0];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r+1)+':'+str(0)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(r+1)+':'+str(0)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(r+1)+' [ headlabel = "' + '0' + '" ];\n')
      dot.write('R'+str(r+1)+' -> N'+str(r)+' [ taillabel = "' + '0' + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] = get_port_info_ifc('+str(r)+');\n')

  link_id = -1;
  # Connect central router (0) to sattelite routers.
  for r in range(1, options.num_routers):
    link_id = link_id + 1;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(0)+'], ' + str(r-1) + ', routers['+str(r)+'], 1);\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(0)+':'+str(r-1)+' -> '+'R'+str(r)+':'+str(1)+'\n')
    if options.gen_graph: dot.write('R'+str(0)+' -> R'+str(r)+' [ taillabel = "' + str(r-1) + '", headlabel = "' + '1' + '" ];\n')

  # Connect sattelite routers to central router (0).
  for r in range(1, options.num_routers):
    link_id = link_id + 1;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(r)+'], ' + str(1) + ', routers['+str(0)+'], ' + str(r-1)+ ');\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(r)+':'+str(1)+' -> '+'R'+str(0)+':'+str(r-1)+'\n')
    if options.gen_graph: dot.write('R'+str(r)+' -> R'+str(0)+' [ taillabel = "' + str(1) + '", headlabel = "' + str(r-1) + '" ];\n')

  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_star_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for star topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try:
      rt = open(filename, 'w')
    except IOError:
      print "Could not open file " + filename
      sys.exit(-1)

    for dst in range(options.num_routers):
      if (src == 0):  # routing for central node
	out_port = dst;  # directly send to sattelite router
	rt.write('%x\n' % (out_port) );
	if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
      else:           # routing for sattelite routers
        if (src-1) == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	  rt.write('%x\n' % (0) );
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
	else: 
	  out_port = 1;  # always send to central router
	  rt.write('%x\n' % (out_port) );
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
  
    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename


#######################################
## Mesh
def gen_mesh_links(links, dot_filename, dump_topology_filename):
  """Generates mesh for mesh topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);

  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "neato");
  
  # Expose user send/receive ports
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r)+'].in_ports[0];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(r)+'].out_ports[0];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(r)+' [ headlabel = "' + '0' + '" ];\n')
      dot.write('R'+str(r)+' -> N'+str(r)+' [ taillabel = "' + '0' + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')

  link_id = -1;
  # Connect in left direction using port 1  (left)
  for r in range(1, options.routers_per_row):
    for c in range(0, options.routers_per_column):
      rt_id = c*options.routers_per_row + r;
      link_id = link_id + 1;
      left_router = c*options.routers_per_row + (r+options.routers_per_row-1)%options.routers_per_row;
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(rt_id)+'], 1, routers['+str(left_router)+'], 1);\n')
      if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(rt_id)+':'+str(1)+' -> '+'R'+str(left_router)+':'+str(1)+'\n')
      if options.gen_graph: dot.write('R'+str(rt_id)+' -> R'+str(left_router)+' [ taillabel = "' + '1' + '", headlabel = "' + '1' + '" ];\n')

  # Connect in up direction using port 2  (up)
  for r in range(0, options.routers_per_row):
    for c in range(1, options.routers_per_column):
      rt_id = c*options.routers_per_row + r;
      link_id = link_id + 1;
      up_router = ((c+options.routers_per_column-1)%options.routers_per_column) * options.routers_per_row + r;
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(rt_id)+'], 2, routers['+str(up_router)+'], 2);\n')
      if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(rt_id)+':'+str(2)+' -> '+'R'+str(up_router)+':'+str(2)+'\n')
      if options.gen_graph: dot.write('R'+str(rt_id)+' -> R'+str(up_router)+' [ taillabel = "' + '2' + '", headlabel = "' + '2' + '" ];\n')

  # Connect in right direction using port 3  (right)
  for r in range(0, options.routers_per_row-1):
    for c in range(0, options.routers_per_column):
      rt_id = c*options.routers_per_row + r;
      link_id = link_id + 1;
      right_router = c*options.routers_per_row + (r+options.routers_per_row+1)%options.routers_per_row;
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(rt_id)+'], 3, routers['+str(right_router)+'], 3);\n')
      if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(rt_id)+':'+str(3)+' -> '+'R'+str(right_router)+':'+str(3)+'\n')
      if options.gen_graph: dot.write('R'+str(rt_id)+' -> R'+str(right_router)+' [ taillabel = "' + '3' + '", headlabel = "' + '3' + '" ];\n')

  # Connect in down direction using port 4  (down)
  for r in range(0, options.routers_per_row):
    for c in range(0, options.routers_per_column-1):
      rt_id = c*options.routers_per_row + r;
      link_id = link_id + 1;
      down_router = ((c+options.routers_per_column+1)%options.routers_per_column) * options.routers_per_row + r;
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(rt_id)+'], 4, routers['+str(down_router)+'], 4);\n')
      if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(rt_id)+':'+str(4)+' -> '+'R'+str(down_router)+':'+str(4)+'\n')
      if options.gen_graph: dot.write('R'+str(rt_id)+' -> R'+str(down_router)+' [ taillabel = "' + '4' + '", headlabel = "' + '4' + '" ];\n')

  # Expose the extra user ports
  if(options.expose_unused_ports):
    num_total_user_ports = options.num_routers + 2*options.routers_per_row + 2*options.routers_per_column;
    for user_port in range(options.num_routers, num_total_user_ports):
      tmp = find_dst_and_output_for_user_port(user_port)
      rt = tmp[0]
      out_port = tmp[1]
      in_port = ((out_port+1) % 4) + 1
      r = rt%options.routers_per_row # row
      c = rt/options.routers_per_row # column
      r_offset = 0; c_offset = 0;
      if (out_port == 1): r_offset = -1.25; 
      if (out_port == 2): c_offset = -1.25; 
      if (out_port == 3): r_offset = 1.25; 
      if (out_port == 4): c_offset = 1.25; 
      links.write('send_ports_ifaces['+str(user_port)+'] = routers['+str(rt)+'].in_ports['+str(in_port)+'];\n')
      links.write('recv_ports_ifaces['+str(user_port)+'] = routers['+str(rt)+'].out_ports['+str(out_port)+'];\n')

      if options.dump_topology_file:
	topo_dump.write('SendPort '+str(user_port)+' -> R'+str(rt)+':'+str(in_port)+'\n')
	topo_dump.write('RecvPort '+str(user_port)+' -> R'+str(rt)+':'+str(out_port)+'\n')
      if options.gen_graph and options.graph_nodes: # also include the endpoints
        #dot.write('\nnode [label="N'+str(user_port)+'"] N'+str(user_port)+'\n');
        dot.write('\nnode [label="N'+str(user_port)+'" pos="'+str(r*1.5+r_offset)+','+str(c*1.5+c_offset)+'!"] N'+str(user_port)+'\n');
        dot.write('N'+str(user_port)+' -> R'+str(rt)+' [ headlabel = "' + str(in_port) + '" ];\n')
        dot.write('R'+str(rt)+' -> N'+str(user_port)+' [ taillabel = "' + str(out_port) + '" ];\n')
      #links.write('router_info_ifaces['+str(user_port)+'] = get_router_info_ifc('+str(user_port)+');\n')
      links.write('recv_ports_info_ifaces['+str(user_port)+'] =  get_port_info_ifc('+str(user_port)+');\n')
  

  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id+1

def gen_mesh_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for mesh topology. XY routing: First move horizontally, then vertically."""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
    
  ## Typical mesh, does not expose extra ports
  if(not options.expose_unused_ports):
    for src in range(options.num_routers):
      filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
      try:
	rt = open(filename, 'w')
      except IOError:
	print "Could not open file " + filename
	sys.exit(-1)

      for dst in range(options.num_routers):
	if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	  rt.write('%x\n' % (0) );
	  #str.format(  );
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
	else:           # packet is not for me, decide which way to send
	  src_row = src / options.routers_per_row
	  src_col = src % options.routers_per_row
	  dst_row = dst / options.routers_per_row
	  dst_col = dst % options.routers_per_row
	  if(src_col != dst_col):  # Need to send horizontally
	    diff = dst_col-src_col
	    dist = abs(diff)
	    if (diff >= 0):   # Send to the right, i.e. using out_port 3
	      out_port = 3
	      rt.write('%x\n' % (out_port) );
	      if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
              if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
	    else:             # Send to the left, i.e. using out_port 1
	      out_port = 1
	      rt.write('%x\n' % (out_port) );
	      if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
              if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
	  else:  # Need to send vertically
	    diff = dst_row-src_row
	    dist = abs(diff)
	    if (diff >= 0):   # Send down, i.e. using out_port 4
	      out_port = 4
	      rt.write('%x\n' % (out_port) );
	      if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
              if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
	    else:             # Send up, i.e. using out_port 2
	      out_port = 2
	      rt.write('%x\n' % (out_port) );
	      if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
              if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');

  ## Expose extra ports
  else: 
    num_total_user_ports = options.num_routers + 2*options.routers_per_row + 2*options.routers_per_column;
    for src in range(options.num_routers):
      filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
      try:
	rt = open(filename, 'w')
      except IOError:
	print "Could not open file " + filename
	sys.exit(-1)

      for user_port in range(num_total_user_ports):
	tmp = find_dst_and_output_for_user_port(user_port)
	dst = tmp[0]
	if dst == src:  # packet is destined to me, extract from router, i.e. out_port 0
	  out_port = tmp[1]
	  rt.write('%x\n' % (out_port) );
	  #str.format(  );
	  if options.verbose: print 'route:'+str(src)+'->'+str(user_port)+':'+str(out_port)
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(user_port)+' -> '+str(out_port)+'\n');
	else:           # packet is not for me, decide which way to send
	  src_row = src / options.routers_per_row
	  src_col = src % options.routers_per_row
	  dst_row = dst / options.routers_per_row
	  dst_col = dst % options.routers_per_row
	  if(src_col != dst_col):  # Need to send horizontally
	    diff = dst_col-src_col
	    dist = abs(diff)
	    if (diff >= 0):   # Send to the right, i.e. using out_port 3
	      out_port = 3
	      rt.write('%x\n' % (out_port) );
	      if options.verbose: print 'route:'+str(src)+'->'+str(user_port)+':'+str(out_port)
              if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(user_port)+' -> '+str(out_port)+'\n');
	    else:             # Send to the left, i.e. using out_port 1
	      out_port = 1
	      rt.write('%x\n' % (out_port) );
	      if options.verbose: print 'route:'+str(src)+'->'+str(user_port)+':'+str(out_port)
              if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(user_port)+' -> '+str(out_port)+'\n');
	  else:  # Need to send vertically
	    diff = dst_row-src_row
	    dist = abs(diff)
	    if (diff >= 0):   # Send down, i.e. using out_port 4
	      out_port = 4
	      rt.write('%x\n' % (out_port) );
	      if options.verbose: print 'route:'+str(src)+'->'+str(user_port)+':'+str(out_port)
              if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(user_port)+' -> '+str(out_port)+'\n');
	    else:             # Send up, i.e. using out_port 2
	      out_port = 2
	      rt.write('%x\n' % (out_port) );
	      if options.verbose: print 'route:'+str(src)+'->'+str(user_port)+':'+str(out_port)
              if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(user_port)+' -> '+str(out_port)+'\n');


    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename

# helper function for mesh that exposes extra user ports
def find_dst_and_output_for_user_port(user_port):
  if(user_port < options.num_routers):
    return [user_port,0]
  else:
    cur_user_port = options.num_routers-1;
    for cur_rt in range(options.num_routers):
      is_left_side_router = cur_rt % options.routers_per_row == 0
      is_right_side_router = cur_rt % options.routers_per_row == options.routers_per_row-1
      is_top_side_router = cur_rt >= 0 and cur_rt < options.routers_per_row
      is_bottom_side_router = cur_rt >= options.num_routers - options.routers_per_row and cur_rt <  options.num_routers

      if(is_left_side_router):
	cur_user_port = cur_user_port+1
	if(cur_user_port == user_port):
          return [cur_rt,1]
      
      if(is_top_side_router):
	cur_user_port = cur_user_port+1
	if(cur_user_port == user_port):
	  return [cur_rt,2]
     
      if(is_right_side_router):
	cur_user_port = cur_user_port+1
	if(cur_user_port == user_port):
	  return [cur_rt,3]
    
      if(is_bottom_side_router):
	cur_user_port = cur_user_port+1
	if(cur_user_port == user_port):
	  return [cur_rt,4]

    #is_corner_router = (cur_rt == 0 || cur_rt == options.routers_per_row-1 || cur_rt == options.num_routers - 1 || cur_rt == options.num_routers - 1 - options.routers_per_row)
    #is_top_bottom_router = (cur_rt >= 0 && cur_rt < options.routers_per_row) || (cur_rt >= options.num_routers - options.routers_per_row && cur_rt <  options.num_routers)

    #is_left_right_side_router = (cur_rt % options.routers_per_row == 0 || cur_rt % options.routers_per_row == options.routers_per_row-1);
    #src_row = src / options.routers_per_row
    #src_col = src % options.routers_per_row
    #dst_row = dst / options.routers_per_row
    #dst_col = dst % options.routers_per_row

  
  


#######################################
## Torus
def gen_torus_links(links, dot_filename, dump_topology_filename):
  """Generates mesh for torus topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "neato");
  
  # Expose user send/receive ports
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r)+'].in_ports[0];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(r)+'].out_ports[0];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(r)+' [ headlabel = "' + '0' + '" ];\n')
      dot.write('R'+str(r)+' -> N'+str(r)+' [ taillabel = "' + '0' + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')

  link_id = -1;
  # Connect in left direction using port 1  (left)
  for r in range(0, options.routers_per_row):
    for c in range(0, options.routers_per_column):
      rt_id = c*options.routers_per_row + r;
      link_id = link_id + 1;
      left_router = c*options.routers_per_row + (r+options.routers_per_row-1)%options.routers_per_row;
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(rt_id)+'], 1, routers['+str(left_router)+'], 1);\n')
      if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(rt_id)+':'+str(1)+' -> '+'R'+str(left_router)+':'+str(1)+'\n')
      if options.gen_graph: dot.write('R'+str(rt_id)+' -> R'+str(left_router)+' [ taillabel = "' + '1' + '", headlabel = "' + '1' + '" ];\n')

  # Connect in up direction using port 2  (up)
  for r in range(0, options.routers_per_row):
    for c in range(0, options.routers_per_column):
      rt_id = c*options.routers_per_row + r;
      link_id = link_id + 1;
      up_router = ((c+options.routers_per_column-1)%options.routers_per_column) * options.routers_per_row + r;
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(rt_id)+'], 2, routers['+str(up_router)+'], 2);\n')
      if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(rt_id)+':'+str(2)+' -> '+'R'+str(up_router)+':'+str(2)+'\n')
      if options.gen_graph: dot.write('R'+str(rt_id)+' -> R'+str(up_router)+' [ taillabel = "' + '2' + '", headlabel = "' + '2' + '" ];\n')

  # Connect in right direction using port 3  (right)
  for r in range(0, options.routers_per_row):
    for c in range(0, options.routers_per_column):
      rt_id = c*options.routers_per_row + r;
      link_id = link_id + 1;
      right_router = c*options.routers_per_row + (r+options.routers_per_row+1)%options.routers_per_row;
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(rt_id)+'], 3, routers['+str(right_router)+'], 3);\n')
      if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(rt_id)+':'+str(3)+' -> '+'R'+str(right_router)+':'+str(3)+'\n')
      if options.gen_graph: dot.write('R'+str(rt_id)+' -> R'+str(right_router)+' [ taillabel = "' + '3' + '", headlabel = "' + '3' + '" ];\n')

  # Connect in down direction using port 4  (down)
  for r in range(0, options.routers_per_row):
    for c in range(0, options.routers_per_column):
      rt_id = c*options.routers_per_row + r;
      link_id = link_id + 1;
      down_router = ((c+options.routers_per_column+1)%options.routers_per_column) * options.routers_per_row + r;
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(rt_id)+'], 4, routers['+str(down_router)+'], 4);\n')
      if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(rt_id)+':'+str(4)+' -> '+'R'+str(down_router)+':'+str(4)+'\n')
      if options.gen_graph: dot.write('R'+str(rt_id)+' -> R'+str(down_router)+' [ taillabel = "' + '4' + '", headlabel = "' + '4' + '" ];\n')

  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_torus_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for torus topology. XY routing: First move horizontally, then vertically."""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try:
      rt = open(filename, 'w')
    except IOError:
      print "Could not open file " + filename
      sys.exit(-1)

    for dst in range(options.num_routers):
      if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	rt.write('%x\n' % (0) );
	#str.format(  );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
      else:           # packet is not for me, decide which way to send
	src_row = src / options.routers_per_row
	src_col = src % options.routers_per_row
	dst_row = dst / options.routers_per_row
	dst_col = dst % options.routers_per_row
	if(src_col != dst_col):  # Need to send horizontally
	  diff = dst_col-src_col
	  dist = abs(diff)
	  if (diff >= 0 and dist <= options.routers_per_row/2) or (diff < 0 and dist > options.routers_per_row/2) :   # Send to the right, i.e. using out_port 3
	    out_port = 3
	    rt.write('%x\n' % (out_port) );
	    if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
            if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
	  else:             # Send to the left, i.e. using out_port 1
	    out_port = 1
	    rt.write('%x\n' % (out_port) );
	    if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
            if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
	else:  # Need to send vertically
	  diff = dst_row-src_row
	  dist = abs(diff)
	  if (diff >= 0 and dist <= options.routers_per_column/2) or (diff < 0 and dist > options.routers_per_column/2) :   # Send down, i.e. using out_port 4
	    out_port = 4
	    rt.write('%x\n' % (out_port) );
	    if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
            if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');
	  else:             # Send up, i.e. using out_port 2
	    out_port = 2
	    rt.write('%x\n' % (out_port) );
	    if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
            if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(out_port)+'\n');

    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename
  
  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename


#######################################
## Fully-connected
def gen_fully_connected_links(links, dot_filename, dump_topology_filename):
  """Generates links for fully_connected topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo");  # neato also works well for small networks

  # Expose user send/receive ports
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r)+'].in_ports[0];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(r)+'].out_ports[0];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(r)+':'+str(0)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(r)+' [ headlabel = "' + '0' + '" ];\n')
      dot.write('R'+str(r)+' -> N'+str(r)+' [ taillabel = "' + '0' + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')

  link_id = -1;
  # Connect each router to all other routers.
  for s in range(0, options.num_routers):
    for d in range(0, options.num_routers):
      if (s != d): # don't create a link to my self
	if (s < d): 
          link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(s)+'], ' + str(d) + ', routers['+str(d)+'], ' + str(s+1) + ');\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(s)+':'+str(d)+' -> '+'R'+str(d)+':'+str(s+1)+'\n')
          if options.gen_graph: dot.write('R'+str(s)+' -> R'+str(d)+' [ taillabel = "' + str(d) + '", headlabel = "' + str(s+1) + '" ];\n')
	else:
	  link_id = link_id + 1;
	  links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(s)+'], ' + str(d+1) + ', routers['+str(d)+'], ' + str(s) + ');\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(s)+':'+str(d+1)+' -> '+'R'+str(d)+':'+str(s)+'\n')
          if options.gen_graph: dot.write('R'+str(s)+' -> R'+str(d)+' [ taillabel = "' + str(d+1) + '", headlabel = "' + str(s) + '" ];\n')
 
  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_fully_connected_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for fully_connected topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try:
      rt = open(filename, 'w')
    except IOError:
      print "Could not open file " + filename
      sys.exit(-1)

  # All routers are a single hop away. Just pick proper output port.
    for dst in range(0, options.num_routers):
      if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	rt.write('%x\n' % (0) );
	#str.format(  );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
      else:           # packet is not for me, decide which way to send
	if (src < dst): 
	  rt.write('%x\n' % (dst) )
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(dst)
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(dst)+'\n');
	else:
	  rt.write('%x\n' % (dst+1) );
	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(dst+1)
          if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(dst+1)+'\n');

    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename


#######################################
## Fat Tree
def gen_fat_tree_links(links, dot_filename, dump_topology_filename):
  """Generates links for fat-tree topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "neato");
  
  # Expose user send/receive ports  (note: num_routers is a misnomer for this topology)
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r/2)+'].in_ports['+str(r%2)+'];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(r/2)+'].out_ports['+str(r%2)+'];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r/2)+':'+str(r%2)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(r/2)+':'+str(r%2)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r)+' -> R'+str(r/2)+' [ headlabel = "' + str(r%2) + '" ];\n')
      dot.write('R'+str(r/2)+' -> N'+str(r)+' [ taillabel = "' + str(r%2) + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')
  
  link_id = -1;
  # Create links for each stage
  num_stages = int(math.log(options.num_routers, 2)) - 2  # counts link stages
  rts_in_stage = options.num_routers/2
  print 'num_stages =', num_stages
  for stage in range(num_stages):
    if (stage < num_stages-1):  # not the top stage
      for sr in range(rts_in_stage):  # subrouter in particular stage
        cur_rt = stage * rts_in_stage + sr

        #Check if this router belongs to the left or right subset
	if( (cur_rt & (1<<stage) ) == 0):   # left subset, i.e. has stage-th bit set to 0  (connect above and to the right)
	  #Up links
          link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 2, routers['+str(cur_rt+rts_in_stage)+'], 0);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(2)+' -> '+'R'+str(cur_rt+rts_in_stage)+':'+str(0)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(cur_rt+rts_in_stage)+' [ taillabel = "' + '2' + '", headlabel = "' + '0' + '" ];\n')
          link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 3, routers['+str(cur_rt+rts_in_stage+(1<<stage))+'], 0);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(3)+' -> '+'R'+str(cur_rt+rts_in_stage+(1<<stage))+':'+str(0)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(cur_rt+rts_in_stage+(1<<stage))+' [ taillabel = "' + '3' + '", headlabel = "' + '0' + '" ];\n')
	  
	  #Down links
	  link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt+rts_in_stage)+'], 0, routers['+str(cur_rt)+'], 2);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt+rts_in_stage)+':'+str(0)+' -> '+'R'+str(cur_rt)+':'+str(2)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt+rts_in_stage)+' -> R'+str(cur_rt)+' [ taillabel = "' + '0' + '", headlabel = "' + '2' + '" ];\n')
          link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt+rts_in_stage+(1<<stage))+'], 0, routers['+str(cur_rt)+'], 3);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt+rts_in_stage+(1<<stage))+':'+str(0)+' -> '+'R'+str(cur_rt)+':'+str(3)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt+rts_in_stage+(1<<stage))+' -> R'+str(cur_rt)+' [ taillabel = "' + '0' + '", headlabel = "' + '3' + '" ];\n')

	else:   # right subset, i.e. has stage-th bit set to 1  (connect to the left and above)
	  #Up links
          link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 2, routers['+str(cur_rt+rts_in_stage-(1<<stage))+'], 1);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(2)+' -> '+'R'+str(cur_rt+rts_in_stage-(1<<stage))+':'+str(1)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(cur_rt+rts_in_stage-(1<<stage))+' [ taillabel = "' + '2' + '", headlabel = "' + '1' + '" ];\n')
          link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 3, routers['+str(cur_rt+rts_in_stage)+'], 1);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(3)+' -> '+'R'+str(cur_rt+rts_in_stage)+':'+str(1)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(cur_rt+rts_in_stage)+' [ taillabel = "' + '3' + '", headlabel = "' + '1' + '" ];\n')
	  
	  #Down links
          link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt+rts_in_stage-(1<<stage))+'], 1, routers['+str(cur_rt)+'], 2);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt+rts_in_stage-(1<<stage))+':'+str(1)+' -> '+'R'+str(cur_rt)+':'+str(2)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt+rts_in_stage-(1<<stage))+' -> R'+str(cur_rt)+' [ taillabel = "' + '1' + '", headlabel = "' + '2' + '" ];\n')
          link_id = link_id + 1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt+rts_in_stage)+'], 1, routers['+str(cur_rt)+'], 3);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt+rts_in_stage)+':'+str(1)+' -> '+'R'+str(cur_rt)+':'+str(3)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt+rts_in_stage)+' -> R'+str(cur_rt)+' [ taillabel = "' + '1' + '", headlabel = "' + '3' + '" ];\n')

    else: # Last stage links
      links.write('//Last stage links\n')
      last_stages = rts_in_stage/2; # Number of stages in last/top level
      first_top_rt = num_stages * rts_in_stage;
      top_rt_offset = 0; # rotate between top RTs
      top_port_id = 0; #which port to connect to
      for sr in range(rts_in_stage):
        cur_rt = stage * rts_in_stage + sr
	#Check if this router belongs to the left or right subset
	#if( (cur_rt & (1<<stage) ) == 0):   # left subset, i.e. has stage-th bit set to 0  (connect above and to the right)
	  #Up links
	link_id = link_id + 1;
	links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 2, routers['+str(first_top_rt+top_rt_offset)+'], '+str(top_port_id)+');\n')
        if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(2)+' -> '+'R'+str(first_top_rt+top_rt_offset)+':'+str(top_port_id)+'\n')
	if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(first_top_rt+top_rt_offset)+' [ taillabel = "' + '2' + '", headlabel = "' + str(top_port_id) + '" ];\n')
	#Down links
	link_id = link_id + 1;
	links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(first_top_rt+top_rt_offset)+'], '+str(top_port_id)+', routers['+str(cur_rt)+'], 2);\n')
        if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(first_top_rt+top_rt_offset)+':'+str(top_port_id)+' -> '+'R'+str(cur_rt)+':'+str(2)+'\n')
	if options.gen_graph: dot.write('R'+str(first_top_rt+top_rt_offset)+' -> R'+str(cur_rt)+' [ taillabel = "' + str(top_port_id) + '", headlabel = "' + '2' + '" ];\n')
	top_rt_offset = (top_rt_offset + 1) % last_stages;

	#Up Links
	link_id = link_id + 1;
	links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 3, routers['+str(first_top_rt+top_rt_offset)+'], '+str(top_port_id)+');\n')
        if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(3)+' -> '+'R'+str(first_top_rt+top_rt_offset)+':'+str(top_port_id)+'\n')
	if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(first_top_rt+top_rt_offset)+' [ taillabel = "' + '3' + '", headlabel = "' + str(top_port_id) + '" ];\n')
	#Down links
	link_id = link_id + 1;
	links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(first_top_rt+top_rt_offset)+'], '+str(top_port_id)+', routers['+str(cur_rt)+'], 3);\n')
        if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(first_top_rt+top_rt_offset)+':'+str(top_port_id)+' -> '+'R'+str(cur_rt)+':'+str(3)+'\n')
	if options.gen_graph: dot.write('R'+str(first_top_rt+top_rt_offset)+' -> R'+str(cur_rt)+' [ taillabel = "' + str(top_port_id) + '", headlabel = "' + '3' + '" ];\n')
	top_rt_offset = (top_rt_offset + 1) % last_stages;

	if(top_rt_offset == 0):
	    top_port_id = top_port_id + 1; # connect to next port now


  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id+1

# TODO: fix this when you get restored file from ECE computing services.
# Correct version was somewhere between 2/11 and 2/14
def gen_fat_tree_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for fat-tree topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  num_stages = int(math.log(options.num_routers, 2)) - 1  # counts router stages
  rts_in_stage = options.num_routers/2
  print 'num_stages =', num_stages
  for stage in range(num_stages):
    if (stage < num_stages-1):  # not the top stage
      for sr in range(rts_in_stage):  # subrouter in particular stage
        cur_rt = stage * rts_in_stage + sr
	print 'cur_rt ', cur_rt
	filename = options.output_dir + '/' + file_prefix + str(cur_rt) + '.hex'
	try: rt = open(filename, 'w');
	except IOError: print "Could not open file " + filename; sys.exit(-1);

	for dst in range(options.num_routers):
	  # Look at MS bits to determine up or down direction
	  if(dst>>stage+1 == sr>>stage): #go down
	    # Look at stage-th bit to determine left or right direction
	    if( dst & (1<<(stage)) == 0):   # go left 
	      rt.write('%x\n' % (0) );
	      if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'0'
              if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(0)+'\n');
	    else: #go right
	      rt.write('%x\n' % (1) );
	      if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'1'
              if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(1)+'\n');
	  else: #go up
	    # Look at stage-th bit to determine left or right direction
	    if( dst & (1<<(stage)) == 0):   # go left 
	      rt.write('%x\n' % (2) );
	      if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'2'
              if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(2)+'\n');
	    else: #go right
	      rt.write('%x\n' % (3) );
	      if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'3'
              if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(3)+'\n');
	rt.close();
	if options.verbose: print 'Generated routing file: ' + filename

    else: # top stage - you can only go down from here
      for sr in range(rts_in_stage/2):  # subrouter in particular stage
        cur_rt = stage * rts_in_stage + sr
	print 'cur_rt ', cur_rt
	filename = options.output_dir + '/' + file_prefix + str(cur_rt) + '.hex'
	try: rt = open(filename, 'w');
	except IOError: print "Could not open file " + filename; sys.exit(-1);

	for dst in range(options.num_routers):
	  # Look at 2 MS bits to determine up or down direction
	  out_port = dst>>stage
	  rt.write('%x\n' % (out_port) );
	  if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+str(out_port)
          if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(out_port)+'\n');
	rt.close();
	if options.verbose: print 'Generated routing file: ' + filename
  # Hack - set num_routers to actual number of routers
  actual_routers = (num_stages-1) * (options.num_routers/2) + (options.num_routers/4) # n-1 stages + last stage
  options.num_routers = actual_routers;

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename

#  for src in range(options.num_routers):
#    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
#    try: rt = open(filename, 'w');
#    except IOError: print "Could not open file " + filename; sys.exit(-1);
#
#    for dst in range(options.num_routers):
#      if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
#	rt.write('%x\n' % (0) );
#	#str.format(  );
#        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
#      else:           # packet is not for me, decide which way to send
#	diff = dst-src
#	dist = abs(diff)
#	if (diff >= 0):   # Send to the right, i.e. using out_port 1
#	  out_port = 1
#	  rt.write('%x\n' % (out_port) );
#	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
#	else:             # Send to the left, i.e. using out_port 2
#	  out_port = 2
#	  rt.write('%x\n' % (out_port) );
#	  if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
#  
#    rt.close();
#    if options.verbose: print 'Generated routing file: ' + filename



#######################################
## Butterfly (2-ary n-fly)
def gen_butterfly_links(links, dot_filename, dump_topology_filename):
  """Generates links for butterfly topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "neato");
 
  # Calculate number of stages and routers per stage
  num_stages = int(math.log(options.num_routers, 2));  # number of stages - log2(N)
  rts_in_stage = options.num_routers/2;  # switches per stage - N/2
  last_stage_offset = (num_stages-1)*rts_in_stage;

  # Expose user send/receive ports  (note: num_routers is a misnomer for this topology)
  for r in range(options.num_routers):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(r/2)+'].in_ports['+str(r%2)+'];\n')
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(last_stage_offset + r/2)+'].out_ports['+str(r%2)+'];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(r/2)+':'+str(r%2)+'\n')
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(last_stage_offset + r/2)+':'+str(r%2)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('N'+str(r+options.num_routers)+' -> R'+str(r/2)+' [ headlabel = "' + str(r%2) + '" ];\n')
      dot.write('R'+str(last_stage_offset + r/2)+' -> N'+str(r)+' [ taillabel = "' + str(r%2) + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')
  
  # Create links for each stage
  link_id = -1;
  print 'num_stages =', num_stages
  link_stages = num_stages - 1;
  for stage in range(link_stages):  # first stage is the most-right one
    for sr in range(rts_in_stage):  # subrouter in particular stage
      cur_rt = stage * rts_in_stage + sr

      rev_stage = link_stages - stage -1; # count in reverse to make things simpler
      #Check if this router belongs to the top or bottom
      if( (cur_rt &  1<<rev_stage ) == 0):   # top subset  (connect to the right and to bottom right)
	#Right links
        link_id = link_id + 1;
        links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 0, routers['+str(cur_rt+rts_in_stage)+'], 0);\n')
        if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(0)+' -> '+'R'+str(cur_rt+rts_in_stage)+':'+str(0)+'\n')
        if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(cur_rt+rts_in_stage)+' [ taillabel = "' + '0' + '", headlabel = "' + '0' + '" ];\n')
        link_id = link_id + 1;
        links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 1, routers['+str(cur_rt+rts_in_stage+(1<<rev_stage))+'], 0);\n')
        if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(1)+' -> '+'R'+str(cur_rt+rts_in_stage+(1<<rev_stage))+':'+str(0)+'\n')
        if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(cur_rt+rts_in_stage+(1<<rev_stage))+' [ taillabel = "' + '1' + '", headlabel = "' + '0' + '" ];\n')
	
	#Down links
	#link_id = link_id + 1;
        #links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt+rts_in_stage)+'], 0, routers['+str(cur_rt)+'], 2);\n')
        #if options.gen_graph: dot.write('R'+str(cur_rt+rts_in_stage)+' -> R'+str(cur_rt)+' [ taillabel = "' + '0' + '", headlabel = "' + '2' + '" ];\n')
        #link_id = link_id + 1;
        #links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt+rts_in_stage+(1<<stage))+'], 0, routers['+str(cur_rt)+'], 3);\n')
        #if options.gen_graph: dot.write('R'+str(cur_rt+rts_in_stage+(1<<stage))+' -> R'+str(cur_rt)+' [ taillabel = "' + '0' + '", headlabel = "' + '3' + '" ];\n')

      else:   # bottom subset, (connect to the right and top right)
	#Up links
        link_id = link_id + 1;
        links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 0, routers['+str(cur_rt+rts_in_stage-(1<<rev_stage))+'], 1);\n')
        if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(0)+' -> '+'R'+str(cur_rt+rts_in_stage-(1<<rev_stage))+':'+str(1)+'\n')
        if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(cur_rt+rts_in_stage-(1<<rev_stage))+' [ taillabel = "' + '0' + '", headlabel = "' + '1' + '" ];\n')
        link_id = link_id + 1;
        links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], 1, routers['+str(cur_rt+rts_in_stage)+'], 1);\n')
        if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(1)+' -> '+'R'+str(cur_rt+rts_in_stage)+':'+str(1)+'\n')
        if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(cur_rt+rts_in_stage)+' [ taillabel = "' + '1' + '", headlabel = "' + '1' + '" ];\n')
	
	#Down links
        #link_id = link_id + 1;
        #links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt+rts_in_stage-(1<<stage))+'], 1, routers['+str(cur_rt)+'], 2);\n')
        #if options.gen_graph: dot.write('R'+str(cur_rt+rts_in_stage-(1<<stage))+' -> R'+str(cur_rt)+' [ taillabel = "' + '1' + '", headlabel = "' + '2' + '" ];\n')
        #link_id = link_id + 1;
        #links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt+rts_in_stage)+'], 1, routers['+str(cur_rt)+'], 3);\n')
        #if options.gen_graph: dot.write('R'+str(cur_rt+rts_in_stage)+' -> R'+str(cur_rt)+' [ taillabel = "' + '1' + '", headlabel = "' + '3' + '" ];\n')

  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id+1
  sys.exit(0)

# fix this
def gen_butterfly_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for butterfly topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  # Calculate number of stages and routers per stage
  num_stages = int(math.log(options.num_routers, 2));  # number of stages - log2(N)
  rts_in_stage = options.num_routers/2;  # switches per stage - N/2
  last_stage_offset = (num_stages-1)*rts_in_stage;

  print 'num_stages =', num_stages
  for stage in range(num_stages):
    for sr in range(rts_in_stage):  # subrouter in particular stage
      cur_rt = stage * rts_in_stage + sr
      rev_stage = num_stages - stage -1; # count in reverse to make things simpler
      print 'cur_rt ', cur_rt
      filename = options.output_dir + '/' + file_prefix + str(cur_rt) + '.hex'
      try: rt = open(filename, 'w');
      except IOError: print "Could not open file " + filename; sys.exit(-1);

      for dst in range(options.num_routers):
	# Look at stage-th bit to determine left or right direction
	if( dst & (1<<(rev_stage)) == 0):   # go down
	  rt.write('%x\n' % (0) );
	  if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'0'
          if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(0)+'\n');
	else: #go up
	  rt.write('%x\n' % (1) );
	  if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'1'
          if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(1)+'\n');

	## Look at MS bits to determine up or down direction
	#if(dst>>rev_stage+1 == sr>>rev_stage): #go down
	#  # Look at stage-th bit to determine left or right direction
	#  if( dst & (1<<(rev_stage)) == 0):   # go left 
	#    rt.write('%x\n' % (0) );
	#    if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'0'
	#  else: #go right
	#    rt.write('%x\n' % (1) );
	#    if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'1'
	#else: #go up
	#  # Look at stage-th bit to determine left or right direction
	#  if( dst & (1<<(rev_stage)) == 0):   # go left 
	#    rt.write('%x\n' % (2) );
	#    if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'2'
	#  else: #go right
	#    rt.write('%x\n' % (3) );
	#    if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+'3'
      rt.close();
      if options.verbose: print 'Generated routing file: ' + filename
  # Hack - set num_routers to actual number of routers
  actual_routers = (num_stages) * (options.num_routers/2) # n stages, each n/2 routers
  options.num_routers = actual_routers;
  
  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename


#######################################
## Unidirectional Single Switch
def gen_uni_single_switch_links(links, dot_filename, dump_topology_filename):
  """Generates links for unidirectional single switch topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo");

# Expose user send/receive ports
  for r in range(options.recv_endpoints):
    links.write('recv_ports_ifaces['+str(r)+'] = routers['+str(0)+'].out_ports['+str(r)+'];\n')
    links.write('recv_ports_info_ifaces['+str(r)+'] =  get_port_info_ifc('+str(r)+');\n')
    if options.dump_topology_file:
      topo_dump.write('RecvPort '+str(r)+' -> R'+str(0)+':'+str(r)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      dot.write('R'+str(0)+' -> N'+str(r)+' [ taillabel = "' + str(r) + '" ];\n')

  for r in range(options.send_endpoints):
    links.write('send_ports_ifaces['+str(r)+'] = routers['+str(0)+'].in_ports['+str(r)+'];\n')
    if options.dump_topology_file:
      topo_dump.write('SendPort '+str(r)+' -> R'+str(0)+':'+str(r)+'\n')
    if options.gen_graph and options.graph_nodes: # also include the endpoints
      #dot.write('N'+str(r+options.recv_endpoints)+' -> R'+str(0)+' [ headlabel = "' + str(r+options.recv_endpoints) + '" ];\n')
      dot.write('N'+str(r+options.recv_endpoints)+' -> R'+str(0)+' [ headlabel = "' + str(r) + '" ];\n')
    #links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
  
  link_id = 0; # this topology does not have any links
  
  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_uni_single_switch_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for unidirectional single switch topology"""
  return gen_single_switch_routing(file_prefix, dump_routing_filename);


#######################################
## Uni-directional Tree helper function
## Given an endpoint id, it returns the router id the node should be attached to.
## Note: you still need to add the router offset of the first router id of the last stage.

def get_uni_tree_distributed_rt(node_id, num_stages, fanout):
  i = 0;
  rt = 0;
  while(num_stages > 0):
    rt += (node_id%fanout) * (fanout**(num_stages-1))
    node_id = node_id / fanout;
    num_stages -= 1
  return rt;

#######################################
## Uni-directional Tree

# Wrappers for gen_uni_tree functions
def gen_uni_tree_up_links(links, dot_filename, dump_topology_filename):
  return gen_uni_tree_links(links, dot_filename, dump_topology_filename);

def gen_uni_tree_up_routing(file_prefix, dump_routing_filename):
  return gen_uni_tree_routing(file_prefix, dump_routing_filename);

def gen_uni_tree_down_links(links, dot_filename, dump_topology_filename):
  return gen_uni_tree_links(links, dot_filename, dump_topology_filename);

def gen_uni_tree_down_routing(file_prefix, dump_routing_filename):
  return gen_uni_tree_routing(file_prefix, dump_routing_filename);

def gen_uni_tree_links(links, dot_filename, dump_topology_filename):
  """Generates links for uni-tree topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "neato");
  
  num_root_nodes = 0;
  num_leaf_nodes = 0;

  build_down_tree = True;
  if (options.topology == "uni_tree_down"):
    build_down_tree = True;
  elif (options.topology == "uni_tree_up"):
    build_down_tree = False;
  elif (options.uni_tree_inputs < options.uni_tree_outputs):
    build_down_tree = True;
  else: 
    build_down_tree = False;

  #if(options.uni_tree_inputs < options.uni_tree_outputs): # Build down tree
  if(build_down_tree): # Build down tree
    num_root_nodes = options.uni_tree_inputs
    num_leaf_nodes = options.uni_tree_outputs
    num_stages = int(math.ceil(math.log(num_leaf_nodes, options.uni_tree_fanout))) - 1  # counts link stages
    print "num_stages ",num_stages
    # Expose user send/receive ports
    for i in range(options.uni_tree_inputs):
      links.write('send_ports_ifaces['+str(i)+'] = routers[0].in_ports['+str(i)+'];\n')
      if options.dump_topology_file:
	topo_dump.write('SendPort '+str(i)+' -> R'+str(0)+':'+str(i)+'\n')
      if options.gen_graph and options.graph_nodes: # also include the endpoints
	dot.write('N'+str(i+options.uni_tree_outputs)+' -> R'+str(0)+' [ headlabel = "' + str(i) + '" ];\n')
    # Find first and last router id of last stage where nodes attach
    final_stage_rt_first_id = 0
    for i in range(num_stages):
      final_stage_rt_first_id += options.uni_tree_fanout**i
    print "final_stage_rt_first_id ", final_stage_rt_first_id
    final_stage_rt_last_id = final_stage_rt_first_id * options.uni_tree_fanout
    print "final_stage_rt_first_id ", final_stage_rt_last_id
    
    
    num_final_stage_rts = (final_stage_rt_last_id+1) - final_stage_rt_first_id;
    if(options.uni_tree_distribute_leaves): 
      for recv_port_id in range(options.uni_tree_outputs):
	o = final_stage_rt_first_id + get_uni_tree_distributed_rt(recv_port_id, num_stages, options.uni_tree_fanout);
	p = recv_port_id/(options.uni_tree_fanout**num_stages)
	links.write('recv_ports_ifaces['+str(recv_port_id)+'] = routers['+str(o)+'].out_ports['+str(p)+'];\n')
        if options.dump_topology_file:
	  topo_dump.write('RecvPort '+str(recv_port_id)+' -> R'+str(0)+':'+str(p)+'\n')
	if options.gen_graph and options.graph_nodes: # also include the endpoints
	  dot.write('R'+str(o)+' -> N'+str(recv_port_id)+' [ taillabel = "' + str(p) + '" ];\n')
	links.write('recv_ports_info_ifaces['+str(recv_port_id)+'] =  get_port_info_ifc('+str(recv_port_id)+');\n')
	recv_port_id += 1;
    else:
      recv_port_id = 0;
      for o in range(final_stage_rt_first_id, final_stage_rt_last_id+1):
	for p in range(options.uni_tree_fanout):
	  if(recv_port_id < options.uni_tree_outputs): # Stop once you've created enough output ports, even if the tree has more outputs
	    links.write('recv_ports_ifaces['+str(recv_port_id)+'] = routers['+str(o)+'].out_ports['+str(p)+'];\n')
	    if options.dump_topology_file:
	      topo_dump.write('RecvPort '+str(recv_port_id)+' -> R'+str(0)+':'+str(p)+'\n')
	    if options.gen_graph and options.graph_nodes: # also include the endpoints
	      dot.write('R'+str(o)+' -> N'+str(recv_port_id)+' [ taillabel = "' + str(p) + '" ];\n')
	    links.write('recv_ports_info_ifaces['+str(recv_port_id)+'] =  get_port_info_ifc('+str(recv_port_id)+');\n')
	    recv_port_id += 1;

    link_id = -1
    cur_rt = 0;
    rts_in_stage = 1;
    for stage in range(num_stages):

      for r in range(rts_in_stage):
	for l in range(options.uni_tree_fanout):
          link_id += 1;
	  dest_rt = options.uni_tree_fanout*cur_rt+l+1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(cur_rt)+'], '+str(l)+', routers['+str(dest_rt)+'], 0);\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(cur_rt)+':'+str(l)+' -> '+'R'+str(dest_rt)+':'+str(0)+'\n')
          if options.gen_graph: dot.write('R'+str(cur_rt)+' -> R'+str(dest_rt)+' [ taillabel = "' + str(l) + '", headlabel = "' + '0' + '" ];\n')
        cur_rt += 1;
      rts_in_stage *= options.uni_tree_fanout;

    
  else: # build up tree
    num_root_nodes = options.uni_tree_outputs
    num_leaf_nodes = options.uni_tree_inputs
    num_stages = int(math.ceil(math.log(num_leaf_nodes, options.uni_tree_fanout))) - 1  # counts link stages
    print "num_stages ",num_stages
    # Expose user send/receive ports
    for o in range(options.uni_tree_outputs):
      links.write('recv_ports_ifaces['+str(o)+'] = routers[0].out_ports['+str(o)+'];\n')
      if options.dump_topology_file:
	topo_dump.write('RecvPort '+str(o)+' -> R'+str(0)+':'+str(o)+'\n')
      if options.gen_graph and options.graph_nodes: # also include the endpoints
	dot.write('R'+str(0)+' -> N'+str(o)+' [ taillabel = "' + str(o) + '" ];\n')
      links.write('recv_ports_info_ifaces['+str(o)+'] =  get_port_info_ifc('+str(o)+');\n')
    # Find first and last router id of last stage where nodes attach
    final_stage_rt_first_id = 0
    for i in range(num_stages):
      final_stage_rt_first_id += options.uni_tree_fanout**i
    print "final_stage_rt_first_id ", final_stage_rt_first_id
    final_stage_rt_last_id = final_stage_rt_first_id * options.uni_tree_fanout
    print "final_stage_rt_first_id ", final_stage_rt_last_id


    num_final_stage_rts = (final_stage_rt_last_id+1) - final_stage_rt_first_id;
    if(options.uni_tree_distribute_leaves): 
      for send_port_id in range(options.uni_tree_inputs):
	o = final_stage_rt_first_id + get_uni_tree_distributed_rt(send_port_id, num_stages, options.uni_tree_fanout);
	p = send_port_id/(options.uni_tree_fanout**num_stages)
	links.write('send_ports_ifaces['+str(send_port_id)+'] = routers['+str(o)+'].in_ports['+str(p)+'];\n')
	if options.dump_topology_file:
	  topo_dump.write('SendPort '+str(send_port_id)+' -> R'+str(o)+':'+str(p)+'\n')
	if options.gen_graph and options.graph_nodes: # also include the endpoints
	  dot.write('N'+str(send_port_id+options.uni_tree_outputs)+' -> R'+str(o)+' [ headlabel = "' + str(p) + '" ];\n')
	send_port_id += 1;
    else:
      send_port_id = 0;
      for o in range(final_stage_rt_first_id, final_stage_rt_last_id+1):
	for p in range(options.uni_tree_fanout):
	  if(send_port_id < options.uni_tree_inputs): # Stop once you've created enough input ports, even if the tree has more outputs
	    links.write('send_ports_ifaces['+str(send_port_id)+'] = routers['+str(o)+'].in_ports['+str(p)+'];\n')
	    if options.dump_topology_file:
	      topo_dump.write('SendPort '+str(send_port_id)+' -> R'+str(o)+':'+str(p)+'\n')
	    if options.gen_graph and options.graph_nodes: # also include the endpoints
	      dot.write('N'+str(send_port_id+options.uni_tree_outputs)+' -> R'+str(o)+' [ headlabel = "' + str(p) + '" ];\n')
	    send_port_id += 1;

    link_id = -1
    cur_rt = 0;
    rts_in_stage = 1;
    for stage in range(num_stages):
      for r in range(rts_in_stage):
	for l in range(options.uni_tree_fanout):
          link_id += 1;
	  src_rt = options.uni_tree_fanout*cur_rt+l+1;
          links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(src_rt)+'], 0, routers['+str(cur_rt)+'], '+str(l)+');\n')
          if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(src_rt)+':'+str(0)+' -> '+'R'+str(cur_rt)+':'+str(l)+'\n')
          if options.gen_graph: dot.write('R'+str(src_rt)+' -> R'+str(cur_rt)+' [ taillabel = "' + '0' + '", headlabel = "' + str(l) + '" ];\n')
        cur_rt += 1;
      rts_in_stage *= options.uni_tree_fanout;

  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id+1


def gen_uni_tree_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for uni-tree topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  num_root_nodes = 0;
  num_leaf_nodes = 0;

  build_down_tree = True;
  if (options.topology == "uni_tree_down"):
    build_down_tree = True;
  elif (options.topology == "uni_tree_up"):
    build_down_tree = False;
  elif (options.uni_tree_inputs < options.uni_tree_outputs):
    build_down_tree = True;
  else: 
    build_down_tree = False;

  #if(options.uni_tree_inputs < options.uni_tree_outputs): # Build down tree
  if(build_down_tree): # Build down tree
    num_root_nodes = options.uni_tree_inputs
    num_leaf_nodes = options.uni_tree_outputs
    num_stages = int(math.ceil(math.log(num_leaf_nodes, options.uni_tree_fanout))) - 1  # counts link stages
    print "num_stages ",num_stages
    
    cur_rt = 0;
    rts_in_stage = 1;
    for stage in range(num_stages+1):
      for r in range(rts_in_stage):
	filename = options.output_dir + '/' + file_prefix + str(cur_rt) + '.hex'
	try: rt = open(filename, 'w');
	except IOError: print "Could not open file " + filename; sys.exit(-1);

	for dst in range(options.uni_tree_outputs):
          if(options.uni_tree_distribute_leaves):  #distribute leaves
	    out_port = dst / ( options.uni_tree_fanout**(stage) ) % options.uni_tree_fanout
	  else:
	    out_port = dst / ( options.uni_tree_fanout**(num_stages-stage) ) % options.uni_tree_fanout
	  rt.write('%x\n' % out_port );
	  if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+ str(out_port)
          if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(out_port)+'\n');
        cur_rt += 1;
	rt.close();
	if options.verbose: print 'Generated routing file: ' + filename
      rts_in_stage *= options.uni_tree_fanout;
  else: # Build up tree
    num_root_nodes = options.uni_tree_outputs
    num_leaf_nodes = options.uni_tree_inputs
    num_stages = int(math.ceil(math.log(num_leaf_nodes, options.uni_tree_fanout))) - 1  # counts link stages
    print "num_stages ",num_stages
    
    cur_rt = 0;
    rts_in_stage = 1;
    for stage in range(num_stages+1):
      for r in range(rts_in_stage):
	filename = options.output_dir + '/' + file_prefix + str(cur_rt) + '.hex'
	try: rt = open(filename, 'w');
	except IOError: print "Could not open file " + filename; sys.exit(-1);

        if(stage == 0):  # root router
	  for dst in range(options.uni_tree_outputs):
	    rt.write('%x\n' % dst );
	    if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+ str(dst)
            if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(dst)+'\n');
	else:
	  for dst in range(options.uni_tree_outputs):
	    rt.write('%x\n' % 0 );
	    if options.verbose: print 'route:'+str(cur_rt)+'->'+str(dst)+':'+ str(0)
            if options.dump_routing_file: route_dump.write('R'+str(cur_rt)+': '+str(dst)+' -> '+str(0)+'\n');

        cur_rt += 1;
	rt.close();
	if options.verbose: print 'Generated routing file: ' + filename
      rts_in_stage *= options.uni_tree_fanout;

  # Hack - set num_routers to actual number of routers
  # Find number of routers
  actual_routers = 0
  for i in range(num_stages+1):
    actual_routers += options.uni_tree_fanout**i
  options.num_routers = actual_routers;

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename


#######################################
## xbar
def gen_xbar_links(links, dot_filename, dump_topology_filename):
  """Generates links for xbar topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo");
 
  link_id = -1;
  for r in range(options.num_routers):
    link_id = link_id + 1;
    next_router = (r+1)%options.num_routers;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(r)+'], 1, routers['+str(next_router)+'], 1);\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(r)+':'+str(1)+' -> '+'R'+str(next_router)+':'+str(1)+'\n')
    if options.gen_graph: dot.write('R'+str(r)+' -> R'+str(next_router)+' [ taillabel = "' + '1' + '", headlabel = "' + '1' + '" ];\n')
  
  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_xbar_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for xbar topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try:
      rt = open(filename, 'w')
    except IOError:
      print "Could not open file " + filename
      sys.exit(-1)

    for dst in range(options.num_routers):
      if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	rt.write('%x\n' % (0) );
	#str.format(  );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
      else:           # packet is not for me, send to next router, i.e. out_port 1
        #next_router = (src+1)%options.num_routers;
	rt.write('%x\n' % (1) );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'1'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(1)+'\n');
  
    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename
  
  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename


#######################################
## Ideal
def gen_ideal_links(links, dot_filename, dump_topology_filename):
  """Generates links for ideal topology"""
  global options, args

  # Dump topology file
  if options.dump_topology_file:
    try: topo_dump = open(dump_topology_filename, 'w');
    except IOError: print "Could not open file " + dump_topology_filename; sys.exit(-1);
  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo");
 
  link_id = -1;
  for r in range(options.num_routers):
    link_id = link_id + 1;
    next_router = (r+1)%options.num_routers;
    links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+str(r)+'], 1, routers['+str(next_router)+'], 1);\n')
    if options.dump_topology_file: topo_dump.write('RouterLink '+'R'+str(r)+':'+str(1)+' -> '+'R'+str(next_router)+':'+str(1)+'\n')
    if options.gen_graph: dot.write('R'+str(r)+' -> R'+str(next_router)+' [ taillabel = "' + '1' + '", headlabel = "' + '1' + '" ];\n')
  
  # Close topology dump file
  if options.dump_topology_file: topo_dump.close();
  if options.verbose and options.dump_topology_file: print 'Dumped topology file: ' + dump_topology_filename
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_ideal_routing(file_prefix, dump_routing_filename):
  """Populates routing tables for ideal topology"""
  global options, args
  
  # Dump routing file
  if options.dump_routing_file:
    try: route_dump = open(dump_routing_filename, 'w');
    except IOError: print "Could not open file " + dump_routing_filename; sys.exit(-1);

  link_id = -1;
  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try:
      rt = open(filename, 'w')
    except IOError:
      print "Could not open file " + filename
      sys.exit(-1)

    for dst in range(options.num_routers):
      if src == dst:  # packet is destined to me, extract from router, i.e. out_port 0
	rt.write('%x\n' % (0) );
	#str.format(  );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'0'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(0)+'\n');
      else:           # packet is not for me, send to next router, i.e. out_port 1
        #next_router = (src+1)%options.num_routers;
	rt.write('%x\n' % (1) );
        if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+'1'
        if options.dump_routing_file: route_dump.write('R'+str(src)+': '+str(dst)+' -> '+str(1)+'\n');
  
    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename

  # Close routing dump file
  if options.dump_routing_file: route_dump.close();
  if options.verbose and options.dump_routing_file: print 'Dumped routing file: ' + dump_routing_filename
 

############################################################
## parse_custom_topology
def parse_custom_topology(custom_topology_file, send_ports, recv_ports, router_links, topology_info):
  """Parses custom topology file"""
  global options, args
  reverse_router_links = dict()
  try: c_topology = open(options.custom_topology, 'r');
  except IOError: print "Could not open custom topology file " + options.custom_topology; sys.exit(-1);

  for i, l in enumerate(c_topology):
    m = re.match('\s*$', l) # only whitespace until end of likne, i.e. empty line
    if(m is not None):  # whitespace
      # skip whitespace
      continue
    m = re.match('\s*#', l) # comment
    if(m is not None):  # comment
      #print 'Skipping comment on line', i
      continue
    #m = re.match('SendPort\s+(\d+)\s*->\s*R(\d+)\s*:\s*(\d+)', l)
    m = re.match('\s*SendPort\s+(?P<send_port>\d+)\s*->\s*R(?P<rt>\d+)\s*:\s*(?P<port>\d+)', l)
    if( m is not None ):
      send_port = m.group('send_port');
      rt = m.group('rt');
      port = m.group('port');
      #if options.verbose: print 'Attaching Send Port %s to R%s:%s' % (m.group(1), m.group(2), m.group(3))
      if options.verbose: print 'Attaching Send Port %s to R%s:%s' % (send_port, rt, port)
      #send_ports[m.group(1)] = [ m.group(2), m.group(3) ]
      send_ports[send_port] = [rt, port]
      #if options.verbose: print 'Attaching Send Port ',m.group(1),' to R',m.group(2),':',m.group(3) 

      # Update topology info
      if(topology_info['num_routers'] < (int(rt)+1)): topology_info['num_routers'] = int(rt)+1; # update total number of routers
      if(topology_info['max_num_in_ports'] < (int(port)+1)): topology_info['max_num_in_ports'] = int(port)+1; # update max number of input ports
      if(topology_info['max_send_ports'] < (int(send_port)+1)): topology_info['max_send_ports'] = int(send_port)+1; # update max number of send ports
      continue
    #m = re.match('\s*RecvPort\s+(\d+)\s*->\s*R(\d+)\s*:\s*(\d+)', l)
    m = re.match('\s*RecvPort\s+(?P<recv_port>\d+)\s*->\s*R(?P<rt>\d+)\s*:\s*(?P<port>\d+)', l)
    if( m is not None ): 
      recv_port = m.group('recv_port');
      rt = m.group('rt');
      port = m.group('port');
      #if options.verbose: print 'Attaching Recv Port %s to R%s:%s' % (m.group(1), m.group(2), m.group(3))
      if options.verbose: print 'Attaching Recv Port %s to R%s:%s' % (recv_port, rt, port)
      #recv_ports[m.group(1)] = [ m.group(2), m.group(3) ]
      recv_ports[recv_port] = [rt, port]
      
      # Update topology info
      if(topology_info['num_routers'] < (int(rt)+1)): topology_info['num_routers'] = int(rt)+1; # update total number of routers
      if(topology_info['max_num_out_ports'] < (int(port)+1)): topology_info['max_num_out_ports'] = int(port)+1; # update max number of input ports
      if(topology_info['max_recv_ports'] < (int(recv_port)+1)): topology_info['max_recv_ports'] = int(recv_port)+1; # update max number of send ports
      continue
    m = re.match('\s*SendRecvPort\s+(?P<user_port>\d+)\s*->\s*R(?P<rt>\d+)\s*:\s*(?P<port>\d+)', l)
    if( m is not None ):
      user_port = m.group('user_port');
      rt = m.group('rt');
      port = m.group('port');
      #if options.verbose: print 'Attaching Send Port %s to R%s:%s' % (m.group(1), m.group(2), m.group(3))
      if options.verbose: print 'Attaching Send Port %s to R%s:%s' % (user_port, rt, port)
      send_ports[user_port] = [rt, port]
      if options.verbose: print 'Attaching Recv Port %s to R%s:%s' % (user_port, rt, port)
      recv_ports[user_port] = [rt, port]
      #send_ports[m.group(1)] = [ m.group(2), m.group(3) ]
      #if options.verbose: print 'Attaching Send Port ',m.group(1),' to R',m.group(2),':',m.group(3) 

      # Update topology info
      if(topology_info['num_routers'] < (int(rt)+1)): topology_info['num_routers'] = int(rt)+1; # update total number of routers
      if(topology_info['max_num_in_ports'] < (int(port)+1)): topology_info['max_num_in_ports'] = int(port)+1; # update max number of input ports
      if(topology_info['max_send_ports'] < (int(user_port)+1)): topology_info['max_send_ports'] = int(user_port)+1; # update max number of send ports
      if(topology_info['max_recv_ports'] < (int(user_port)+1)): topology_info['max_recv_ports'] = int(user_port)+1; # update max number of send ports
      continue
    m = re.match('\s*RouterLink\s+R(?P<src_rt>\d+)\s*:\s*(?P<src_port>\d+)\s*->\s*R(?P<dst_rt>\d+)\s*:\s*(?P<dst_port>\d+)', l)
    if( m is not None ):
      src_rt = m.group('src_rt');
      src_port = m.group('src_port');
      dst_rt = m.group('dst_rt');
      dst_port = m.group('dst_port');
      #if options.verbose: print 'Connecting R%s:%s to R%s:%s' % (m.group(1), m.group(2), m.group(3), m.group(4))
      if options.verbose: print 'Connecting R%s:%s to R%s:%s' % (src_rt, src_port, dst_rt, dst_port)
      if(src_rt not in router_links): router_links[src_rt] = dict();
      # check if connection already exists
      if(src_port in router_links[src_rt]): # Overwriting connections
	exist_dest = router_links[src_rt][src_port]
	#print 'Warning: R%s:%s was already connected to R%s:%s, but will now be connected to R%s:R%s' % (m.group(1), m.group(2), exist_dest[0], exist_dest[1], m.group(3), m.group(4))
	print 'Warning: R%s:%s was already connected to R%s:%s, but will now be connected to R%s:R%s' % (src_rt, src_port, exist_dest[0], exist_dest[1], dst_rt, dst_port)

      # Add link
      #router_links[m.group(1)][m.group(2)] = [ m.group(3), m.group(4) ]
      router_links[src_rt][src_port] = [ dst_rt, dst_port ]

      # Update topology info
      if(topology_info['num_routers'] < (int(src_rt)+1)): topology_info['num_routers'] = int(src_rt)+1; # update total number of routers
      if(topology_info['num_routers'] < (int(dst_rt)+1)): topology_info['num_routers'] = int(dst_rt)+1; # update total number of routers
      if(topology_info['max_num_out_ports'] < (int(src_port)+1)): topology_info['max_num_out_ports'] = int(src_port)+1; # update max number of input ports
      if(topology_info['max_num_in_ports'] < (int(dst_port)+1)): topology_info['max_num_in_ports'] = int(dst_port)+1; # update max number of input ports

      # For sanity check
      if(dst_rt not in reverse_router_links): reverse_router_links[dst_rt] = dict();
      reverse_router_links[dst_rt][dst_port] = [ src_rt, src_port ]

      continue
    print 'Error parsing custom_topology_file (%s) at line %d: "%s"' % (custom_topology_file, i, l[:-1])
    sys.exit(-1);

  # Sanity checks
  for r in range(topology_info['num_routers']):
    if( ( str(r) not in router_links ) and ( str(r) not in reverse_router_links ) ): # A router that is unconnected
      print 'Error: Missing topology info for router %d. Router IDs must be consecutive.' % (r)
      sys.exit(-1);

  for s in range(topology_info['max_send_ports']):
    if( str(s) not in send_ports ): # A non-existent send port
      print 'Error: Missing topology info for send port %d. Send port IDs must be consecutive.' % (s)
      sys.exit(-1);

  for r in range(topology_info['max_recv_ports']):
    if( str(r) not in recv_ports ): # A non-existent recv port
      print 'Error: Missing topology info for recv port %d. Recv port IDs must be consecutive.' % (r)
      sys.exit(-1);

  if(int(topology_info['max_send_ports']) < 1):
      print 'Error: No send ports! A network requires at least one send port.'
      sys.exit(-1);
  
  if(int(topology_info['max_recv_ports']) < 1):
      print 'Error: No receive ports! A network requires at least one receive port.'
      sys.exit(-1);

  if options.verbose: print 'Total number of routers:', topology_info['num_routers']
  if options.verbose: print 'Max number of in ports:', topology_info['max_num_in_ports']
  if options.verbose: print 'Max number of out ports:', topology_info['max_num_out_ports']
  if options.verbose: print 'Max number of send ports:', topology_info['max_send_ports']
  if options.verbose: print 'Max number of recv ports:', topology_info['max_recv_ports']



############################################################
## parse_custom_topology
def parse_custom_routing(custom_routing_file, topology_info):
  """Parses custom routing file"""
  global options, args
  try: c_routing = open(custom_routing_file, 'r');
  except IOError: print "Could not open custom routing file " + options.custom_routing; sys.exit(-1);
  
  # Initialize routing tables
  # routing = int(topology_info['num_routers']) * [int(topology_info['max_dests']) * [-1] ] # This does not work! Routing entries are aliases and overwrite each other
  routing = []
  for r in range(int(topology_info['num_routers'])):
    routing.insert(r, int(topology_info['max_dests']) * [-1] )

  for i, l in enumerate(c_routing):
    m = re.match('\s*$', l) # only whitespace until end of likne, i.e. empty line
    if(m is not None):  # whitespace
      # skip whitespace
      continue
    m = re.match('\s*#', l) # comment
    if(m is not None):  # comment
      #print 'Skipping comment on line', i
      continue
    #m = re.match('SendPort\s+(\d+)\s*->\s*R(\d+)\s*:\s*(\d+)', l)
    m = re.match('\s*R(?P<rt>\d+)\s*:\s*(?P<dst>\d+)\s*->\s*(?P<port>\d+)', l)
    if( m is not None ):
      rt = m.group('rt');
      dst = m.group('dst');
      port = m.group('port');
      if(int(rt) >= topology_info['num_routers']): print 'Routing entry for non-existent router %s at line %d: "%s"' % (rt, i, l[:-1]); sys.exit(-1)
      if(int(dst) >= topology_info['max_dests']): print 'Routing entry for router %s has non-existent destination (%s) at line %d: "%s"' % (rt, dst, i, l[:-1]); sys.exit(-1)
      if(int(port) >= topology_info['max_num_out_ports']): print 'Routing entry for router %s has non-existent out port (%s) at line %d: "%s"' % (rt, port, i, l[:-1]); sys.exit(-1)
      
      if( routing[int(rt)][int(dst)] != -1 ): print 'Warning: Overwriting previous routing entry (R%s:%s->%d) with new routing entry (R%s:%s->%s)' % ( rt, dst, routing[int(rt)][int(dst)], rt, dst, port)
      #if options.verbose: print 'Attaching Send Port %s to R%s:%s' % (m.group(1), m.group(2), m.group(3))
      if options.verbose: print 'New routing entry for router %s: dst:%s -> out_port:%s' % (rt, dst, port)
      routing[int(rt)][int(dst)] = int(port)

      continue
    print 'Error parsing routing_topology_file (%s) at line %d: "%s"' % (routing_topology_file, i, l[:-1])
    sys.exit(-1);

  # Sanity check
  for r in range(len(routing)):
    for dst in range(len(routing[r])):
      if(routing[r][dst] == -1):
	print 'Warning: Router %d has undefined output port for packets with destination %d. Will use default output port (0).' % (r, dst)
	routing[r][dst] = 0

  return routing

#######################################
## Custom
def gen_custom_links(send_ports, recv_ports, router_links, topology_info, links, dot_filename):
  """Generates links for custom topology"""
  global options, args

  # Generate graphviz .gv file
  if options.gen_graph: dot = prepare_graph_file(dot_filename + ".gv", "circo", topology_info);

# Expose user send/receive and info ports
  for s, rp in send_ports.items():
    links.write('send_ports_ifaces['+s+'] = routers['+rp[0]+'].in_ports['+rp[1]+'];\n')
    if options.graph_nodes: dot.write('N'+s+' -> R'+rp[0]+' [ headlabel = "' + rp[1] + '" ];\n')
  for r, rp in recv_ports.items():
    links.write('recv_ports_ifaces['+r+'] = routers['+rp[0]+'].out_ports['+rp[1]+'];\n')
    if options.graph_nodes: dot.write('R'+rp[0]+' -> N'+r+' [ taillabel = "' + rp[1] + '" ];\n')
    links.write('recv_ports_info_ifaces['+r+'] =  get_port_info_ifc('+r+');\n')
  #for r in range(max(topology_info['max_send_ports'], topology_info['max_recv_ports'])):
  #for r in range(options.num_routers):
  #  links.write('router_info_ifaces['+str(r)+'] =  get_router_info_ifc('+str(r)+');\n')
  
  link_id = 0;
  for src_rt in router_links.keys():
    for src_port in router_links[src_rt].keys():
      tmp = router_links[src_rt][src_port]
      dst_rt = tmp[0]
      dst_port = tmp[1]
      links.write('links['+str(link_id)+'] <- mkConnectPorts(routers['+src_rt+'], '+src_port+', routers['+dst_rt+'], '+dst_port+');\n')
      if options.gen_graph: dot.write('R'+src_rt+' -> R'+dst_rt+' [ taillabel = "' + src_port + '", headlabel = "' + dst_port + '" ];\n')
      link_id = link_id + 1;
  
  # Close graphviz file
  if options.gen_graph: dot.write('}\n'); dot.close();
  if options.verbose and options.gen_graph: print 'Generated graphviz file: ' + dot_filename + ".gv"
  
  return link_id

def gen_custom_routing(routing, topology_info, file_prefix):
  """Populates routing tables for custom topology"""
  global options, args
  for src in range(options.num_routers):
    filename = options.output_dir + '/' + file_prefix + str(src) + '.hex'
    try: rt = open(filename, 'w');
    except IOError: print "Could not open file " + filename; sys.exit(-1);

    for dst in range(int(topology_info['max_dests'])):
      out_port = routing[src][dst]
      rt.write('%x\n' % (out_port) );
      if options.verbose: print 'route:'+str(src)+'->'+str(dst)+':'+str(out_port)
  
    rt.close();
    if options.verbose: print 'Generated routing file: ' + filename



############################################################
## gen_net_parameters
def gen_net_parameters(num_user_send_ports, num_user_recv_ports, num_in_ports, num_out_ports, num_links, cut, filename = 'network_parameters.bsv'):
  """Generates network parameters file"""
  global options, args
  filename = options.output_dir + '/' + filename
  try:
    parameters = open(filename, 'w')
  except IOError:
    print "Could not open file " + filename
    sys.exit(-1)

  #parameters.write('`define NUM_TOTAL_USER_PORTS ' + str(num_total_user_ports) + '\n')
  parameters.write('`define NUM_USER_SEND_PORTS ' + str(num_user_send_ports) + '\n')
  parameters.write('`define NUM_USER_RECV_PORTS ' + str(num_user_recv_ports) + '\n')
  parameters.write('`define NUM_ROUTERS ' + str(options.num_routers) + '\n')
  parameters.write('`define NUM_IN_PORTS ' + str(num_in_ports) + '\n')
  parameters.write('`define NUM_OUT_PORTS ' + str(num_out_ports) + '\n')
  parameters.write('`define CREDIT_DELAY 1\n')
  parameters.write('`define NUM_VCS ' + str(options.num_vcs) + '\n')
  parameters.write('`define ALLOC_TYPE ' + str(options.alloc_type) + '\n')
  parameters.write('`define USE_VIRTUAL_LINKS ' + str(options.use_virtual_links) + '\n')
  parameters.write('`define FLIT_BUFFER_DEPTH ' + str(options.flit_buffer_depth) + '\n')
  parameters.write('`define FLIT_DATA_WIDTH ' + str(options.flit_data_width) + '\n')
  parameters.write('`define NUM_LINKS ' + str(num_links) + '\n')
  parameters.write('`define NETWORK_CUT ' + str(cut) + '\n')
  parameters.write('`define XBAR_LANES ' + str(options.xbar_lanes) + '\n')
  if (options.router_type == "voq"):
    parameters.write('`define USE_VOQ_ROUTER True\n')
  elif (options.router_type == "iq"):
    parameters.write('`define USE_IQ_ROUTER True\n')
  if(options.dbg):
    parameters.write('`define EN_DBG True\n')
  if(options.dbg_detail):
    parameters.write('`define EN_DBG True\n')
    parameters.write('`define EN_DBG_DETAIL True\n')
  
  if(options.pipeline_core):
    parameters.write('`define PIPELINE_CORE True\n')
  else:
    parameters.write('`define PIPELINE_CORE False\n')
  if(options.pipeline_alloc):
    parameters.write('`define PIPELINE_ALLOCATOR True\n')
  else:
    parameters.write('`define PIPELINE_ALLOCATOR False\n')
  if(options.pipeline_links):
    parameters.write('`define PIPELINE_LINKS True\n')
  else:
    parameters.write('`define PIPELINE_LINKS False\n')

  if options.verbose: print 'Generated parameters file: ' + filename

############################################################
## main
def main ():
    # Default values for parameters
    global options, args
    #if (len(sys.argv) < 3):
    #  print "Error at least 2 args expected!";
    #  exit();
    #for arg in sys.argv:
    #  print arg;

    if options.verbose: 
      print '================ Options ================'
      options_dict = vars(options)
      for o in options_dict:
        print o,':',options_dict[o]

    #num_total_user_ports = options.num_routers
    num_user_send_ports = options.num_routers
    num_user_recv_ports = options.num_routers
    max_num_in_ports = -1
    max_num_out_ports = -1
    num_links = -1

    # Generated Files
    network_parameters_file = ''
    network_links_file = ''
    network_routing_file_prefix = ''

    #### Derived options ####
    if (options.voq_routers):
      options.router_type = "voq";
    if (options.peek_flow_control):
      options.flow_control_type = "peek";
    # Graph_nodes implies gen_graph
    if (options.graph_nodes):  
      options.gen_graph = True; 

    #### Global Checks for all topologies ####
    if (options.router_type == "voq"):
      if (not (options.flow_control_type == "peek")):
        print 'Warning: VOQ routers require the use of "peek" flow control. Setting flow control to "peek".'
	options.flow_control_type = True;
      if (options.num_vcs > 1):
        print 'Warning: VOQ routers do not support multiple Virtual Channels (VCs). Setting num_vcs to 1.'
	options.num_vcs = 1;

    else:  # VC-based routers
      if (options.num_vcs == 1):
        print 'Warning: VC-based routers require at least two Virtual Channels (VCs). Setting num_vcs to 2.'
	options.num_vcs = 2;

    # Prefix for generated files (some topologies might add more fields to this - custom overrides this)
    file_prefix = '';
    if(options.file_prefix == ''):
      file_prefix = options.topology + '_' + str(options.num_routers) + 'RTs_' + str(options.num_vcs) + 'VCs_' + str(options.flit_buffer_depth) + 'BD_' + str(options.flit_data_width) + 'DW_' + str(options.alloc_type) + 'Alloc'
    else:
      file_prefix = options.file_prefix;

    #### single switch ####
    if options.topology == 'single_switch':
      # Set topology-specific parameters here
      max_num_in_ports = options.num_routers
      max_num_out_ports = options.num_routers

    #### line ####
    elif options.topology == 'line':
      # Set topology-specific parameters here
      max_num_in_ports = 3
      max_num_out_ports = 3
    
    #### ring ####
    elif options.topology == 'ring':
      # Set topology-specific parameters here
      max_num_in_ports = 2
      max_num_out_ports = 2

    elif options.topology == 'ideal':
      max_num_in_ports = 2
      max_num_out_ports = 2 

    elif options.topology == 'xbar':
      max_num_in_ports = 2
      max_num_out_ports = 2  
 
    #### double-ring ####
    elif options.topology == 'double_ring':
      # Set topology-specific parameters here
      max_num_in_ports = 3
      max_num_out_ports = 3
    
    #### star ####
    elif options.topology == 'star':
      # Check if star parameters are valid
      if(options.num_routers > 16):
	print 'Error:',options.topology, 'topology only supports up to 16 routers.'
	sys.exit(1)

      num_user_send_ports = options.num_routers-1
      num_user_recv_ports = options.num_routers-1

      # Set topology-specific parameters here
      max_num_in_ports = options.num_routers-1   # central node is connected to num_routers-1 other routers, plus local port
      max_num_out_ports = options.num_routers-1  # central node is connected to num_routers-1 other routers, plus local port
    
    #### mesh ####
    elif options.topology == 'mesh':
      # Check if mesh parameters are valid
      # if num_routers is perfect square and routers_per_row, routers_per_column were not specified, set them here.
      num_routers_sqrt = (int)( math.floor(math.sqrt(options.num_routers)) )
      num_routers_is_square = (options.num_routers == num_routers_sqrt**2)
      if(num_routers_is_square and options.routers_per_row == -1 and options.routers_per_column == -1):
        if options.verbose: print 'num_routers(%d) is perfect square; setting options.routers_per_row and options.routers_per_column to sqrt(num_routers) to build square mesh.' % (options.num_routers)
	options.routers_per_row    = num_routers_sqrt
	options.routers_per_column = num_routers_sqrt

      if(options.routers_per_row * options.routers_per_column != options.num_routers):
	print 'Error:',options.topology, 'topology requires that routers_per_row(%d) and routers_per_column(%d) are specified and that their product is equal to num_routers(%d).' % (options.routers_per_row, options.routers_per_column, options.num_routers)
	sys.exit(1)

      # Set topology-specific parameters here
      if(options.expose_unused_ports):
        num_total_user_ports = options.num_routers + 2*options.routers_per_row + 2*options.routers_per_column;
        num_user_send_ports = num_total_user_ports
        num_user_recv_ports = num_total_user_ports
      max_num_in_ports = 5
      max_num_out_ports = 5
      # Augment default prefix to include routers per row/column
      if(options.file_prefix == ''):
        file_prefix = file_prefix + '_' + str(options.routers_per_row) + 'RTsPerRow_' + str(options.routers_per_column) + 'RTsPerCol'

    
    #### torus ####
    elif options.topology == 'torus':
      # Check if torus parameters are valid
      # if num_routers is perfect square and routers_per_row, routers_per_column were not specified, set them here.
      num_routers_sqrt = (int)( math.floor(math.sqrt(options.num_routers)) )
      num_routers_is_square = (options.num_routers == num_routers_sqrt**2)
      if(num_routers_is_square and options.routers_per_row == -1 and options.routers_per_column == -1):
        if options.verbose: print 'num_routers(%d) is perfect square; setting options.routers_per_row and options.routers_per_column to sqrt(num_routers) to build square torus.' % (options.num_routers)
	options.routers_per_row    = num_routers_sqrt
	options.routers_per_column = num_routers_sqrt

      if(options.routers_per_row * options.routers_per_column != options.num_routers):
	print 'Error:',options.topology, 'topology requires that routers_per_row(%d) and routers_per_column(%d) are specified and that their product is equal to num_routers(%d).' % (options.routers_per_row, options.routers_per_column, options.num_routers)
	sys.exit(1)

      # Set topology-specific parameters here
      max_num_in_ports = 5
      max_num_out_ports = 5
      # Augment default prefix to include routers per row/column
      if(options.file_prefix == ''):
        file_prefix = file_prefix + '_' + str(options.routers_per_row) + 'RTsPerRow_' + str(options.routers_per_column) + 'RTsPerCol'

    
    #### fully-connected ####
    elif options.topology == 'fully_connected':
      # Check if fully-connected parameters are valid
      if(options.num_routers > 16):
	print 'Error:',options.topology, 'topology only supports up to 16 routers.'
	sys.exit(1)

      # Set topology-specific parameters here
      max_num_in_ports = options.num_routers   # central node is connected to num_routers-1 other routers, plus local port
      max_num_out_ports = options.num_routers  # central node is connected to num_routers-1 other routers, plus local port

    #### fat tree ####
    elif options.topology == 'fat_tree':
      # Check if fat tree parameters are valid
      num_is_power_of_two = options.num_routers != 0 and ((options.num_routers & (options.num_routers - 1)) == 0)
      num_routers_sqrt = (int)( math.floor(math.sqrt(options.num_routers)) )
      num_routers_is_square = (options.num_routers == num_routers_sqrt**2)
      if(not num_is_power_of_two):
	print 'Error:',options.topology, 'topology requires that num_routers is a power of two.'
	sys.exit(1)

      # Set topology-specific parameters here
      max_num_in_ports = 4   # only fat tree based on 4x4 routers supported for now
      max_num_out_ports = 4  # only fat tree based on 4x4 routers supported for now

    #### butterfly ####
    elif options.topology == 'butterfly':
      # Check if butterfly parameters are valid
      num_is_power_of_two = options.num_routers != 0 and ((options.num_routers & (options.num_routers - 1)) == 0)
      num_routers_sqrt = (int)( math.floor(math.sqrt(options.num_routers)) )
      num_routers_is_square = (options.num_routers == num_routers_sqrt**2)
      if(not num_is_power_of_two):
	print 'Error:',options.topology, 'topology requires that num_routers is a power of two.'
	sys.exit(1)

      # Set topology-specific parameters here
      max_num_in_ports = 2   # only 2-ary butterfly topology based on 2x2 routers supported for now
      max_num_out_ports = 2  # only 2-ary butterfly topology based on 2x2 routers supported for now

    #### single switch ####
    elif options.topology == 'uni_single_switch':
      # Set topology-specific parameters here
      max_num_in_ports = options.send_endpoints;
      max_num_out_ports = options.recv_endpoints;
      num_user_send_ports = options.uni_tree_inputs
      num_user_recv_ports = options.uni_tree_outputs

    #### aggregation uni-directional tree ####
    elif options.topology == 'uni_tree_up': 
      # Check if fat tree parameters are valid
         
      num_leaf_nodes = options.uni_tree_inputs;
      if(num_leaf_nodes > 512): 
	print 'Error',options.topology, 'topology only supports up to 512 leaf nodes.'
	sys.exit(1)

      if(options.uni_tree_fanout < 2):  #automatically set fanout, default fan_out is 4
	if(num_leaf_nodes <= 4):
	  options.uni_tree_fanout = num_leaf_nodes
	elif(num_leaf_nodes <= 16):
	  options.uni_tree_fanout = int(math.ceil(math.pow(num_leaf_nodes, 1.0/2.0)));
	elif(num_leaf_nodes <= 256):
	  options.uni_tree_fanout = int(math.ceil(math.pow(num_leaf_nodes, 1.0/3.0)));
	print 'Warning',options.topology, 'topology requires that uni_tree_fanout is at least two. Setting uni_tree_fanout to ', options.uni_tree_fanout 

      # corner-case for very small uni_tree
      if(options.uni_tree_inputs < options.uni_tree_fanout and options.uni_tree_outputs < options.uni_tree_fanout): 
	max_in_out =  max(options.uni_tree_inputs, options.uni_tree_outputs);
        print "Warning: uni_tree topology requires that uni_tree_fanout is not larger than both uni_tree_inputs and uni_tree_outpus.\n  Setting uni_tree_fanout to (",max_in_out,")."
        options.uni_tree_fanout = max_in_out;

      # Override file_prefix
      if(options.file_prefix == ''):
        file_prefix = options.topology + '_' + str(options.uni_tree_inputs) + 'INs_' + str(options.uni_tree_outputs) + 'OUTs_' + str(options.uni_tree_fanout) + 'FANOUT_' + str(options.num_vcs) + 'VCs_' + str(options.flit_buffer_depth) + 'BD_' + str(options.flit_data_width) + 'DW_' + str(options.alloc_type) + 'Alloc'
      # Set topology-specific parameters here
      num_user_send_ports = options.uni_tree_inputs
      num_user_recv_ports = options.uni_tree_outputs
      max_num_in_ports = options.uni_tree_fanout  
      max_num_out_ports = options.uni_tree_outputs  

#      if(options.uni_tree_inputs < options.uni_tree_outputs): # Build down tree
#	print 'Error',options.topology, 'topology requires that uni_tree_inputs >= uni_tree_outputs.'
#	sys.exit(1)

    #### distribution uni-directional tree ####
    elif options.topology == 'uni_tree_down': 
      # Check if fat tree parameters are valid
         
      num_leaf_nodes = options.uni_tree_inputs;
      if(num_leaf_nodes > 512): 
	print 'Error',options.topology, 'topology only supports up to 512 leaf nodes.'
	sys.exit(1)

      if(options.uni_tree_fanout < 2):  #automatically set fanout, default fan_out is 4
	if(num_leaf_nodes <= 4):
	  options.uni_tree_fanout = num_leaf_nodes
	elif(num_leaf_nodes <= 16):
	  options.uni_tree_fanout = int(math.ceil(math.pow(num_leaf_nodes, 1.0/2.0)));
	elif(num_leaf_nodes <= 256):
	  options.uni_tree_fanout = int(math.ceil(math.pow(num_leaf_nodes, 1.0/3.0)));
	print 'Warning',options.topology, 'topology requires that uni_tree_fanout is at least two. Setting uni_tree_fanout to ', options.uni_tree_fanout 

      # corner-case for very small uni_tree
      if(options.uni_tree_inputs < options.uni_tree_fanout and options.uni_tree_outputs < options.uni_tree_fanout): 
	max_in_out =  max(options.uni_tree_inputs, options.uni_tree_outputs);
        print "Warning: uni_tree topology requires that uni_tree_fanout is not larger than both uni_tree_inputs and uni_tree_outpus.\n  Setting uni_tree_fanout to (",max_in_out,")."
        options.uni_tree_fanout = max_in_out;

      # Override file_prefix
      if(options.file_prefix == ''):
        file_prefix = options.topology + '_' + str(options.uni_tree_inputs) + 'INs_' + str(options.uni_tree_outputs) + 'OUTs_' + str(options.uni_tree_fanout) + 'FANOUT_' + str(options.num_vcs) + 'VCs_' + str(options.flit_buffer_depth) + 'BD_' + str(options.flit_data_width) + 'DW_' + str(options.alloc_type) + 'Alloc'
      # Set topology-specific parameters here
      num_user_send_ports = options.uni_tree_inputs
      num_user_recv_ports = options.uni_tree_outputs
      max_num_in_ports = options.uni_tree_inputs
      max_num_out_ports = options.uni_tree_fanout 

#      if(options.uni_tree_inputs > options.uni_tree_outputs): # Build down tree
#	print 'Error',options.topology, 'topology requires that uni_tree_inputs <= uni_tree_outputs.'
#	sys.exit(1)

    #### uni-directional tree ####
    elif options.topology == 'uni_tree':
      # Check if fat tree parameters are valid
      #if(not num_is_power_of_two):
      #  print 'Error:',options.topology, 'topology requires that num_routers is a power of two.'
      #  sys.exit(1)
      
      num_leaf_nodes = max(options.uni_tree_inputs, options.uni_tree_outputs);
      if(num_leaf_nodes > 512): 
	print 'Error',options.topology, 'topology only supports up to 512 leaf nodes.'
	sys.exit(1)

      if(options.uni_tree_fanout < 2): 
	if(num_leaf_nodes <= 8):
	  options.uni_tree_fanout = num_leaf_nodes
	elif(num_leaf_nodes <= 64):
	  options.uni_tree_fanout = int(math.ceil(math.pow(num_leaf_nodes, 1.0/2.0)));
	elif(num_leaf_nodes <= 512):
	  options.uni_tree_fanout = int(math.ceil(math.pow(num_leaf_nodes, 1.0/3.0)));
	print 'Warning',options.topology, 'topology requires that uni_tree_fanout is at least two. Setting uni_tree_fanout to ', options.uni_tree_fanout 

      # corner-case for very small uni_tree
      if(options.uni_tree_inputs < options.uni_tree_fanout and options.uni_tree_outputs < options.uni_tree_fanout): 
	max_in_out =  max(options.uni_tree_inputs, options.uni_tree_outputs);
        print "Warning: uni_tree topology requires that uni_tree_fanout is not larger than both uni_tree_inputs and uni_tree_outpus.\n  Setting uni_tree_fanout to (",max_in_out,")."
        options.uni_tree_fanout = max_in_out;

      # Override file_prefix
      if(options.file_prefix == ''):
        file_prefix = options.topology + '_' + str(options.uni_tree_inputs) + 'INs_' + str(options.uni_tree_outputs) + 'OUTs_' + str(options.uni_tree_fanout) + 'FANOUT_' + str(options.num_vcs) + 'VCs_' + str(options.flit_buffer_depth) + 'BD_' + str(options.flit_data_width) + 'DW_' + str(options.alloc_type) + 'Alloc'
      # Set topology-specific parameters here
      num_user_send_ports = options.uni_tree_inputs
      num_user_recv_ports = options.uni_tree_outputs
      if(options.uni_tree_inputs < options.uni_tree_outputs): # Build down tree
        max_num_in_ports = options.uni_tree_inputs   
        max_num_out_ports = options.uni_tree_fanout  
	#if(options.uni_tree_inputs < options.uni_tree_fanout): # corner-case for very small uni_tree
	#  print "WARNING: uni_tree topology requires that uni_tree_fanout is >= MIN(uni_tree_inputs, uni_tree_outpus).i
	#      \  Setting uni_tree_fanout to uni_tree_inputs (",options.uni_tree_inputs,")."
      else:
        max_num_in_ports = options.uni_tree_fanout  
        max_num_out_ports = options.uni_tree_outputs


    #### Custom ####
    elif options.topology == 'custom':
      # Check if custom parameters are valid
      if(options.custom_topology == "" or options.custom_routing == ""):
	print "You must specify a custom topology and custom routing file using the --custom_topology and --custom_routing command-line options!"; sys.exit(-1);

      try: c_topology = open(options.custom_topology, 'r');
      except IOError: print "Could not open custom topology file " + options.custom_topology; sys.exit(-1);
      try: c_routing = open(options.custom_routing, 'r');
      except IOError: print "Could not open custom routing file " + options.custom_routing; sys.exit(-1);

      # Generate a hash based on the custom topology and routing files
      md5gen = hashlib.md5()
      for l in c_topology:
	md5gen.update(l);
      for l in c_routing:
	md5gen.update(l);
      hash = md5gen.hexdigest();
      c_topology.close()
      c_routing.close()
      #print 'md5sum is :', hash
      #sys.exit(-1);

      if(options.file_prefix == ''):
        file_prefix = options.topology + hash + '_' + str(options.num_routers) + 'RTs_' + str(options.num_vcs) + 'VCs_' + str(options.flit_buffer_depth) + 'BD_' + str(options.flit_data_width) + 'DW_' + str(options.alloc_type) + 'Alloc' 

      # Parse custom topology and routing files - might change options.num_routers
      send_ports = dict(); recv_ports = dict(); router_links = dict(); # will get populated by parse_custom_topology
      topology_info = {'num_routers':0, 'max_num_in_ports':0, 'max_num_out_ports':0, 'max_send_ports':0, 'max_recv_ports':0}
      parse_custom_topology(options.custom_topology, send_ports, recv_ports, router_links, topology_info)

      # Set topology-specific parameters here
      options.num_routers = topology_info['num_routers']
      max_num_in_ports = topology_info['max_num_in_ports']
      max_num_out_ports = topology_info['max_num_out_ports']
      num_user_send_ports = topology_info['max_send_ports']
      num_user_recv_ports = topology_info['max_recv_ports']
      #num_total_user_ports = max(topology_info['max_send_ports'], topology_info['max_recv_ports'])
      #if options.verbose: print 'Total number of User ports (max of send/receive ports): %d' % (num_total_user_ports)
      #if options.verbose: print 'Custom Topology Info: ', topology_info
#      if options.verbose: print 'Custom topology info\n  Number of routers: %d\n  Max input ports per router: %d\n  Max output ports per router: %d\n  Number of user send ports: %d\n  Number of user receive ports: %d\n' % (num_total_user_ports)
      
      topology_info['max_dests'] = topology_info['max_recv_ports']
      
      routing = parse_custom_routing(options.custom_routing, topology_info)
      
      #sys.exit(-1);


    #### unknown topology ####
    else:
      print 'Unknown topology', options.topology
      sys.exit(1)

    # Check if other options are valid
    if(options.expose_unused_ports and options.topology != 'mesh'):
      print 'Warning: Ignoring option --expose_unused_ports, which is only supported for mesh topology'
      #sys.exit(1)


    # Generate configuration files
    # Set configuration file names
    network_parameters_file = file_prefix+'_parameters.bsv'
    network_links_file = file_prefix+'_links.bsv'
    network_routing_file_prefix = file_prefix+'_routing_'

    if options.verbose: print '\n================ Generating ' + options.topology + ' network ================'
    generate_links_function   = 'gen_'+options.topology+'_links'
    generate_routing_function = 'gen_'+options.topology+'_routing'
    
    # Open links file
    network_links_filename = options.output_dir + '/' + network_links_file
    try: links = open(network_links_filename, 'w');
    except IOError: print "Could not open file " + network_links_filename; sys.exit(-1);
    dot_filename = network_links_filename
    dump_topology_filename = file_prefix+'.topology'
    dump_routing_filename = file_prefix+'.routing'
    
    if(options.topology != "custom"):
      num_links = eval(generate_links_function)(links, dot_filename, dump_topology_filename)
      eval(generate_routing_function)(network_routing_file_prefix, dump_routing_filename)
    else:
      num_links = gen_custom_links(send_ports, recv_ports, router_links, topology_info, links, dot_filename);
      gen_custom_routing(routing, topology_info, network_routing_file_prefix);
  
    links.close(); # close links file
    if options.verbose: print 'Generated links file: ' + network_links_filename

    gen_net_parameters(num_user_send_ports, num_user_recv_ports, max_num_in_ports, max_num_out_ports, num_links, options.cut, network_parameters_file)
    print 'Generated ' + options.topology + ' network configuration succesfully.'

    # Generate visulization of network graph
    if options.gen_graph: 
      if (options.graph_layout == "invalid"):  # if user or topology hasn't set this
	options.graph_layout = "circo";
      command = 'dot -T'+options.graph_format + ' -K' + options.graph_layout + ' ' + options.output_dir + '/' + file_prefix+'_links.bsv.gv -o ' + options.output_dir + '/' + file_prefix+'.'+options.graph_format
      os.system(command)
      if options.verbose: print 'Generated network graph visuzalization file: ' + file_prefix+'.'+options.graph_format
    
    # Generate RTL and synthesize
    if(options.gen_rtl):
      xtra_flags = ""
      if options.topology == 'ideal':
	    xtra_flags = "-D IDEAL=1 "
      if options.topology == 'xbar':
	    xtra_flags = "-D XBAR=1 -D XBAR_LANES="+str(options.xbar_lanes) + " " 

      user_flags = 'USER_FLAGS=\'' + xtra_flags + '-D NETWORK_PARAMETERS_FILE="\\"' + network_parameters_file + '"\\" -D NETWORK_LINKS_FILE="\\"' + network_links_file + '"\\" -D NETWORK_ROUTING_FILE_PREFIX="\\"' + network_routing_file_prefix +'"\\"\''  
      command = 'make net ' + user_flags 
      if (options.flow_control_type == "peek"):
        command = 'make net_simple ' + user_flags 
      
      print 'Compiling Bluespec to Verilog' 
      if options.verbose: print 'Executing command: ' + command
      os.system(command);

    if(options.run_xst):
      user_flags = 'USER_FLAGS=\'-D NETWORK_PARAMETERS_FILE="\\"' + network_parameters_file + '"\\" -D NETWORK_LINKS_FILE="\\"' + network_links_file + '"\\" -D NETWORK_ROUTING_FILE_PREFIX="\\"' + network_routing_file_prefix +'"\\"\'' 
      command = 'make net_xst ' + user_flags 

      if (options.flow_control_type == "peek"):
        command = 'make net_simple_xst ' + user_flags 

      print 'Compiling Bluespec to Verilog and running Xilinx XST for synthesis' 
      if options.verbose: print 'Executing command: ' + command
      os.system(command);


    if(options.run_dc):
      user_flags = 'USER_FLAGS=\'-D NETWORK_PARAMETERS_FILE="\\"' + network_parameters_file + '"\\" -D NETWORK_LINKS_FILE="\\"' + network_links_file + '"\\" -D NETWORK_ROUTING_FILE_PREFIX="\\"' + network_routing_file_prefix +'"\\"\'' 
      command = 'make net_dc ' + user_flags 

      if (options.flow_control_type == "peek"):
        command = 'make net_simple_dc ' + user_flags 

      print 'Compiling Bluespec to Verilog and running Synopsys DC for synthesis' 
      if options.verbose: print 'Executing command: ' + command
      os.system(command);


    if(options.sendmail != ''):
      #command = 'echo "\n~H From:CONECT <papamix@cs.cmu.edu>\n\nBody of message" | mail -s "CONECT subject" '+options.sendmail
      #command = 'echo "Body of message" | mail -s "CONECT subject" -a "From: CONECT <papamix@cs.cmu.edu>" '+options.sendmail
      #command = 'echo "Body of message" | mail -r "CONECT" -R "papamix@cs.cmu.edu" -s "CONECT subject" '+options.sendmail
      command = 'echo "Body of message" | mail -r "CONECT" -s "CONECT subject" -S replyto=papamix@cs.cmu.edu '+options.sendmail
      #command = 'echo "Body of message" | mail -r "CONECT" -s "CONECT subject" -S from="CONECT <papamix@cs.cmu.edu>" '+options.sendmail
      #command = 'echo "Body of message" | mail -r "CONECT" -s "CONECT subject" '+options.sendmail+' -- -f papamix@cs.cmu.edu'
      os.system(command);


if __name__ == '__main__':
    try:
        start_time = time.time()
	#terminal_columns = os.popen('stty size', 'r').read().split()[1]; # hack to get terminal columns if not available from 'COLUMNS' environment variable
        #parser = optparse.OptionParser(formatter=optparse.TitledHelpFormatter( width = int( os.environ.get('COLUMNS', terminal_columns) ) ), usage=globals()['__doc__'], version='0.6')
        parser = optparse.OptionParser(formatter=optparse.TitledHelpFormatter(), usage=globals()['__doc__'], version='0.6')
        #parser = optparse.OptionParser(formatter=optparse.IndentedHelpFormatter( width = int( os.environ.get('COLUMNS', terminal_columns) ) ), usage=globals()['__doc__'], version='0.4')
        parser.add_option ('--verbose', action='store_true', default=False, help='verbose output');
	parser.add_option ('-t', '--topology', action='store', type="string", default='ring', 
	                   help='specifies topology (can take values "single_switch", "line", "ring", "double_ring", "star", "mesh", "torus", "fat_tree", "butterfly", "fully_connected", "uni_single_switch", "uni_tree", uni_tree_up", "uni_tree_down", "custom", "ideal", "xbar")');
        parser.add_option ('--sendmail', action='store', type="string", default='', help='Send email notification when done')
	parser.add_option ('-n', '--num_routers', action='store', type="int", default=4, help='Specifies number of endpoint routers');
	parser.add_option ('--send_endpoints', action='store', type="int", default=4, help='Specifies number of send endpoints for uni-directional topologies');
	parser.add_option ('--recv_endpoints', action='store', type="int", default=4, help='Specifies number of receive endpoints for uni-directional topologies');
	parser.add_option ('-r', '--routers_per_row', action='store', type="int", default=-1, 
	                   help='specifies number of routers in each row (only used for mesh and torus)');
	parser.add_option ('-c', '--routers_per_column', action='store', type="int", default=-1, 
	                   help='specifies number of routers in each column (only used for mesh and torus)');
	parser.add_option ('-v', '--num_vcs', action='store', type="int", default=2, help='specifies number of virtual channels');
	parser.add_option ('-a', '--alloc_type', action='store', type="string", default='SepIFRoundRobin', 
	                   help='specifies type of allocator (can take values "SepIFRoundRobin", "SepOFRoundRobin", "SepIFStatic", "SepOFStatic", "Memocode")');
	parser.add_option ('--use_virtual_links', action='store_true', default=False, help='Enables locking of virtual links (VC+OutPort) in the presence of multi-flit packets.');
	# parser.add_option ('-a', '--alloc_type', action='store', type="string", default='sep_if_', help='specifies type of allocator (can take values:\n"sep_if_rr" (Separable Input-First Round-Robin Allocator),\n"sep_of_rr" (Separable Output-First Round-Robin Allocator),\n"sep_if_st" (Separable Input-First Static Allocator),\n"sep_of_st" (Separable Output-First Static Allocator),\n"memocode"  (Exhaustive maximal allocator used in memocode design contest)')
	parser.add_option ('-d', '--flit_buffer_depth', action='store', type="int", default=4, help='specifies depth of flit buffers');
	parser.add_option ('-s', '--sink_buffer_depth', action='store', type="int", default=-1, 
	                   help='specifies depth of buffers at receiving endpoints. If not specified flit_buffer_depth is assumed.');
	parser.add_option ('-w', '--flit_data_width', action='store', type="int", default=256, help='specifies flit data width');
	parser.add_option ('-i', '--cut', action='store', type="int", default=0, help='specifies the cut in an ideal or xbar network');
	parser.add_option ('-p', '--file_prefix', action='store', type="string", default='', help='override default file prefix');
	parser.add_option ('-l', '--xbar_lanes', action='store', type="int", default=1, help="specifies number of lanes in Xbar network");
	parser.add_option ('-o', '--output_dir', action='store', type="string", default='.', help='specifies output directory (default is ./)');
	parser.add_option ('-g', '--gen_rtl', action='store_true', default=False, help='invokes bsc compiler to generate rtl');
	parser.add_option ('-x', '--run_xst', action='store_true', default=False, help='generates rtl and invokes xst for synthesis');
	parser.add_option ('--run_dc', action='store_true', default=False, help='generates rtl and invokes Synopsys DC for synthesis');
	parser.add_option ('--expose_unused_ports', action='store_true', default=False, help='Exposes unused user ports for Mesh topology.');
	parser.add_option ('--flow_control_type', action='store', type="string", default='credit', 
	                   help='specifies flow control type, Credit-based or Peek (can take values "credit", "peek")');
	parser.add_option ('--peek_flow_control', action='store_true', default=False, help='Uses simpler peek flow control interface instead of credit-based interface.');
	parser.add_option ('--router_type', action='store', type="string", default='vc', 
	                   help='specifies router type, Virtual-Channel-based, Virtual-Output-Queued or Input-Queued (can take values "vc", "voq", "iq")');
	parser.add_option ('--voq_routers', action='store_true', default=False, help='Use Virtual-Output-Queued (VOQ) routers instead of Virtual-Channel (VC) routers.');
	parser.add_option ('--uni_tree_inputs', action='store', type="int", default=4, help='Number of tree input ports.');
	parser.add_option ('--uni_tree_outputs', action='store', type="int", default=64, help='Number of tree input ports.');
	parser.add_option ('--uni_tree_fanout', action='store', type="int", default=0, help='Fan-out of each tree router (will be calculated automatically if set to 0).');
	parser.add_option ('--uni_tree_distribute_leaves', action='store_true', default=False, help='Distributes the leaf nodes to the available routers, when the tree does not perfectly fit the available leaf nodes.');
	parser.add_option ('--pipeline_core', action='store_true', default=False, help='Pipelines router core.');
	parser.add_option ('--pipeline_alloc', action='store_true', default=False, help='Pipelines router allocator.');
	parser.add_option ('--pipeline_links', action='store_true', default=False, help='Pipelines flit and credit links.');
	parser.add_option ('--concentration_factor', action='store', type="int", default=1, 
	                   help='specifies number of user ports per endpoint router (not implemented yet)');
	parser.add_option ('--custom_topology', action='store', type="string", default="", help='specifies custom topology file.');
	parser.add_option ('--custom_routing', action='store', type="string", default="", help='specifies custom routing file.');
	parser.add_option ('--dump_topology_file', action='store_true', default=False, help='dumps the topology spec file for the generated network.');
	parser.add_option ('--dump_routing_file', action='store_true', default=False, help='dumps the routing spec file for the generated network.');
	parser.add_option ('--dbg', action='store_true', default=False, help='Enables debug messages in generated rtl.');
	parser.add_option ('--dbg_detail', action='store_true', default=False, help='Enables more detailed debug messages in generated rtl.');
	parser.add_option ('--gen_graph', action='store_true', default=False, help='Visualizes network graph using graphviz.');
	parser.add_option ('--graph_nodes', action='store_true', default=False, help='Also includes endpoint nodes in generated graph.');
	parser.add_option ('--graph_format', action='store', type="string", default="svg", help='Specifies output format for graphviz (e.g., png, jpg or svg)');
	parser.add_option ('--graph_layout', action='store', type="string", default="invalid", help='Specifies graphviz layout engine (e.g., dot, neato, circle)');
	# Future parameters
	# Pick between different allocation schemes (e.g. matrix allocators, wavefront allocators, etc)
	# choose implementation details (e.g. BRAM/LUT RAM, etc)

        (options, args) = parser.parse_args()
        if (len(sys.argv) < 2):
            parser.print_help(); #parser.error ('missing argument')
            sys.exit(0)
        main()
        if options.verbose: print 'Done in', (time.time() - start_time), 'seconds' 
        sys.exit(0)
    except KeyboardInterrupt, e: # Ctrl-C
        raise e
    except SystemExit, e: # sys.exit()
        raise e
    except Exception, e:
        print 'ERROR, UNEXPECTED EXCEPTION'
        print str(e)
        traceback.print_exc()
        os._exit(1)


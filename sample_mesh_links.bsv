send_ports_ifaces[0] = routers[0].in_ports[0];
recv_ports_ifaces[0] = routers[0].out_ports[0];
recv_ports_info_ifaces[0] =  get_port_info_ifc(0);
send_ports_ifaces[1] = routers[1].in_ports[0];
recv_ports_ifaces[1] = routers[1].out_ports[0];
recv_ports_info_ifaces[1] =  get_port_info_ifc(1);
send_ports_ifaces[2] = routers[2].in_ports[0];
recv_ports_ifaces[2] = routers[2].out_ports[0];
recv_ports_info_ifaces[2] =  get_port_info_ifc(2);
send_ports_ifaces[3] = routers[3].in_ports[0];
recv_ports_ifaces[3] = routers[3].out_ports[0];
recv_ports_info_ifaces[3] =  get_port_info_ifc(3);
send_ports_ifaces[4] = routers[4].in_ports[0];
recv_ports_ifaces[4] = routers[4].out_ports[0];
recv_ports_info_ifaces[4] =  get_port_info_ifc(4);
send_ports_ifaces[5] = routers[5].in_ports[0];
recv_ports_ifaces[5] = routers[5].out_ports[0];
recv_ports_info_ifaces[5] =  get_port_info_ifc(5);
send_ports_ifaces[6] = routers[6].in_ports[0];
recv_ports_ifaces[6] = routers[6].out_ports[0];
recv_ports_info_ifaces[6] =  get_port_info_ifc(6);
send_ports_ifaces[7] = routers[7].in_ports[0];
recv_ports_ifaces[7] = routers[7].out_ports[0];
recv_ports_info_ifaces[7] =  get_port_info_ifc(7);
send_ports_ifaces[8] = routers[8].in_ports[0];
recv_ports_ifaces[8] = routers[8].out_ports[0];
recv_ports_info_ifaces[8] =  get_port_info_ifc(8);
send_ports_ifaces[9] = routers[9].in_ports[0];
recv_ports_ifaces[9] = routers[9].out_ports[0];
recv_ports_info_ifaces[9] =  get_port_info_ifc(9);
send_ports_ifaces[10] = routers[10].in_ports[0];
recv_ports_ifaces[10] = routers[10].out_ports[0];
recv_ports_info_ifaces[10] =  get_port_info_ifc(10);
send_ports_ifaces[11] = routers[11].in_ports[0];
recv_ports_ifaces[11] = routers[11].out_ports[0];
recv_ports_info_ifaces[11] =  get_port_info_ifc(11);
send_ports_ifaces[12] = routers[12].in_ports[0];
recv_ports_ifaces[12] = routers[12].out_ports[0];
recv_ports_info_ifaces[12] =  get_port_info_ifc(12);
send_ports_ifaces[13] = routers[13].in_ports[0];
recv_ports_ifaces[13] = routers[13].out_ports[0];
recv_ports_info_ifaces[13] =  get_port_info_ifc(13);
send_ports_ifaces[14] = routers[14].in_ports[0];
recv_ports_ifaces[14] = routers[14].out_ports[0];
recv_ports_info_ifaces[14] =  get_port_info_ifc(14);
send_ports_ifaces[15] = routers[15].in_ports[0];
recv_ports_ifaces[15] = routers[15].out_ports[0];
recv_ports_info_ifaces[15] =  get_port_info_ifc(15);
links[0] <- mkConnectPorts(routers[1], 1, routers[0], 1);
links[1] <- mkConnectPorts(routers[5], 1, routers[4], 1);
links[2] <- mkConnectPorts(routers[9], 1, routers[8], 1);
links[3] <- mkConnectPorts(routers[13], 1, routers[12], 1);
links[4] <- mkConnectPorts(routers[2], 1, routers[1], 1);
links[5] <- mkConnectPorts(routers[6], 1, routers[5], 1);
links[6] <- mkConnectPorts(routers[10], 1, routers[9], 1);
links[7] <- mkConnectPorts(routers[14], 1, routers[13], 1);
links[8] <- mkConnectPorts(routers[3], 1, routers[2], 1);
links[9] <- mkConnectPorts(routers[7], 1, routers[6], 1);
links[10] <- mkConnectPorts(routers[11], 1, routers[10], 1);
links[11] <- mkConnectPorts(routers[15], 1, routers[14], 1);
links[12] <- mkConnectPorts(routers[4], 2, routers[0], 2);
links[13] <- mkConnectPorts(routers[8], 2, routers[4], 2);
links[14] <- mkConnectPorts(routers[12], 2, routers[8], 2);
links[15] <- mkConnectPorts(routers[5], 2, routers[1], 2);
links[16] <- mkConnectPorts(routers[9], 2, routers[5], 2);
links[17] <- mkConnectPorts(routers[13], 2, routers[9], 2);
links[18] <- mkConnectPorts(routers[6], 2, routers[2], 2);
links[19] <- mkConnectPorts(routers[10], 2, routers[6], 2);
links[20] <- mkConnectPorts(routers[14], 2, routers[10], 2);
links[21] <- mkConnectPorts(routers[7], 2, routers[3], 2);
links[22] <- mkConnectPorts(routers[11], 2, routers[7], 2);
links[23] <- mkConnectPorts(routers[15], 2, routers[11], 2);
links[24] <- mkConnectPorts(routers[0], 3, routers[1], 3);
links[25] <- mkConnectPorts(routers[4], 3, routers[5], 3);
links[26] <- mkConnectPorts(routers[8], 3, routers[9], 3);
links[27] <- mkConnectPorts(routers[12], 3, routers[13], 3);
links[28] <- mkConnectPorts(routers[1], 3, routers[2], 3);
links[29] <- mkConnectPorts(routers[5], 3, routers[6], 3);
links[30] <- mkConnectPorts(routers[9], 3, routers[10], 3);
links[31] <- mkConnectPorts(routers[13], 3, routers[14], 3);
links[32] <- mkConnectPorts(routers[2], 3, routers[3], 3);
links[33] <- mkConnectPorts(routers[6], 3, routers[7], 3);
links[34] <- mkConnectPorts(routers[10], 3, routers[11], 3);
links[35] <- mkConnectPorts(routers[14], 3, routers[15], 3);
links[36] <- mkConnectPorts(routers[0], 4, routers[4], 4);
links[37] <- mkConnectPorts(routers[4], 4, routers[8], 4);
links[38] <- mkConnectPorts(routers[8], 4, routers[12], 4);
links[39] <- mkConnectPorts(routers[1], 4, routers[5], 4);
links[40] <- mkConnectPorts(routers[5], 4, routers[9], 4);
links[41] <- mkConnectPorts(routers[9], 4, routers[13], 4);
links[42] <- mkConnectPorts(routers[2], 4, routers[6], 4);
links[43] <- mkConnectPorts(routers[6], 4, routers[10], 4);
links[44] <- mkConnectPorts(routers[10], 4, routers[14], 4);
links[45] <- mkConnectPorts(routers[3], 4, routers[7], 4);
links[46] <- mkConnectPorts(routers[7], 4, routers[11], 4);
links[47] <- mkConnectPorts(routers[11], 4, routers[15], 4);

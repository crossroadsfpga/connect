
#=========================================================================
# 
#  Filename:            Makefile
#  Date created:        03-16-2011
#  Last modified:       04-07-2011
#  Authors:		Michael Papamichael <papamixATcs.cmu.edu>
# 
#  Description:
#  Makefile for simulating and generating netlists. 
#  Based on Eric's makefile.
#  
#=========================================================================


include makefile.def
include makefile.syn
include makefile.clean

NPROCS:=$(shell grep -c ^processor /proc/cpuinfo)

ifndef TARGET
%-bsim:
	@make TARGET=$* $@ top=$(top) BSV_MACROS=$(BSV_MACROS) BUILD=$(BUILD)
%-vsim:
	@make TARGET=$* $@ top=$(top) BSV_MACROS=$(BSV_MACROS) BUILD=$(BUILD)
%-run:
	@make TARGET=$* $@ top=$(top) BSV_MACROS=$(BSV_MACROS) BUILD=$(BUILD)
%-xst:
	@echo $*
	@echo $@
	@echo $(top)
	@make TARGET=$* $@ top=$(top) part=$(part) BSV_MACROS=$(BSV_MACROS) BUILD=$(BUILD)
%-dc:
	@echo $*
	@echo $@
	@echo $(top)
	@make TARGET=$* $@ top=$(top) pdk=$(pdk) BSV_MACROS=$(BSV_MACROS) BUILD=$(BUILD)

%-map:
	@echo $*
	@echo $@
	@echo $(top)
	@make TARGET=$* $@ top=$(top) part=$(part) BSV_MACROS=$(BSV_MACROS) BUILD=$(BUILD)
%-bsc:
	@echo $*
	@echo $@
	@echo $(top)
	@make TARGET=$* $@ top=$(top) BSV_MACROS=$(BSV_MACROS) BUILD=$(BUILD)
else

########## BSIM PLUS COPRIMS ###########
#%-bsim: coprims $(call csrc, ./proj/$(TARGET))
#ifndef top
#	$(call bsim_compile, mk$*, $*.bsv); # bsv handles rest of dependencies
#else
#	$(call bsim_compile, mk$(top), $(top).bsv);
#endif

########## VSIM ###########
%-vsim: copy_vlog
ifndef top
	scripts/bsvdeps . $*.bsv 1 > $*.dep
	make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" BSV_MACROS='$(BSV_MACROS)'
	#$(call vsim_compile, mk$*, $*.bsv);
else
	scripts/bsvdeps . $*.bsv 1 > $*.dep
	make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#$(call vsim_compile, $(top), $*.bsv);
endif

########## VSIM ###########
%-run: copy_vlog
ifndef top
	$(call vsim_compile, mk$*, $*.bsv);
	$(call vcs_compile, mk$*);
else
	$(call vsim_compile, $(top), $*.bsv);
	$(call vcs_compile, $(top));
endif

########## XST ###########
%-xst: copy_vlog
ifndef top
        # Parallel make
	#scripts/bsvdeps . $*.bsv 1 > $*.dep
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -f makefile.bsc target TOP=$* GLOBAL_FLAGS="$(GLOBAL_FLAGS)"
        
	# Serial make
	$(call vsim_compile, mk$*, $*.bsv);
	$(call xst_compile, mk$*, $(part));
else
        # Parallel make
	#scripts/bsvdeps . $*.bsv 1 > $*.dep
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -f makefile.bsc target TARGET=$* TOP=$(top) GLOBAL_FLAGS="$(GLOBAL_FLAGS)"

        # Serial make
	$(call vsim_compile, $(top), $*.bsv);
	$(call xst_compile, $(top), $(part));
endif

########## DC ###########
%-dc: copy_vlog
ifndef top
        # Parallel make
	#scripts/bsvdeps . $*.bsv 1 > $*.dep
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -f makefile.bsc target TOP=$* GLOBAL_FLAGS="$(GLOBAL_FLAGS)"
        
	# Serial make
	$(call vsim_compile, mk$*, $*.bsv);
	$(call dc_compile, mk$*, $(pdk));
else
        # Parallel make
	#scripts/bsvdeps . $*.bsv 1 > $*.dep
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -f makefile.bsc target TARGET=$* TOP=$(top) GLOBAL_FLAGS="$(GLOBAL_FLAGS)"

        # Serial make
	$(call vsim_compile, $(top), $*.bsv);
	$(call dc_compile, $(top), $(pdk));
endif

########## MAP ###########
%-map: copy_vlog
ifndef top
        # Parallel make
	#scripts/bsvdeps . $*.bsv 1 > $*.dep
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -f makefile.bsc target TOP=$* GLOBAL_FLAGS="$(GLOBAL_FLAGS)"
        
	# Serial make
	$(call vsim_compile, mk$*, $*.bsv);
	$(call map_compile, mk$*, $(part));
else
        # Parallel make
	#scripts/bsvdeps . $*.bsv 1 > $*.dep
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -f makefile.bsc target TARGET=$* TOP=$(top) GLOBAL_FLAGS="$(GLOBAL_FLAGS)"

        # Serial make
	$(call vsim_compile, $(top), $*.bsv);
	$(call map_compile, $(top), $(part));
endif


########## BSC ###########
%-bsc: copy_vlog
ifndef top
        # Parallel make
	#scripts/bsvdeps . $*.bsv 1 > $*.dep
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -f makefile.bsc target TOP=$* GLOBAL_FLAGS="$(GLOBAL_FLAGS)"
        
	# Serial make
	$(call vsim_compile, mk$*, $*.bsv);
else
        # Parallel make
	#scripts/bsvdeps . $*.bsv 1 > $*.dep
	#make -j $(NPROCS) -f makefile.bsc DEP=$*.dep GLOBAL_FLAGS="$(GLOBAL_FLAGS)" 
	#make -f makefile.bsc target TARGET=$* TOP=$(top) GLOBAL_FLAGS="$(GLOBAL_FLAGS)"

        # Serial make
	$(call vsim_compile, $(top), $*.bsv);
endif


endif

sw:
	g++ -o parse_conf parse_conf.cpp
	g++ -o parse_traffic parse_traffic.cpp

tmp: copy_vlog
	$(call vsim_compile, mkInputVOQs, InputVOQs.bsv);
	$(call xst_compile, mkInputVOQs);

tmp2: copy_vlog
	$(call vsim_compile, mkTestArbiter8, Arbiters.bsv);
	$(call xst_compile, mkTestArbiter8);

tmp3: copy_vlog
	$(call vsim_compile, mkVOQRouter_multi_flit_bufs, VOQRouter_multi_flit_bufs.bsv);
	$(call xst_compile, mkVOQRouter_multi_flit_bufs);


tmp4: copy_vlog
	$(call vsim_compile, mkMultiFIFOMemTest, MultiFIFOMem.bsv);
	$(call xst_compile, mkMultiFIFOMemTest);

net: copy_vlog
	$(call vsim_compile, mkNetwork, Network.bsv);

net_xst: copy_vlog
	$(call vsim_compile, mkNetwork, Network.bsv);
	$(call xst_compile, mkNetwork);

net_dc: copy_vlog
	$(call vsim_compile, mkNetwork, Network.bsv);
	$(call dc_compile, mkNetwork);


net_simple: copy_vlog
	$(call vsim_compile, mkNetworkSimple, NetworkSimple.bsv);

net_simple_xst: copy_vlog
	$(call vsim_compile, mkNetworkSimple, NetworkSimple.bsv);
	$(call xst_compile, mkNetworkSimple);

net_simple_dc: copy_vlog
	$(call vsim_compile, mkNetworkSimple, NetworkSimple.bsv);
	$(call dc_compile, mkNetworkSimple);


mcr_tb: copy_vlog
	$(call vsim_compile, mkMCRouter_tb, MCRouter_tb.bsv);
	$(call vcs_compile, mkMCRouter_tb);

mcr_xst: copy_vlog
	$(call vsim_compile, mkMCRouter, MCRouter.bsv);
	$(call xst_compile, mkMCRouter);

mcn_tb: copy_vlog
	$(call vsim_compile, mkMCNetwork_tb, MCNetwork_tb.bsv);
	$(call vcs_compile, mkMCNetwork_tb);

mcn_xst: copy_vlog
	$(call vsim_compile, mkMCNetwork, MCNetwork.bsv);
	$(call xst_compile, mkMCNetwork);

mcn_xst_speed2: copy_vlog
	$(call vsim_compile, mkMCNetwork, MCNetwork.bsv);
	$(call xst_compile_speed2, mkMCNetwork);

mcn_xst_speed3: copy_vlog
	$(call vsim_compile, mkMCNetwork, MCNetwork.bsv);
	$(call xst_compile_speed3, mkMCNetwork);

mcn_xst_xupv5: copy_vlog
	$(call vsim_compile, mkMCNetwork, MCNetwork.bsv);
	$(call xst_compile_xupv5, mkMCNetwork);

mcn_xst_xupv5_speed2: copy_vlog
	$(call vsim_compile, mkMCNetwork, MCNetwork.bsv);
	$(call xst_compile_xupv5_speed2, mkMCNetwork);

mcn_xst_xupv5_speed3: copy_vlog
	$(call vsim_compile, mkMCNetwork, MCNetwork.bsv);
	$(call xst_compile_xupv5_speed2, mkMCNetwork);

mcvn_xst: copy_vlog
	$(call vsim_compile, mkMCVirtualNetwork, MCVirtualNetwork.bsv);
	$(call xst_compile, mkMCVirtualNetwork);

mcvn_xst_speed2: copy_vlog
	$(call vsim_compile, mkMCVirtualNetwork, MCVirtualNetwork.bsv);
	$(call xst_compile_speed2, mkMCVirtualNetwork);

mcvn_xst_speed3: copy_vlog
	$(call vsim_compile, mkMCVirtualNetwork, MCVirtualNetwork.bsv);
	$(call xst_compile_speed3, mkMCVirtualNetwork);

mcvn_xst_xupv5: copy_vlog
	$(call vsim_compile, mkMCVirtualNetwork, MCVirtualNetwork.bsv);
	$(call xst_compile_xupv5, mkMCVirtualNetwork);

mcvn_xst_xupv5_speed2: copy_vlog
	$(call vsim_compile, mkMCVirtualNetwork, MCVirtualNetwork.bsv);
	$(call xst_compile_xupv5_speed2, mkMCVirtualNetwork);

mcvn_xst_xupv5_speed3: copy_vlog
	$(call vsim_compile, mkMCVirtualNetwork, MCVirtualNetwork.bsv);
	$(call xst_compile_xupv5_speed3, mkMCVirtualNetwork);


mcvn_tb: copy_vlog
	$(call vsim_compile, mkMCVirtualNetwork_tb, MCVirtualNetwork_tb.bsv);
	$(call vcs_compile, mkMCVirtualNetwork_tb);

mctraffic_tb: copy_vlog
	$(call vsim_compile, mkMCTraffic_tb, MCTraffic_tb.bsv);
	$(call vcs_compile, mkMCTraffic_tb);



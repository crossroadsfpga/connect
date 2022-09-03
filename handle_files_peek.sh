cp test/*parameters.bsv build/connect_parameters.v
cp test/*.hex build/
cp src/* build/
cd build
rm testbench_sample.v
rm node.v
rm *Synth.v
rm *16*.v
rm Xbar.v
rm *BRAM*
rm BypassWire.v
rm *SRAM*
rm *PriorityEncoder*
rm *ROM*
rm RegFile.v
#rm SizedFIFO.v
#rm mkInputArbiter.v
#rm mkOutputArbiter.v
#rm *Static*
rm mkTestArbiter8.v
rm shift_8x64.v
rm shift_reg.v
echo "\`define PKT_SIZE 100000" >> connect_parameters.v
echo "\`define SIM_TIME 100000" >> connect_parameters.v
echo "\`define TIME_START 20000" >> connect_parameters.v
echo "\`define TIME_END 100000" >> connect_parameters.v
#./pkt_generator uniform test 570 100000 4 16 1 0 0 0 0
#./run_vcs.sh

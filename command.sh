rm -r build
rm -r test
mkdir build
mkdir test
#./gen_network.py -t mesh -n 16 -r 4 -c 4 --router_type=vc --flow_control_type=credit -w 32 -d 4 -a SepIFRoundRobin -g -o test
#./gen_network.py -t single_switch -n 4 --router_type=vc --flow_control_type=peek -w 33 -d 8 -a SepIFRoundRobin -g -o test
./gen_network.py -t mesh -n 16 -r 4 -c 4 --router_type=iq --flow_control_type=peek -w 32 -d 8 -a SepIFRoundRobin --pipeline_alloc -g -o test
#./gen_network.py -t mesh -n 16 -r 4 -c 4 --router_type=iq --flow_control_type=peek -w 32 -d 8 -a SepIFRoundRobin --use_virtual_links -g -o test
#./gen_network.py -t mesh -n 16 -r 4 -c 4 --router_type=vc -v 2 --flow_control_type=peek -w 32 -d 8 -a SepIFRoundRobin -g -o test

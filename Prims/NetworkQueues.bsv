import FIFOLevel::*;
import LUTFIFO::*;
import NetworkTypes::*;
import NetworkExternalTypes::*; 

(* synthesize *)
module mkNetworkXbarQ(FIFOCountIfc#(Flit_t, FlitBufferDepth));
    let q <- mkLUTFIFO(False);
    return q;
endmodule

import RegFile::*;

module mkRegFileLoadSyn#(String filename)(RegFile#(index,data))
				    provisos( Bounded#(index),
					      Bits#(index, a__),
					      Bits#(data, b__));
    RegFile#(index,data) rf;
    if(genVerilog) begin
	rf <- mkRegFileLoadSynVerilog(filename);
    end
    else begin
	rf <- mkRegFileFullLoad(filename);
    end
    return rf;
endmodule

import "BVI" RegFileLoadSyn = module mkRegFileLoadSynVerilog#(String filename)(RegFile#(index, data));

    default_clock clk(CLK, (*unused*) clk_gate);
    default_reset( RST_N ); 

    parameter file = filename;
    parameter addr_width = fromInteger(valueOf(SizeOf#(index)));
    parameter data_width = fromInteger(valueOf(SizeOf#(data)));
    parameter lo = 0;
    parameter hi = fromInteger(valueOf(TExp#(SizeOf#(index))))-1;
    parameter binary = 0;

    method D_OUT_1 sub(ADDR_1);
    method upd(ADDR_IN, D_IN) enable(WE);
    schedule (sub, upd) CF (sub, upd);

endmodule

module mkRfSynTest(RegFile#(Bit#(5), Bit#(64)));
	let rf <- mkRegFileLoadSyn("zeros.hex");
	return rf;
endmodule

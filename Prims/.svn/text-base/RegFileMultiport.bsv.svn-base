import RegFile::*;
import Vector::*;
import ConfigReg::*;
import RegFileLoadSyn::*;

interface RegFileRead#(type addr, type data);
    method data sub(addr a);
endinterface

interface RegFileWrite#(type addr, type data);
    method Action upd(addr a, data d);
endinterface 

interface RegFileMultiport#(numeric type nr, numeric type nw, type addr, type data);
    interface Vector#(nr, RegFileRead#(addr,data)) r;
    interface Vector#(nw, RegFileWrite#(addr,data)) w;
endinterface

interface RegFile_1W_nR#(numeric type nr, type addr, type data);
    interface RegFileWrite#(addr, data) w;
    interface Vector#(nr, RegFileRead#(addr, data)) r;
endinterface


module mkRegFile_1W_nR(RegFile_1W_nR#(nr, addr, data))
				provisos(Bits#(addr, addr_nt),
					 Bits#(data, data_nt),
					 Bounded#(addr),
				         PrimIndex#(addr, a__)
					);

    Vector#(nr, RegFile#(addr, data))  banks <- replicateM(mkRegFileLoadSyn("zeros.hex"));
    Vector#(nr, RegFileRead#(addr,data))  r_ifaces;

    for(Integer i=0; i < valueOf(nr); i=i+1) begin
	let r_ifc = interface RegFileRead
		    method data sub(addr a);
			return banks[i].sub(a);
		    endmethod
		endinterface;

	r_ifaces[i] = r_ifc;
    end

    interface RegFileWrite w;
	method Action upd(addr a, data d);
	    for(Integer i=0; i < valueOf(nr); i=i+1) begin
		banks[i].upd(a, d);
	    end
	endmethod
    endinterface 

    interface r = r_ifaces;

endmodule
 




module mkRegFileMultiport(RegFileMultiport#(nr, nw, addr, data))
				provisos(Bits#(addr, addr_nt),
					 Bits#(data, data_nt),
					 Bounded#(addr),
				         PrimIndex#(addr, a__)
					);

    Vector#(nw, RegFile_1W_nR#(nr, addr, data))	    banks <- replicateM(mkRegFile_1W_nR);
    Vector#(TExp#(addr_nt), Reg#(Bit#(TLog#(nw))))  lvt   <- replicateM(mkConfigRegU);

    Vector#(nw, RegFileWrite#(addr,data)) w_ifaces;
    Vector#(nr, RegFileRead#(addr,data))  r_ifaces;

    for(Integer i=0; i < valueOf(nw); i=i+1) begin
	let w_ifc = interface RegFileWrite
		    method Action upd(addr a, data d);
			banks[i].w.upd(a, d);
			lvt[a] <= fromInteger(i);
		    endmethod
		endinterface;
	w_ifaces[i] = w_ifc;
    end

    for(Integer i=0; i < valueOf(nr); i=i+1) begin
	let r_ifc = interface RegFileRead
		    method data sub(addr a);
			let pick = lvt[a];
			return banks[pick].r[i].sub(a);
		    endmethod
		endinterface;
	r_ifaces[i] = r_ifc;
    end

    interface w = w_ifaces;
    interface r = r_ifaces;

endmodule


module mkRegFileMultiportBrute(RegFileMultiport#(nr, nw, addr, data))
				provisos(Bits#(addr, addr_nt),
					 Bits#(data, data_nt),
					 Bounded#(addr),
				         PrimIndex#(addr, a__)
					);

    Vector#(TExp#(addr_nt), Reg#(data)) store <- replicateM(mkConfigRegU);
    Vector#(nw, RegFileWrite#(addr,data)) w_ifaces;
    Vector#(nr, RegFileRead#(addr,data))  r_ifaces;

    for(Integer i=0; i < valueOf(nw); i=i+1) begin
	let w_ifc = interface RegFileWrite
		    method Action upd(addr a, data d);
			store[a]<=d;
		    endmethod
		endinterface;
	w_ifaces[i] = w_ifc;
    end

    for(Integer i=0; i < valueOf(nr); i=i+1) begin
	let r_ifc = interface RegFileRead
		    method data sub(addr a);
			return store[a];
		    endmethod
		endinterface;
	r_ifaces[i] = r_ifc;
    end

    interface w = w_ifaces;
    interface r = r_ifaces;

endmodule


////////////////////////////////////////////////////////
// papamix: Added version that load init file

module mkRegFile_1W_nR_Load#(String loadfile)  
  (RegFile_1W_nR#(nr, addr, data))
  provisos(Bits#(addr, addr_nt),
    Bits#(data, data_nt),
    Bounded#(addr),
    PrimIndex#(addr, a__)
  );

    Vector#(nr, RegFile#(addr, data))  banks <- replicateM(mkRegFileLoadSyn(loadfile));
    Vector#(nr, RegFileRead#(addr,data))  r_ifaces;

    for(Integer i=0; i < valueOf(nr); i=i+1) begin
	let r_ifc = interface RegFileRead
		    method data sub(addr a);
			return banks[i].sub(a);
		    endmethod
		endinterface;

	r_ifaces[i] = r_ifc;
    end

    interface RegFileWrite w;
	method Action upd(addr a, data d);
	    for(Integer i=0; i < valueOf(nr); i=i+1) begin
		banks[i].upd(a, d);
	    end
	endmethod
    endinterface 

    interface r = r_ifaces;

endmodule
 

module mkRegFileMultiportLoad#(String loadfile)  
  (RegFileMultiport#(nr, nw, addr, data))
    provisos(Bits#(addr, addr_nt),
    	 Bits#(data, data_nt),
    	 Bounded#(addr),
         PrimIndex#(addr, a__)
    );

    Vector#(nw, RegFile_1W_nR#(nr, addr, data))	    banks <- replicateM(mkRegFile_1W_nR_Load(loadfile));
    Vector#(TExp#(addr_nt), Reg#(Bit#(TLog#(nw))))  lvt   <- replicateM(mkConfigRegU);

    Vector#(nw, RegFileWrite#(addr,data)) w_ifaces;
    Vector#(nr, RegFileRead#(addr,data))  r_ifaces;

    for(Integer i=0; i < valueOf(nw); i=i+1) begin
	let w_ifc = interface RegFileWrite
		    method Action upd(addr a, data d);
			banks[i].w.upd(a, d);
			lvt[a] <= fromInteger(i);
		    endmethod
		endinterface;
	w_ifaces[i] = w_ifc;
    end

    for(Integer i=0; i < valueOf(nr); i=i+1) begin
	let r_ifc = interface RegFileRead
		    method data sub(addr a);
			let pick = lvt[a];
			return banks[pick].r[i].sub(a);
		    endmethod
		endinterface;
	r_ifaces[i] = r_ifc;
    end

    interface w = w_ifaces;
    interface r = r_ifaces;

endmodule



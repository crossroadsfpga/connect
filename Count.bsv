import GenReg::*;
import Vector::*;

interface AddSub#(type data_t);
    method Action add(data_t c);
    method Action sub(data_t c);
endinterface

interface Count#(type data_t, numeric type np);

  method Action add(data_t c);
  method Action sub(data_t c);
  method Action clear();
  method data_t value();

  interface Vector#(np, AddSub#(data_t)) dports;

endinterface


module mkCount#(Integer init)(Count#(data_t, nports))
			  provisos(Bits#(data_t, data_nt),Eq#(data_t),Literal#(data_t));

  Reg#(Bit#(data_nt))	  count		<- mkGenReg(fromInteger(init));
  RWire#(Bit#(data_nt))	  count_add	<- mkRWire();
  RWire#(Bit#(data_nt))	  count_sub	<- mkRWire();
  PulseWire		  clear_wire	<- mkPulseWire();

  Vector#(nports, RWire#(Bit#(data_nt)))    delay_sub	    <- replicateM(mkRWire);
  Vector#(nports, Reg#(Bit#(data_nt)))	    delay_sub_r	    <- replicateM(mkGenReg(0));
  Vector#(nports, Reg#(Bool))		    delay_sub_r_v   <- replicateM(mkGenReg(False));

  Vector#(nports, RWire#(Bit#(data_nt)))    delay_add	    <- replicateM(mkRWire);
  Vector#(nports, Reg#(Bit#(data_nt)))	    delay_add_r	    <- replicateM(mkGenReg(0));
  Vector#(nports, Reg#(Bool))		    delay_add_r_v   <- replicateM(mkGenReg(False));
 
  rule update(True);

    Bit#(data_nt) ncount = count;

    if(isValid(count_add.wget)) ncount=ncount+validValue(count_add.wget);
    if(isValid(count_sub.wget)) ncount=ncount-validValue(count_sub.wget);

    for(Integer i=0; i < valueOf(nports); i=i+1) begin
	if(delay_add_r_v[i]) ncount=ncount+delay_add_r[i];
	if(delay_sub_r_v[i]) ncount=ncount-delay_sub_r[i];
    end

    if(clear_wire) ncount=0;
    count<=ncount;

  endrule

  (* fire_when_enabled *)
  rule updateDelayed(True);
      for(Integer i=0; i < valueOf(nports); i=i+1) begin
	  delay_add_r_v[i]  <= isValid(delay_add[i].wget);
	  delay_add_r[i]    <= validValue(delay_add[i].wget);
	  delay_sub_r_v[i]  <= isValid(delay_sub[i].wget);
	  delay_sub_r[i]    <= validValue(delay_sub[i].wget);
      end
  endrule

  Vector#(nports, AddSub#(data_t)) dport_ifaces;

  for(Integer i=0; i < valueOf(nports); i=i+1) begin
      let ifc = interface AddSub
		    method Action add(data_t din);
			delay_add[i].wset(pack(din));
		    endmethod
		    method Action sub(data_t din);
			delay_sub[i].wset(pack(din));
		    endmethod
		endinterface;

      dport_ifaces[i] = ifc;
  end

  interface dports = dport_ifaces;

  method Action add(data_t c);
    count_add.wset(pack(c));
  endmethod

  method Action sub(data_t c);
    count_sub.wset(pack(c));
  endmethod

  method Action clear();
    clear_wire.send();
  endmethod
  
  method value() = unpack(count);

endmodule

module mkGenReg#(data init)(Reg#(data)) provisos(Bits#(data,data_nt));

    Reg#(data) r;

    // generated verilog
    if(genVerilog) begin
	`ifdef RST_ZERO
	    r <- mkReg(init);
	`else
	    if(pack(init) == 0) r <- mkRegU;
	    else r <- mkReg(init);
	`endif
    end
    // bsim
    else begin
	r <- mkReg(init);
    end

    return r;

endmodule

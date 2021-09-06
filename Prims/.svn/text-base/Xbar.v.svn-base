`define clogb2(x) (\
	x <= 1 ? 0: \
	x <= 2 ? 1: \
	x <= 4 ? 2: \
	x <= 8 ? 3: \
	x <= 16 ? 4: \
	x <= 32 ? 5: \
	x <= 64 ? 6: \
	x <= 128 ? 7: \
	x <= 256 ? 8 : \
	x <= 512 ? 9 : \
	x <= 1024 ? 10 : \
	x <= 2048 ? 11 : \
	x <= 4096 ? 12 : \
	x <= 8192 ? 13 : \
	x <= 16384 ? 14 : -1)  

module XbarArbiter(CLK, RST_N, raises, grant, valid);

    parameter N=4;

    input CLK;
    input RST_N;
    input [N-1:0] raises;
    output reg [N-1:0] grant;
    output reg valid;

    function [1:0] gen_grant_carry;
	input c, r, p;
	begin
	    gen_grant_carry[1] = ~r & (c | p);
	    gen_grant_carry[0] = r & (c | p);
	end
    endfunction

    reg [N-1:0] token;
    reg [N-1:0] granted_A;
    reg [N-1:0] granted_B;
    reg carry;
    reg [1:0] gc;

    integer i;


    always@(*) begin
	valid = 1'b0;
	grant = 0;
	carry = 0;
	granted_A = 0;
	granted_B = 0;

	// Arbiter 1
	for(i=0; i < N; i=i+1) begin
	    gc = gen_grant_carry(carry, raises[i], token[i]);
	    granted_A[i] = gc[0];
	    carry = gc[1];
	end

        // Arbiter 2 (uses the carry from Arbiter 1)
	for(i=0; i < N; i=i+1) begin
	    gc = gen_grant_carry(carry, raises[i], token[i]);
	    granted_B[i] = gc[0];
	    carry = gc[1];
	end

	for(i=0; i < N; i=i+1) begin
	    if(granted_A[i] | granted_B[i]) begin
		grant = 0;
		grant[i] = 1'b1;
		valid = 1'b1;
	    end
	end
    end

    always@(posedge CLK) begin
	if(RST_N) token <= {token[N-2:0], token[N-1]};
	else token <= 1;
    end

endmodule


module Xbar(CLK, RST_N,
	    i_valid,
	    i_prio,
	    i_tail,
	    i_dst,
	    i_vc,
	    i_data, 

	    o_valid,
	    o_prio,
	    o_tail,
	    o_dst,
	    o_vc,
	    o_data, 

 	    i_cred,
	    i_cred_valid,

	    o_cred_en
	    );

    parameter N		    = 16;
    parameter NUM_VCS	    = 2;
    parameter CUT	    = 2;
    parameter DATA	    = 32;
    parameter BUFFER_DEPTH  = 16;

    parameter LOG_N	    = `clogb2(N);
    parameter VC	    = `clogb2(NUM_VCS); 
    parameter DST	    = `clogb2(N);
    parameter FLIT_WIDTH    = 1+1+DST+VC+DATA;
    parameter CRED_WIDTH    = `clogb2(BUFFER_DEPTH) + 1;

    input CLK, RST_N;

    // Input ports
    input [N-1:0]              i_valid;
    input [N-1:0]              i_prio; 
    input [N-1:0]              i_tail;
    input [N*DST-1:0]          i_dst; 
    input [N*VC-1:0]           i_vc;
    input [N*DATA-1:0]         i_data;

    wire [VC-1:0]              i_vc_arr [N-1:0];

    // Input queue front ports
    wire [N-1:0]               f_prio;
    wire [N-1:0]               f_tail;
    wire [DST-1:0]             f_dst [N-1:0];
    wire [VC-1:0]              f_vc [N-1:0];
    wire [DATA-1:0]            f_data [N-1:0];
    wire [N-1:0]               f_elig;

    // Needed to play friendly with Icarus Verilog and Modelsim
    wire [DST*N-1:0]	       f_dst_flat;
    wire [VC*N-1:0]            f_vc_flat;
    wire [DATA*N-1:0]          f_data_flat;

    // Output ports
    output reg [N-1:0]         o_valid;
    output reg [N-1:0]         o_prio;
    output reg [N-1:0]         o_tail;
    output [N*DST-1:0]         o_dst;
    output [N*VC-1:0]          o_vc;
    output [N*DATA-1:0]        o_data;

    reg [DST-1:0]              o_dst_arr [N-1:0];
    reg [VC-1:0]               o_vc_arr [N-1:0];
    reg [DATA-1:0]             o_data_arr [N-1:0];

    // Input credit 
    output [N*VC-1:0]          i_cred; // just remembers the VC of 1st packet that arrives
    output reg [N-1:0]         i_cred_valid; // maybe bit
    reg [VC-1:0]               i_cred_arr [N-1:0];
 
    // Output credit
    input [N-1:0]              o_cred_en;

    // Dequeue wires
    wire [N-1:0]               grants [N-1:0];
    wire [N-1:0]               grant_valids;
    reg [N-1:0]                deq_en;

    reg [CRED_WIDTH-1:0]       creds_left [N-1:0];

    genvar i, o, k;
    integer in,out;

    generate
	for(o=0; o < N; o=o+1) begin: arbiters
	    wire [N-1:0] raises;

	    for(k=0; k < N; k=k+1) begin: raisewires
		assign raises[k] = (f_dst[k] == o) && f_elig[k];
	    end

	    XbarArbiter#(.N(N)) arbiter(.CLK(CLK), 
					.RST_N(RST_N),
					.raises(raises),
					.valid(grant_valids[o]),
					.grant(grants[o])); // [(o+1)*LOG_N-1:o*LOG_N]));

	    
	     
	end
    endgenerate


    /*
    // Stats 
    always@(negedge CLK) begin
	if(RST_N) begin
	    for(in=0; in < N; in=in+1) begin
		if(f_elig[in])
		    $display("strace time=%0d component=noc inst=0 evt=raises val=1", $time);

		if(deq_en[in] != 0) 
		    $display("strace time=%0d component=noc inst=0 evt=grants val=1", $time);
		    //$display("strace time=%0d component=noc inst=0 evt=full val=1", $time);
	    end
	end
    end 
    */

    // Record the input VC
    always@(posedge CLK) begin
	if(RST_N) begin
	    for(in=0; in < N; in=in+1) begin
		if(i_valid[in])
		    i_cred_arr[in] <= i_vc_arr[in];
	    end
	end
	else begin
	    for(in=0; in < N; in=in+1) begin
		i_cred_arr[in]<='hx;
	    end
	end
    end

    for(i=0; i < N; i=i+1) begin: assign_arr
	assign i_vc_arr[i] = i_vc[(i+1)*VC-1:i*VC];
        assign i_cred[(i+1)*VC-1:i*VC] = i_cred_arr[i];
        assign o_dst[(i+1)*DST-1:i*DST] = o_dst_arr[i];
	assign o_vc[(i+1)*VC-1:i*VC] = o_vc_arr[i];
	assign o_data[(i+1)*DATA-1:i*DATA] = o_data_arr[i]; 
    end

    // Enable deq 
    always@(*) begin
	for(in=0; in < N; in=in+1) begin: deqwires
	    deq_en[in] = 1'b0;
	    i_cred_valid[in] = 1'b0;

	    for(out=0; out < N; out=out+1) begin: outer
		if(grant_valids[out] && (grants[out][in] == 1'b1) && (creds_left[out] != 0)) begin
		    deq_en[in] = 1'b1;
		    i_cred_valid[in] = 1'b1;
		end
	    end
	end
    end

    // Needed to play friendly with Icarus Verilog
    for(i=0; i < N; i=i+1) begin
	assign f_dst_flat[(i+1)*DST-1:i*DST] = f_dst[i];
	assign f_vc_flat[(i+1)*VC-1:i*VC] = f_vc[i];
	assign f_data_flat[(i+1)*DATA-1:i*DATA] = f_data[i];
    end

    // Muxbar
    for(i=0; i < N; i=i+1) begin: steerwires
	always@(grant_valids[i] or grants[i] or creds_left[i] or f_prio or f_tail or f_dst_flat or f_vc_flat or f_data_flat) begin
	    o_valid[i] = 1'b0;
	    o_prio[i] = 'hx;
	    o_tail[i] = 'hx;
	    o_dst_arr[i] = 'hx;
	    o_vc_arr[i] = 'hx;
	    o_data_arr[i] = 'hx;

	    for(in=0; in < N; in=in+1) begin: innersteer
		if(grant_valids[i] && (grants[i][in] == 1'b1) && (creds_left[i] != 0)) begin
		    o_valid[i] = 1'b1;
		    o_prio[i] = f_prio[in];
		    o_tail[i] = f_tail[in];
		    o_dst_arr[i]  = f_dst[in];
		    o_vc_arr[i]   = f_vc[in];
		    o_data_arr[i] = f_data[in];
		end
	    end
	end
    end
     

    /*
    // Muxbar
    always@(*) begin
	for(out=0; out < N; out=out+1) begin: steerwires
	    o_valid[out] = 1'b0;
	    o_prio[out] = 'hx;
	    o_tail[out] = 'hx;
	    o_dst_arr[out] = 'hx;
	    o_vc_arr[out] = 'hx;
	    o_data_arr[out] = 'hx;

	    for(in=0; in < N; in=in+1) begin: innersteer
		if(grant_valids[out] && (grants[out][in] == 1'b1) && (creds_left[out] != 0)) begin
		    o_valid[out] = 1'b1;
		    o_prio[out] = f_prio[in];
		    o_tail[out] = f_tail[in];
		    o_dst_arr[out]  = f_dst[in];
		    o_vc_arr[out]   = f_vc[in];
		    o_data_arr[out] = f_data[in];
		end
	    end
	end
    end
    */

    // Transmit credits
    for(o=0; o < N; o=o+1) begin: output_credits
	always@(posedge CLK) begin
	    if(RST_N) begin
		if((o_cred_en[o] == 1'b0) && (o_valid[o] == 1'b1))
		    creds_left[o] <= creds_left[o] - 1;
		else if((o_cred_en[o] == 1'b1) && (o_valid[o] == 1'b0))
		    creds_left[o] <= creds_left[o] + 1;
	    end
	    else begin
		creds_left[o] <= BUFFER_DEPTH;
	    end
	end
    end

    /////////////////////////
    // Input Queues
    /////////////////////////
    
    generate
	for(i=0; i < N; i=i+1) begin: ififos
/*
	    SizedFIFO#(.p1width(FLIT_WIDTH), .p2depth(BUFFER_DEPTH), .p3cntr_width(`clogb2(BUFFER_DEPTH))) inQ
		       (.CLK(CLK), 
			.RST_N(RST_N), 
			.D_IN({i_prio[i], i_tail[i], i_dst[(i+1)*DST-1:i*DST], i_vc[(i+1)*VC-1:i*VC], i_data[(i+1)*DATA-1:i*DATA]}),
			.ENQ(i_valid[i]),
			.D_OUT({f_prio[i], f_tail[i], f_dst[i], f_vc[i], f_data[i]}),
			.DEQ(deq_en[i]),
			.EMPTY_N(f_elig[i]),
			.FULL_N(), // unused
			.CLR(1'b0) // unused
		      );
*/
	    mkNetworkXbarQ inQ(.CLK(CLK), .RST_N(RST_N),
                      	   .enq_sendData({i_prio[i], i_tail[i], i_dst[(i+1)*DST-1:i*DST], i_vc[(i+1)*VC-1:i*VC], i_data[(i+1)*DATA-1:i*DATA]}),
                           .EN_enq(i_valid[i]),
                      	   .RDY_enq(),
                           .EN_deq(deq_en[i]),
                           .RDY_deq(),
                           .first({f_prio[i], f_tail[i], f_dst[i], f_vc[i], f_data[i]}),
                           .RDY_first(),
                           .notFull(),
                           .RDY_notFull(),
                           .notEmpty(f_elig[i]),
                           .RDY_notEmpty(),
                           .count(),
                           .RDY_count(),
                           .EN_clear(1'b0),
                           .RDY_clear());

	end
    endgenerate

endmodule

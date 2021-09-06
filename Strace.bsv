function Action strace(String component, Bit#(32) inst, String evt);
    action
	$display("strace time=%0d component=%s inst=%0d evt=%s val=1", $time, component, inst, evt);
    endaction
endfunction

function Action strace_new_region(Bit#(32) id);
    action
	$display("strace time=%0d inst=%0d evt=new_region", $time, id);
    endaction
endfunction

function Action strace_add(String component, Bit#(32) inst, String evt, Bit#(32) val);
    action
	$display("strace time=%0d component=%s inst=%0d evt=%s val=%0d", $time, component, inst, evt, val);
    endaction
endfunction
 
function Action strace_begin(String component, Bit#(32) inst, String evt, Bit#(32) tag);
    action
	$display("strace time=%0d component=%s inst=%0d evt=%s tag=%0d begin=1", $time, component, inst, evt, tag);
    endaction
endfunction

function Action strace_end(String component, Bit#(32) inst, String evt, Bit#(32) tag);
    action
	$display("strace time=%0d component=%s inst=%0d evt=%s tag=%0d end=1", $time, component, inst, evt, tag);
    endaction
endfunction

function Action strace_cfg(String cfg, Bit#(32) value);
    action
	$display("strace cfg=%s val=%0d", cfg, value);
    endaction
endfunction

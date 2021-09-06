module PriorityEncoder
(
input_data,
output_data
);


parameter OUTPUT_WIDTH=8;
parameter INPUT_WIDTH=1<<OUTPUT_WIDTH;

 input      [INPUT_WIDTH-1:0]  input_data;
 output     [OUTPUT_WIDTH-1:0] output_data;

 reg [OUTPUT_WIDTH-1:0] output_data;
 
integer                            ii;
 
always @* begin
  output_data = {OUTPUT_WIDTH{1'bx}};
  for(ii=0;ii<INPUT_WIDTH;ii=ii+1) if (input_data[ii]) output_data = ii;
end
 
endmodule

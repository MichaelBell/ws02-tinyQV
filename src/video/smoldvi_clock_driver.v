// We can drive a clock by passing 10'b11111_00000 into a 10:1 serialiser, but this
// is wasteful, because the tools won't trim the CDC hardware. It's worth it
// (area-wise) to specialise this.
//
// This module takes a half-rate bit clock (5x pixel clock) and drives a
// pseudodifferential pixel clock using DDR outputs.

module smoldvi_clock_driver (
	input  wire       clk_x5,
	input  wire       rst_n_x5,

	output wire       qp,
	output wire       qn
);

reg [9:0] ring_ctr;

always @ (posedge clk_x5) begin
	if (!rst_n_x5) begin
		ring_ctr <= 10'b00111_11000;
	end else begin
		ring_ctr <= {ring_ctr[1:0], ring_ctr[9:2]};
	end
end

assign qp = clk_x5 ? ring_ctr[0] : ring_ctr[1];
assign qn = clk_x5 ? ring_ctr[5] : ring_ctr[6];

endmodule

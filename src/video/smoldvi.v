module smoldvi (
	// Full-rate pixel clock, full-rate bit clock. Must have exact 1:10 frequency
	// ratio, and a common root oscillator
	input wire                 clk_pix,
	input wire                 rst_n_pix,
	input wire                 clk_bit,
	input wire                 rst_n_bit,

	input  wire [1:0] r,
	input  wire [1:0] g,
	input  wire [1:0] b,
    input wire hsync,
    input wire vsync,
    input wire den,

	// {CK, D2, D1, D0}
	output wire [3:0]          dvi_p,
	output wire [3:0]          dvi_n
);


wire [9:0] tmds0;
wire [9:0] tmds1;
wire [9:0] tmds2;

reg den_delay;
always @(posedge clk_pix) begin
	den_delay <= den;
end

simple_tmds_encode tmds0_encoder (
	.clk   (clk_pix),
	.rst_n (rst_n_pix),
	.c     ({vsync, hsync}),
	.d     (b),
	.den   (den_delay),
	.q     (tmds0)
);

simple_tmds_encode tmds1_encoder (
	.clk   (clk_pix),
	.rst_n (rst_n_pix),
	.c     (2'b00),
	.d     (g),
	.den   (den_delay),
	.q     (tmds1)
);

simple_tmds_encode tmds2_encoder (
	.clk   (clk_pix),
	.rst_n (rst_n_pix),
	.c     (2'b00),
	.d     (r),
	.den   (den_delay),
	.q     (tmds2)
);

smoldvi_serialiser ser_d0 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds0),
	.qp        (dvi_p[0]),
	.qn        (dvi_n[0])
);

smoldvi_serialiser ser_d1 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds1),
	.qp        (dvi_p[1]),
	.qn        (dvi_n[1])
);

smoldvi_serialiser ser_d2 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds2),
	.qp        (dvi_p[2]),
	.qn        (dvi_n[2])
);

smoldvi_clock_driver ser_ck (
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.qp        (dvi_p[3]),
	.qn        (dvi_n[3])
);

endmodule

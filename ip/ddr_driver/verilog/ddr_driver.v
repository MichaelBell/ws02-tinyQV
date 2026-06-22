`default_nettype    none

module ddr_driver (
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif    
    input wire          clk,
    input wire  [1:0]   data,
    output wire [1:0]   q
);

    wire clk1, clk_final;
    wire [1:0] data_n;
    wire d1p, d2p, d1n, d2n;

    gf180mcu_as_sc_mcu7t3v3__dlybuff_2 clkdly1 (.A(clk), .Y(clk1));
    gf180mcu_as_sc_mcu7t3v3__dlybuff_2 clkdly2 (.A(clk1), .Y(clk_final));

    gf180mcu_as_sc_mcu7t3v3__inv_2 inv1(.A(data[0]), .Y(data_n[0]));
    gf180mcu_as_sc_mcu7t3v3__inv_2 inv2(.A(data[1]), .Y(data_n[1]));

    gf180mcu_as_sc_mcu7t3v3__dlxfn_2 latch1n (.D(data[0]), .ENA(clk_final), .Q(d1n));
    gf180mcu_as_sc_mcu7t3v3__dfxtp_2 flop2p (.D(data[1]), .CLK(clk_final), .Q(d2p));

    gf180mcu_as_sc_mcu7t3v3__dlxfn_2 latch1p (.D(data_n[0]), .ENA(clk_final), .Q(d1p));
    gf180mcu_as_sc_mcu7t3v3__dfxtp_2 flop2n (.D(data_n[1]), .CLK(clk_final), .Q(d2n));

    gf180mcu_as_sc_mcu7t3v3__mux2_4 muxp (.A(d2p), .B(d1p), .S(clk), .Y(q[0]));
    gf180mcu_as_sc_mcu7t3v3__mux2_4 muxn (.A(d2n), .B(d1n), .S(clk), .Y(q[1]));

endmodule

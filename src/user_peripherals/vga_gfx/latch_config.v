`default_nettype none

// A wrapper to use a latch as a register
// Note no reset - reset using data
module vga_latch_config #(
    parameter WIDTH=32
) (
    input wire clk,

    input wire wen,                 // Write enable
    input wire [WIDTH-1:0] data_in, // Data to write during second half of clock when wen is high

    output wire [WIDTH-1:0] data_out
);

`ifdef SIM
    reg [WIDTH-1:0] state;

    /* verilator lint_off SYNCASYNCNET */
    always @(wen or data_in) begin
        if (wen) state <= data_in;
    end
    /* verilator lint_on SYNCASYNCNET */

    assign data_out = state;

    wire _unused = &{clk, 1'b0};

`elsif SCL_gf180mcu_as_sc_mcu7t3v3
    reg [WIDTH-1:0] state;

    always @(posedge clk) begin
        if (wen) state <= data_in;
    end

    assign data_out = state;

`else
    /* verilator lint_off PINMISSING */
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i+1) begin : gen_latch
`ifdef SCL_sky130_fd_sc_hd
            sky130_fd_sc_hd__dlxtp_1 state (.Q(data_out[i]), .D(data_in[i]), .GATE(wen) );
`else
            gf180mcu_fd_sc_mcu7t5v0__latq_1 p_latch(.E(wen), .D(data_in[i]), .Q(data_out[i]));
`endif
        end
    endgenerate
    /* verilator lint_on PINMISSING */

    wire _unused = &{clk, 1'b0};
`endif

endmodule

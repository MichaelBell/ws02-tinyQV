// SPDX-FileCopyrightText: © 2025 XXX Authors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif
    
    input  wire clk,       // clock
    input  wire rst_n,     // reset (active low)
    input  wire clk5x,     // clock for DV serialization
    input  wire prog_clk,
    
    input  wire [NUM_INPUT_PADS-1:0] input_in,   // Input value
    output wire [NUM_INPUT_PADS-1:0] input_pu,   // Pull-up
    output wire [NUM_INPUT_PADS-1:0] input_pd,   // Pull-down

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,   // Input value
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,  // Output value
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,   // Output enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,   // Input type (0=CMOS Buffer, 1=Schmitt Trigger)
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,   // Slew rate (0=fast, 1=slow)
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,   // Input enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,   // Pull-up
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,   // Pull-down

    inout  wire [NUM_ANALOG_PADS-1:0] analog  // Analog
);

    // See here for usage: https://gf180mcu-pdk.readthedocs.io/en/latest/IPs/IO/gf180mcu_fd_io/digital.html
    
    // Pull up for prog_cs, use_hdmi_n, prog_n
    assign input_pu = 5'b10110;
    assign input_pd = 5'b00000;

    // Set the bidir as the TT inputs, bidirs, outputs
    assign bidir_oe[7:0] = '0;
    assign bidir_out[7:0] = '0;

    assign bidir_oe[28:16] = '1;

    assign bidir_cs = '0;
    assign bidir_sl = '0;
    assign bidir_ie[28:0] = ~bidir_oe[28:0];
    assign bidir_pu[7:0] = 8'b10000000;  // Pull up in7 to avoid glitching UART RX if not connected
    assign bidir_pu[28:16] = '0;
    assign bidir_pd[7:0] = '0;
    assign bidir_pd[28:16] = '0;

    // Set the pulls on the QSPI data to configure sensible default latency, and pull up chip selects
    wire prog_n = input_in[1];
    assign bidir_pu[15:8] = prog_n ? 8'b11000011 : 8'b11110011;
    assign bidir_pd[15:8] = prog_n ? 8'b00110100 : 8'b00000100;

    wire [7:0] uio_in;
    wire [7:0] uio_oe;
    wire [7:0] uio_out;
    assign bidir_out[8] = prog_n ? uio_out[0] : input_in[4];  // Flash CS
    assign bidir_oe[8]  = prog_n ? uio_oe[0]  : '1;
    assign bidir_out[9] = prog_n ? uio_out[1] : input_in[3];  // Flash MOSI
    assign bidir_oe[9]  = prog_n ? uio_oe[1]  : '1;
    assign bidir_out[10] = prog_n ? uio_out[2] : '0;          // Flash MISO
    assign bidir_oe[10]  = prog_n ? uio_oe[2]  : '0;
    assign bidir_out[11] = prog_n ? uio_out[3] : prog_clk;    // Flash SCK
    assign bidir_oe[11]  = prog_n ? uio_oe[3]  : '1;
    assign bidir_out[12] = uio_out[4];
    assign bidir_oe[12] = prog_n ? uio_oe[4] : '0;
    assign bidir_out[13] = uio_out[5];
    assign bidir_oe[13] = prog_n ? uio_oe[5] : '0;
    assign bidir_out[14] = prog_n ? uio_out[6] : '1;           // RAM A CS
    assign bidir_oe[14] = prog_n ? uio_oe[6] : '0;
    assign bidir_out[15] = prog_n ? uio_out[7] : '1;           // RAM B CS
    assign bidir_oe[15] = prog_n ? uio_oe[7] : '0;

    // Prog MISO
    assign bidir_out[37] = prog_n ? 1'b0 : bidir_in[10];
    assign bidir_oe[37] = prog_n ? 1'b0 : 1'b1;
    assign bidir_ie[37] = 1'b0;
    assign bidir_pu[37] = '0;
    assign bidir_pd[37] = '0;

    assign bidir_ie[36:29] = '0;
    assign bidir_oe[36:29] = '1;
    assign bidir_pu[36:29] = '0;
    assign bidir_pd[36:29] = '0;

    generate
    for (genvar i=0; i<8; i++) begin : bidir_inputs
        assign uio_in[i] = uio_oe[i] ? uio_out[i] : bidir_in[i+8];
    end
    endgenerate

    wire use_hdmi_n = input_in[2];

    // Clock
    reg [4:0] clkdiv;
    always @(posedge clk5x or negedge rst_n) begin
        if (~rst_n) clkdiv <= 5'b11100;
        else clkdiv <= {clkdiv[0], clkdiv[4:1]};
    end
    wire real_clk = use_hdmi_n ? clk : clkdiv[0];
    reg [4:0] rst_delay;
    always @(posedge real_clk or negedge rst_n) begin
        if (~rst_n) rst_delay <= 5'b00000;
        else rst_delay <= {rst_delay[3:0], 1'b1};
    end
    wire real_rst_n = use_hdmi_n ? rst_n : rst_delay[4];

    tt_um_MichaelBell_tinyQV tt(
        .ui_in(bidir_in[7:0]),
        .uo_out(bidir_out[24:16]),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(1'b1),
        .clk(real_clk),
        .rst_n(real_rst_n),
        .clk5x(clk5x),
        .use_hdmi_n(use_hdmi_n),
        .uart_rx(input_in[0]),
        .uart_tx(bidir_out[25]),
        .uart_rts(bidir_out[26]),
        .debug_uart_txd(bidir_out[27]),
        .debug_signal(bidir_out[28]),
        .video_out(bidir_out[36:29])
    );

endmodule

`default_nettype wire

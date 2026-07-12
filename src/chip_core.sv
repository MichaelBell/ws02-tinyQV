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
    
    // Pull up for prog_n
    assign input_pu[1:0] = 2'b10;
    assign input_pd[1:0] = 2'b00;
    assign input_pu[NUM_INPUT_PADS-1:2] = '0;
    assign input_pd[NUM_INPUT_PADS-1:2] = '0;

    // Set the bidir as the TT inputs, bidirs, outputs
    assign bidir_oe[7:0] = '0;
    assign bidir_out[7:0] = '0;

    assign bidir_oe[28:16] = '1;

    assign bidir_cs = '0;
    assign bidir_sl = '0;
    assign bidir_ie[28:0] = ~bidir_oe[28:0];
    assign bidir_pu[7:0] = '0;
    assign bidir_pu[28:16] = '0;
    assign bidir_pd[7:0] = '0;
    assign bidir_pd[28:16] = '0;

    // Set the pulls on the QSPI data to configure sensible default latency, and pull up chip selects
    assign bidir_pu[15:8] = 8'b11000011;
    assign bidir_pd[15:8] = 8'b00110100;

    wire [7:0] uio_in;
    wire [7:0] uio_oe;
    wire [7:0] uio_out;
    assign bidir_out[8] = uio_out[0];  // Flash CS
    assign bidir_oe[8]  = uio_oe[0];
    assign bidir_out[9] = uio_out[1];  // Flash MOSI
    assign bidir_oe[9]  = uio_oe[1];
    assign bidir_out[10] = uio_out[2];           // Flash MISO
    assign bidir_oe[10]  = uio_oe[2];
    assign bidir_out[11] = uio_out[3]; // Flash SCK
    assign bidir_oe[11]  = uio_oe[3];
    assign bidir_out[12] = uio_out[4];
    assign bidir_oe[12] = uio_oe[4];
    assign bidir_out[13] = uio_out[5];
    assign bidir_oe[13] = uio_oe[5];
    assign bidir_out[14] = uio_out[6];           // RAM A CS
    assign bidir_oe[14] = uio_oe[6];
    assign bidir_out[15] = uio_out[7];           // RAM B CS
    assign bidir_oe[15] = uio_oe[7];

    assign bidir_ie[NUM_BIDIR_PADS-1:29] = '0;
    assign bidir_oe[NUM_BIDIR_PADS-1:29] = '0;
    assign bidir_pu[NUM_BIDIR_PADS-1:29] = '0;
    assign bidir_pd[NUM_BIDIR_PADS-1:29] = '1;
    assign bidir_out[NUM_BIDIR_PADS-1:29] = '0;

    generate
    for (genvar i=0; i<8; i++) begin : bidir_inputs
        assign uio_in[i] = uio_oe[i] ? uio_out[i] : bidir_in[i+8];
    end
    endgenerate

    tt_um_MichaelBell_tinyQV tt(
        .ui_in(bidir_in[7:0]),
        .uo_out(bidir_out[24:16]),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(1'b1),
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(input_in[0]),
        .uart_tx(bidir_out[25]),
        .uart_rts(bidir_out[26]),
        .debug_uart_txd(bidir_out[27]),
        .debug_signal(bidir_out[28])
    );

endmodule

`default_nettype wire

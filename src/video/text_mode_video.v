/*
 * Copyright (c) 2025 Michael Bell
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Wrapper for all TinyQV peripherals
//
// Address space:
// 0x800_0000 - 03f: Reserved by project wrapper (time, debug, etc)
// 0x800_0040 - 07f: GPIO configuration
// 0x800_0080 - 0bf: UART
// 0x800_00c0 - 0ff: Game pmod
// 0x800_0100 - 2bf: 7 user peripherals (64 bytes each, word and halfword access supported, each has an interrupt)
// 0x800_0400 - 43f: 4 simple peripherals (16 bytes each, byte access only)
module tinyQV_text_mode_video (
    input         clk,
    input         clk5x,        // Required for HDMI output, must be exactly 5x clk, but any phase is allowed.
    input         rst_n,

    input         use_hdmi,     // If high then clk5x must be supplied, and the output is HDMI not VGA.

    input [11:0]  addr_in,
    input [7:0]   data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input         data_write_n, // Only byte reads and writes supported
    input         data_read_n,

    output [7:0]  data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    input         data_read_complete,  // Set by TinyQV when a read is complete

    output        interrupt,

    output [7:0]  video_out
);

    wire text_ram_addr_n = addr_in[11:9] > 3'b101;
    wire font_ram_addr_n = addr_in[11:10] != 2'b11;

    // VGA signals
    wire hsync;
    wire vsync;
    reg [1:0] R;
    reg [1:0] G;
    reg [1:0] B;
    reg hsync_r;
    reg vsync_r;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    hvsync_generator sync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    wire [7:0] text_out;
    wire [7:0] font_out;
    wire [7:0] char_data;
    wire text_read = pix_x[1:0] == 2'b10;
    wire [11:0] text_addr = pix_y[8:4] * 12'd80 + pix_x[8:3];
    text_ram i_text(
        .clk(clk),
        .rstn(rst_n),
        .data_addr(text_read ? text_addr : addr_in),
        .data_write_n(data_write_n | text_ram_addr_n | pix_x[1]),
        .data_in(data_in),
        .data_out(text_out)
    );

    wire font_read = pix_x[1:0] == 2'b11;
    font_8x16 i_font (
        .clk(clk),
        .rstn(rst_n),
        .data_addr(addr_in[9:0]),
        .data_write_n(data_write_n | font_ram_addr_n | pix_x[1]),
        .data_in(data_in),
        .data_out(font_out),
        .char_read(font_read),
        .char_in(text_out[6:0]),
        .y(pix_y[3:0]),
        .x(pix_x[2]),
        .char_data(char_data)
    );

    wire data_txn = !data_read_n || !data_write_n;
    //reg data_txn_r;
    reg data_ready_r;
    always @(posedge clk) begin
        //data_txn_r <= data_txn;
        data_ready_r <= !pix_x[1] && data_txn;
    end

    wire [1:0] char_colour = char_data[{pix_x[1:0], 1'b0} +: 2];

    // TODO
    always @(posedge clk) begin
        R <= video_active ? char_colour : 2'b00;
        G <= video_active ? char_colour : 2'b00;
        B <= video_active ? char_colour : 2'b00;
        hsync_r <= hsync;
        vsync_r <= vsync;
    end

    // VGA for now
    assign video_out = {hsync_r, B[0], G[0], R[0], vsync_r, B[1], G[1], R[1]};

    assign data_out = font_ram_addr_n ? text_out : font_out;
    assign data_ready = data_ready_r;

    // TODO
    assign interrupt = 1'b0;

endmodule

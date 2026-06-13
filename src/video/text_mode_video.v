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

    wire text_ram_addr_n = addr_in[11:9] >= 3'b101;
    wire font_ram_addr_n = addr_in[11:10] != 2'b11;
    wire reg_addr = addr_in[11:9] == 3'b101;

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
    wire [11:0] text_addr_y = pix_y[8:4] * 12'd80;
    wire end_of_row = pix_x[9:7] >= 3'b101;
    wire end_of_text_row = end_of_row && pix_y[3:0] == 4'b1111;
    wire [6:0] text_addr_x = end_of_row ? (end_of_text_row ? 7'd80 : 7'd0) : pix_x[9:3] + {6'b0, pix_x[2]};
    wire [11:0] text_addr = text_addr_y + {5'b0, text_addr_x};
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
        .y(pix_y[3:0] + {3'b0, end_of_row}),
        .x(~pix_x[2]),
        .char_data(char_data)
    );

    reg use_alt; 
    always @(posedge clk) begin
        if (font_read) use_alt <= text_out[7];
    end

    wire data_txn = !data_read_n || !data_write_n;
    reg data_ready_r;
    always @(posedge clk) begin
        data_ready_r <= !pix_x[1] && data_txn;
    end

    // Could use latches, but lets avoid that for now
    reg [5:0] colour;
    reg [5:0] alt_colour;
    reg [1:0] int_enable;
    reg [1:0] int_status;
    reg [7:0] reg_data_out;

    always @(posedge clk) begin
        if (~rst_n) begin
            colour <= 6'b000111;
            alt_colour <= 6'b000010;
            int_enable <= 2'b00;
            int_status <= 2'b00;
        end else begin
            if (!data_write_n && reg_addr) begin
                case (addr_in[1:0])
                    2'b00: colour <= data_in[5:0];
                    2'b01: alt_colour <= data_in[5:0];
                    2'b10: int_enable <= data_in[1:0];
                    2'b11:;
                endcase
            end
        end
    end

    always @(*) begin
        case (addr_in[1:0])
            2'b00: reg_data_out = {2'h0, colour};
            2'b01: reg_data_out = {2'h0, alt_colour};
            2'b10: reg_data_out = {6'h0, int_enable};
            2'b11: reg_data_out = {6'h0, int_status};
        endcase
    end

    wire [1:0] char_colour = char_data[{pix_x[1:0], 1'b0} +: 2];
    wire [2:0] fg_colour = use_alt ? alt_colour[2:0] : colour[2:0];
    wire [2:0] bg_colour = use_alt ? alt_colour[5:3] : colour[5:3];
    reg [1:0] red;
    reg [1:0] green;
    reg [1:0] blue;
    always @(*) begin
        if (fg_colour[2] == bg_colour[2]) red = {2{fg_colour[2]}};
        else red = char_colour ^ {2{bg_colour[2]}};
        if (fg_colour[1] == bg_colour[1]) green = {2{fg_colour[1]}};
        else green = char_colour ^ {2{bg_colour[1]}};
        if (fg_colour[0] == bg_colour[0]) blue = {2{fg_colour[0]}};
        else blue = char_colour ^ {2{bg_colour[0]}};
    end

    always @(posedge clk) begin
        R <= video_active ? red : 2'b00;
        G <= video_active ? green : 2'b00;
        B <= video_active ? blue : 2'b00;
        hsync_r <= hsync;
        vsync_r <= vsync;
    end

    // VGA for now
    assign video_out = {hsync_r, B[0], G[0], R[0], vsync_r, B[1], G[1], R[1]};

    wire [7:0] data_out_imm =  reg_addr ? reg_data_out : 
            font_ram_addr_n ? text_out : font_out;

    reg [7:0] data_out_r;
    always @(posedge clk) begin
        if (data_ready_r) data_out_r <= data_out_imm;
    end

    assign data_out = data_ready_r ? data_out_imm : data_out_r;
    assign data_ready = data_ready_r;

    assign interrupt = |(int_status & int_enable);

    wire _unused = &{pix_y[9], data_read_complete, 1'b0};

endmodule

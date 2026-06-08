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

    input         use_hdmi_n,     // If high then clk5x must be supplied, and the output is HDMI not VGA.

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
    reg rst_n_and_en;

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
    reg video_active_r;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    hvsync_generator sync_gen (
        .clk(clk),
        .rst_n(rst_n_and_en),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    reg [4:0] scroll_offset;
    wire [7:0] text_out;
    wire [7:0] font_out;
    wire [7:0] char_data;
    wire text_read = pix_x[1:0] == 2'b10;
    wire [4:0] row_addr = (pix_y[9] ? 5'h1f : pix_y[8:4]) + scroll_offset;
    wire [11:0] text_addr_y = row_addr * 12'd80;
    wire end_of_row = pix_x[9:7] >= 3'b101;
    wire end_of_text_row = end_of_row && (pix_y[3:0] == 4'b1111 || pix_y[9]);
    wire [6:0] text_addr_x = end_of_row ? (end_of_text_row ? 7'd80 : 7'd0) : pix_x[9:3] + {6'b0, pix_x[2]};
    wire [11:0] text_addr_unwrapped = text_addr_y + {5'b0, text_addr_x};
    wire [11:0] text_addr = {(text_addr_unwrapped[11] & text_addr_unwrapped[9]) ? 3'b000 : text_addr_unwrapped[11:9], text_addr_unwrapped[8:0]};
    text_ram i_text(
        .clk(clk),
        .rstn(rst_n_and_en),
        .data_addr(text_read ? text_addr : addr_in),
        .data_write_n(data_write_n | text_ram_addr_n | pix_x[1]),
        .data_in(data_in),
        .data_out(text_out)
    );

    wire font_read = pix_x[1:0] == 2'b11;
    font_8x16 i_font (
        .clk(clk),
        .rstn(rst_n_and_en),
        .data_addr(addr_in[9:0]),
        .data_write_n(data_write_n | font_ram_addr_n | pix_x[1]),
        .data_in(data_in),
        .data_out(font_out),
        .char_read(font_read),
        .char_in(text_out[6:0]),
        .y((pix_y[3:0] + {3'b0, end_of_row}) & {4{~pix_y[9]}}),
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
    reg video_enable;
    reg [5:0] colour;
    reg [5:0] alt_colour;
    reg [1:0] int_enable;
    reg [1:0] int_status;
    reg [7:0] reg_data_out;

    always @(posedge clk) begin
        if (~rst_n) begin
            video_enable <= 0;
            scroll_offset <= 0;
            colour <= 6'b000111;
            alt_colour <= 6'b000010;
            int_enable <= 2'b00;
            int_status <= 2'b00;
        end else begin
            if (!data_write_n && reg_addr) begin
                case (addr_in[2:0])
                    3'b000: video_enable <= data_in[0];
                    3'b001: scroll_offset <= data_in[4:0];
                    3'b010: int_enable <= data_in[1:0];
                    3'b100: colour <= data_in[5:0];
                    3'b101: alt_colour <= data_in[5:0];
                    default:;
                endcase
            end
        end
    end

    always @(negedge clk) begin
        rst_n_and_en <= rst_n & video_enable;
    end

    always @(*) begin
        case (addr_in[2:0])
            3'b000: reg_data_out = {7'h0, video_enable};
            3'b001: reg_data_out = {3'h0, scroll_offset};
            3'b010: reg_data_out = {6'h0, int_enable};
            3'b011: reg_data_out = {6'h0, int_status};
            3'b100: reg_data_out = {2'h0, colour};
            3'b101: reg_data_out = {2'h0, alt_colour};
            default: reg_data_out = 8'h0;
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
        video_active_r <= video_active;
    end

    reg rst_5x_sync;
    reg rst_n_and_en_5x;
    always @(posedge clk5x) begin
        rst_5x_sync <= rst_n_and_en;
        rst_n_and_en_5x <= rst_5x_sync;
    end

    wire [3:0] dvi_p;
    wire [3:0] dvi_n;
    smoldvi i_dvi (
        .clk_pix(clk),
        .rst_n_pix(rst_n_and_en),
        .clk_bit(clk5x),
        .rst_n_bit(rst_n_and_en_5x),
        .r(R),
        .g(G),
        .b(B),
        .hsync(hsync_r),
        .vsync(vsync_r),
        .den(video_active_r),
        .dvi_p(dvi_p),
        .dvi_n(dvi_n)
    );

    assign video_out = use_hdmi_n ? {hsync_r, vsync_r, B[0], B[1], G[0], G[1], R[0], R[1]} :
                                    {dvi_n[3], dvi_p[3], dvi_n[0], dvi_p[0], dvi_n[1], dvi_p[1], dvi_n[2], dvi_p[2]};

    wire [7:0] data_out_imm =  reg_addr ? reg_data_out : 
            font_ram_addr_n ? text_out : font_out;

    reg [7:0] data_out_r;
    always @(posedge clk) begin
        if (data_ready_r) data_out_r <= data_out_imm;
    end

    assign data_out = data_ready_r ? data_out_imm : data_out_r;
    assign data_ready = data_ready_r;

    assign interrupt = |(int_status & int_enable);

    wire _unused = &{data_read_complete, 1'b0};

endmodule

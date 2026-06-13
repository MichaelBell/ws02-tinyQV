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
module tinyQV_peripherals #(parameter CLOCK_KHZ=25200) (
    input         clk,
    input         rst_n,

    input  [7:0]  ui_in,        // The input PMOD, always available
    input  [7:0]  ui_in_raw,    // The input PMOD, not synchronized
    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected

    output reg    audio,        // An extra output that can be selected on to uio[7]
    output        audio_select, // Whether audio should be selected on uio[7] (resets to 0).

    output        uart_tx,
    output        uart_rts,
    input         uart_rx,

    input [10:0]  addr_in,
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits

    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    input         data_read_complete,  // Set by TinyQV when a read is complete

    output [6:2] user_interrupts  // User peripherals get interrupts 2-6
);

    localparam NUM_USER_PERI = 8;
    localparam NUM_SIMPLE_PERI = 4;

    // Registered data out to TinyQV
    reg  [31:0] data_out_r;
    reg         data_out_hold;
    reg         data_ready_r;

    wire        read_req = data_read_n != 2'b11;

    // Muxed data out direct from selected peripheral
    reg [31:0] data_from_peri;
    reg        data_ready_from_peri;

    // Must mask the data_read_n to avoid extra read while
    // buffering the result
    wire [1:0] data_read_n_peri;
    assign data_read_n_peri = data_read_n | {2{data_ready_r}};

    wire [31:0] data_from_user_peri   [0:NUM_USER_PERI-1];
    wire [7:0]  data_from_simple_peri [0:NUM_SIMPLE_PERI-1];
    wire        data_ready_from_user_peri   [0:NUM_USER_PERI-1];

    wire [7:0]  uo_out_from_user_peri   [0:NUM_USER_PERI-1];
    wire [7:0]  uo_out_from_simple_peri [0:NUM_SIMPLE_PERI-1];
    reg [7:0] uo_out_comb;
    assign uo_out = uo_out_comb;

    // Rebuffer reset on positive edge of clock.  This is fine providing peripherals
    // don't use async reset.
    (* keep *) reg rst_n_rebuf;
    /* verilator lint_off SYNCASYNCNET */
    (* keep *) reg rst_n_rebuf_negedge;
    /* verilator lint_on SYNCASYNCNET */
    always @(posedge clk) begin
        rst_n_rebuf <= rst_n;
    end
    always @(negedge clk) begin
        rst_n_rebuf_negedge <= rst_n_rebuf;
    end

    // Register the data output from the peripheral.  This improves timing and
    // also simplifies the peripheral interface (no need for the peripheral to care
    // about holding data_out until data_read_complete - it looks like it is read
    // synchronously).
    always @(posedge clk) begin
        if (!rst_n_rebuf) begin
            data_out_hold <= 0;
        end else begin
            if (data_read_complete) data_out_hold <= 0;

            if (!data_out_hold && data_ready_from_peri && data_read_n != 2'b11) begin
                data_out_hold <= 1;
                data_out_r <= data_from_peri;
            end

            // Data ready must be registered because data_out is.
            data_ready_r <= read_req && data_ready_from_peri;
        end
    end

    assign data_out = data_out_r;
    assign data_ready = data_ready_r || data_write_n != 2'b11;

    // --------------------------------------------------------------------- //
    // Decode the address to select the active peripheral

    localparam PERI_GPIO = 1;
    localparam PERI_UART = 2;

    reg [NUM_USER_PERI-1:0] peri_user;
    reg [NUM_SIMPLE_PERI-1:0] peri_simple;

    always @(*) begin
        peri_user = 0;
        peri_simple = 0;

        if (addr_in[10:9] == 2'b10) begin
            peri_simple[addr_in[5:4]] = 1;
            data_from_peri = {24'h0, data_from_simple_peri[addr_in[5:4]]};
            data_ready_from_peri = 1;
        end else begin
            peri_user[addr_in[8:6]] = 1;
            data_from_peri = data_from_user_peri[addr_in[8:6]];
            data_ready_from_peri = data_ready_from_user_peri[addr_in[8:6]];
        end
    end

    assign data_from_user_peri[0] = 32'h0;
    assign data_ready_from_user_peri[0] = 0;
    assign uo_out_from_user_peri[0] = 8'h0;

    // --------------------------------------------------------------------- //
    // GPIO

    reg [2:0] audio_func_sel;
    reg [4:0] gpio_out_func_sel [0:7];
    reg [7:0] gpio_out;

    always @(posedge clk) begin
        if (!rst_n_rebuf) begin
            gpio_out <= 0;
        end else if (peri_user[PERI_GPIO]) begin
            if (addr_in[5:0] == 6'h0) begin
                if (data_write_n != 2'b11) gpio_out <= data_in[7:0];
            end
        end
    end

    assign data_from_user_peri[PERI_GPIO] = (addr_in[5:0] == 6'h0) ? {24'h0, gpio_out} :
                                            (addr_in[5:0] == 6'h4) ? {24'h0, ui_in}    :
                                            (addr_in[5:0] == 6'h10)? {29'h0, audio_func_sel} :
                                            ({addr_in[5], addr_in[1:0]} == 3'b100) ? {27'h0, gpio_out_func_sel[addr_in[4:2]][4:0] } :
                                            32'h0;
    assign data_ready_from_user_peri[PERI_GPIO] = 1;
    assign uo_out_from_user_peri[PERI_GPIO] = gpio_out;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin
            always @(posedge clk) begin
                if (!rst_n_rebuf) begin
                    gpio_out_func_sel[i] <= (i == 0 || i == 1) ? PERI_UART : PERI_GPIO;
                end else if (peri_user[PERI_GPIO]) begin
                    if ({addr_in[5], addr_in[1:0]} == 3'b100 && addr_in[4:2] == i) begin
                        if (data_write_n != 2'b11) gpio_out_func_sel[i] <= {data_in[4:0]};
                    end
                end
            end

            always @(*) begin
                uo_out_comb[i] = 0;

                if (gpio_out_func_sel[i][4]) begin
                    uo_out_comb[i] = uo_out_from_simple_peri[gpio_out_func_sel[i][1:0]][i];
                end else begin
                    uo_out_comb[i] = uo_out_from_user_peri[gpio_out_func_sel[i][2:0]][i];
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n_rebuf) begin
            audio_func_sel <= 0;
        end else if (peri_user[PERI_GPIO]) begin
            if (addr_in[5:0] == 6'h10) begin
                if (data_write_n != 2'b11) audio_func_sel <= data_in[2:0];
            end
        end
    end

    always @(posedge clk) begin
        case (audio_func_sel[1:0])
            2'b00: audio <= uo_out_from_user_peri[5][7];   // PWL synth right
            2'b01: audio <= uo_out_from_user_peri[4][7];   // Pulse TX
            2'b10: audio <= uo_out_from_simple_peri[3][0];  // AY-8913
            2'b11: audio <= uo_out_from_simple_peri[2][7];  // Matt PWM
        endcase
    end

    assign audio_select = audio_func_sel[2];

    // --------------------------------------------------------------------- //
    // UART

    tqvp_uart_wrapper #(.CLOCK_KHZ(CLOCK_KHZ)) i_uart (
        .clk(clk),
        .rst_n(rst_n_rebuf),

        .ui_in(ui_in),
        .uart_rx(uart_rx),
        .uo_out(uo_out_from_user_peri[PERI_UART]),

        .address(addr_in[5:0]),
        .data_in(data_in),

        .data_write_n(data_write_n    | {2{~peri_user[PERI_UART]}}),
        .data_read_n(data_read_n_peri | {2{~peri_user[PERI_UART]}}),

        .data_out(data_from_user_peri[PERI_UART]),
        .data_ready(data_ready_from_user_peri[PERI_UART]),

        .user_interrupt(user_interrupts[PERI_UART+1:PERI_UART])
    );

    assign uart_tx = uo_out_from_user_peri[PERI_UART][0];
    assign uart_rts = uo_out_from_user_peri[PERI_UART][1];

    // Peripheral 3 is a full peripheral but with no interrupt
    tqvp_game_pmod i_user_peri03(
        .clk(clk),
        .rst_n(rst_n_rebuf),

        .ui_in(ui_in),
        .uo_out(uo_out_from_user_peri[3]),

        .address(addr_in[5:0]),
        .data_in(data_in),

        .data_write_n(data_write_n    | {2{~peri_user[3]}}),
        .data_read_n(data_read_n_peri | {2{~peri_user[3]}}),

        .data_out(data_from_user_peri[3]),
        .data_ready(data_ready_from_user_peri[3])
    );

    // --------------------------------------------------------------------- //
    // Full interface peripherals

    tqvp_hx2003_pulse_transmitter i_user_peri04(
        .clk(clk),
        .rst_n(rst_n_rebuf),

        .ui_in(ui_in),
        .uo_out(uo_out_from_user_peri[4]),

        .address(addr_in[5:0]),
        .data_in(data_in),

        .data_write_n(data_write_n    | {2{~peri_user[4]}}),
        .data_read_n(data_read_n_peri | {2{~peri_user[4]}}),

        .data_out(data_from_user_peri[4]),
        .data_ready(data_ready_from_user_peri[4]),

        .user_interrupt(user_interrupts[4])
    );

    tqvp_toivoh_pwl_synth i_user_peri05 (
        .clk(clk),
        .rst_n(rst_n_rebuf_negedge),

        .ui_in(ui_in),
        .uo_out(uo_out_from_user_peri[5]),

        .address(addr_in[5:0]),
        .data_in(data_in),

        .data_write_n(data_write_n    | {2{~peri_user[5]}}),
        .data_read_n(data_read_n_peri | {2{~peri_user[5]}}),

        .data_out(data_from_user_peri[5]),
        .data_ready(data_ready_from_user_peri[5]),

        .user_interrupt(user_interrupts[5])
    );

    tqvp_rebelmike_vga_gfx i_user_peri06 (
        .clk(clk),
        .rst_n(rst_n_rebuf),

        .ui_in(ui_in),
        .uo_out(uo_out_from_user_peri[6]),

        .address(addr_in[5:0]),
        .data_in(data_in),

        .data_write_n(data_write_n    | {2{~peri_user[6]}}),
        .data_read_n(data_read_n_peri | {2{~peri_user[6]}}),

        .data_out(data_from_user_peri[6]),
        .data_ready(data_ready_from_user_peri[6]),

        .user_interrupt(user_interrupts[6])
    );

    tqvp_full_empty_no_irq i_user_peri07 (
        .clk(clk),
        .rst_n(rst_n_rebuf),

        .ui_in(ui_in),
        .uo_out(uo_out_from_user_peri[7]),

        .address(addr_in[5:0]),
        .data_in(data_in),

        .data_write_n(data_write_n    | {2{~peri_user[7]}}),
        .data_read_n(data_read_n_peri | {2{~peri_user[7]}}),

        .data_out(data_from_user_peri[7]),
        .data_ready(data_ready_from_user_peri[7])
    );

    // --------------------------------------------------------------------- //
    // Byte interface peripherals

    tqvp_spi_peripheral i_simple_peri16 (
        .clk(clk),
        .rst_n(rst_n_rebuf),

        .ui_in(ui_in_raw),
        .uo_out(uo_out_from_simple_peri[0]),

        .address(addr_in[3:0]),

        .data_write((data_write_n != 2'b11) & peri_simple[0]),
        .data_in(data_in[7:0]),

        .data_out(data_from_simple_peri[0])
    );

    tqvp_rebeccargb_universal_decoder i_simple_peri17 (
        .clk(clk),
        .rst_n(rst_n_rebuf),

        .ui_in(ui_in),
        .uo_out(uo_out_from_simple_peri[1]),

        .address(addr_in[3:0]),

        .data_write((data_write_n != 2'b11) & peri_simple[1]),
        .data_in(data_in[7:0]),

        .data_out(data_from_simple_peri[1])
    );

    tqvp_matt_pwm matt_pwm (
        .clk(clk),
        .rst_n(rst_n_rebuf),

        .ui_in(ui_in),
        .uo_out(uo_out_from_simple_peri[2]),

        .address(addr_in[3:0]),

        .data_write((data_write_n != 2'b11) & peri_simple[2]),
        .data_in(data_in[7:0]),

        .data_out(data_from_simple_peri[2])
    );

    tqvp_rejunity_ay8913 i_simple_peri19(
        .clk(clk),
        .rst_n(rst_n_rebuf),
        .ui_in(ui_in),
        .uo_out(uo_out_from_simple_peri[3]),

        .address(addr_in[3:0]),

        .data_write((data_write_n != 2'b11) & peri_simple[3]),
        .data_in(data_in[7:0]),

        .data_out(data_from_simple_peri[3])
    );

endmodule

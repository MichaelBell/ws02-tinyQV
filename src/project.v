/*
 * Copyright (c) 2024 Michael Bell
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_MichaelBell_tinyQV #(parameter CLOCK_KHZ=25200) (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [8:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path - only some bits used
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clk5x,
    input  wire       use_hdmi_n,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire       uart_rts,
    output wire       debug_uart_txd,
    output wire       debug_signal,
    output wire [7:0] video_out,
    inout wire       dac_out
);

    // Address to peripheral map
    localparam PERI_NONE = 4'h0;
    localparam PERI_ID = 4'h2;
    localparam PERI_GPIO_OUT_SEL = 4'h3;
    localparam PERI_DEBUG_UART = 4'h6;
    localparam PERI_DEBUG_UART_STATUS = 4'h7;
    localparam PERI_TIME_LIMIT = 4'hB;
    localparam PERI_DEBUG = 4'hC;
    localparam PERI_DAC = 4'hD;
    localparam PERI_VIDEO = 4'hE;
    localparam PERI_USER = 4'hF;

    // Bidirs are used for SPI interface
    wire [3:0] qspi_data_in = {uio_in[5:4], uio_in[2:1]};
    wire [3:0] qspi_data_out;
    wire [3:0] qspi_data_oe;
    wire       qspi_clk_out;
    wire       qspi_flash_select;
    wire       qspi_ram_a_select;
    wire       qspi_ram_b_select;
    wire       audio;
    wire       audio_select;
    wire [7:0] audio_sample;
    assign uio_out = {audio_select ? audio : qspi_ram_b_select, qspi_ram_a_select, qspi_data_out[3:2], 
                      qspi_clk_out, qspi_data_out[1:0], qspi_flash_select};
    assign uio_oe = rst_n ? {2'b11, qspi_data_oe[3:2], 1'b1, qspi_data_oe[1:0], 1'b1} : 8'h00;
    assign uo_out[8] = audio;

    wire [3:0] qspi_data_in_ctrl;
    reg  [3:0] qspi_config;
    wire [3:0] qspi_data_out_ctrl;
    wire [3:0] qspi_data_oe_ctrl;
    wire       qspi_clk_out_ctrl;
    wire       qspi_flash_select_ctrl;
    wire       qspi_ram_a_select_ctrl;
    wire       qspi_ram_b_select_ctrl;
    wire [3:0] qspi_data_out_setup;
    wire [3:0] qspi_data_oe_setup;
    wire       qspi_clk_out_setup;
    wire       qspi_flash_select_setup;
    wire       qspi_ram_a_select_setup;
    wire       qspi_ram_b_select_setup;
    wire       setup_done;
    reg        setup_rst_n;

    wire [27:0] addr;
    wire  [1:0] write_n;
    wire  [1:0] read_n;
    wire        read_complete;
    wire [31:0] data_to_write;

    wire        data_ready;
    reg [31:0] data_from_read;

    wire       debug_instr_complete;
    wire       debug_instr_ready;
    wire       debug_instr_valid;
    wire       debug_fetch_restart;
    wire       debug_data_ready;
    wire       debug_interrupt_pending;
    wire       debug_branch;
    wire       debug_early_branch;
    wire       debug_ret;
    wire       debug_reg_wen;
    wire       debug_counter_0;
    wire       debug_data_continue;
    wire       debug_stall_txn;
    wire       debug_stop_txn;
    wire [3:0] debug_rd;

    reg  [6:6] gpio_out_sel;

    reg [3:0] connect_peripheral;

    // Debug
    reg debug_register_data;
    reg [3:0] debug_rd_r;

    // Debug UART - runs fast to reduce the width of the count necessary for the divider!
    wire debug_uart_tx_busy;
    wire debug_uart_tx_start = write_n != 2'b11 && connect_peripheral == PERI_DEBUG_UART;

    // Time
    reg [6:2] time_limit;
    wire time_pulse;

    // Peripherals interface
    wire [7:0] peri_out;
    wire [31:0] peri_data_out;
    wire        peri_data_ready;
    wire [6:2] peri_interrupts;

    // Peripherals get synchronized ui_in.
    reg [7:0] ui_in_sync0;
    reg [7:0] ui_in_sync;
    reg       uart_rx_sync0;
    reg       uart_rx_sync;
    always @(posedge clk) begin
        ui_in_sync0 <= ui_in;
        uart_rx_sync0 <= uart_rx;
        ui_in_sync <= ui_in_sync0;
        uart_rx_sync <= uart_rx_sync0;
    end

    // DAC
    reg dac_select;
    reg [7:0] dac_data;

    // Text console interface
    wire video_interrupt;
    wire [7:0] video_data_out;
    wire       video_data_ready;

    // Interrupt requests
    wire [7:0] interrupt_req = {video_interrupt, peri_interrupts, ui_in_sync[1:0]};
    // Register the reset on the negative edge of clock for safety.
    // This also allows the option of async reset in the design, which might be preferable in some cases
    always @(negedge clk) setup_rst_n <= rst_n;

    /* verilator lint_off SYNCASYNCNET */
    (* keep *) reg rst_reg_n;
    /* verilator lint_on SYNCASYNCNET */
    always @(negedge clk) rst_reg_n <= rst_n & setup_done;

    always @(posedge clk) begin
        if (!setup_rst_n) begin
            qspi_config <= qspi_data_in;
        end
    end

    assign qspi_data_in_ctrl = rst_reg_n ? qspi_data_in : qspi_config;
    assign qspi_data_out     = rst_reg_n ? qspi_data_out_ctrl : qspi_data_out_setup;
    assign qspi_data_oe      = rst_reg_n ? qspi_data_oe_ctrl  : qspi_data_oe_setup;
    assign qspi_clk_out      = rst_reg_n ? qspi_clk_out_ctrl  : qspi_clk_out_setup;
    assign qspi_flash_select = rst_reg_n ? qspi_flash_select_ctrl : qspi_flash_select_setup;
    assign qspi_ram_a_select = rst_reg_n ? qspi_ram_a_select_ctrl : qspi_ram_a_select_setup;
    assign qspi_ram_b_select = rst_reg_n ? qspi_ram_b_select_ctrl : qspi_ram_b_select_setup;

    qspi_setup i_setup(
        .clk(clk),
        .rstn(setup_rst_n),

        .spi_data_out(qspi_data_out_setup),
        .spi_data_oe(qspi_data_oe_setup),
        .spi_clk_out(qspi_clk_out_setup),
        .spi_flash_select(qspi_flash_select_setup),
        .spi_ram_a_select(qspi_ram_a_select_setup),
        .spi_ram_b_select(qspi_ram_b_select_setup),

        .done(setup_done)
    );

    tinyQV i_tinyqv(
        .clk(clk),
        .rstn(rst_reg_n),

        .data_addr(addr),
        .data_write_n(write_n),
        .data_read_n(read_n),
        .data_read_complete(read_complete),
        .data_out(data_to_write),

        .data_ready(data_ready),
        .data_in(data_from_read),

        .interrupt_req(interrupt_req),
        .time_pulse(time_pulse),

        .spi_data_in(qspi_data_in_ctrl),
        .spi_data_out(qspi_data_out_ctrl),
        .spi_data_oe(qspi_data_oe_ctrl),
        .spi_clk_out(qspi_clk_out_ctrl),
        .spi_flash_select(qspi_flash_select_ctrl),
        .spi_ram_a_select(qspi_ram_a_select_ctrl),
        .spi_ram_b_select(qspi_ram_b_select_ctrl),

        .debug_instr_complete(debug_instr_complete),
        .debug_instr_ready(debug_instr_ready),
        .debug_instr_valid(debug_instr_valid),
        .debug_fetch_restart(debug_fetch_restart),
        .debug_data_ready(debug_data_ready),
        .debug_interrupt_pending(debug_interrupt_pending),
        .debug_branch(debug_branch),
        .debug_early_branch(debug_early_branch),
        .debug_ret(debug_ret),
        .debug_reg_wen(debug_reg_wen),
        .debug_counter_0(debug_counter_0),
        .debug_data_continue(debug_data_continue),
        .debug_stall_txn(debug_stall_txn),
        .debug_stop_txn(debug_stop_txn),
        .debug_rd(debug_rd)
    );

    assign uo_out[0] = peri_out[0];
    assign uo_out[1] = peri_out[1];
    assign uo_out[2] = debug_register_data ? debug_rd_r[0] : peri_out[2];
    assign uo_out[3] = debug_register_data ? debug_rd_r[1] : peri_out[3];
    assign uo_out[4] = debug_register_data ? debug_rd_r[2] : peri_out[4];
    assign uo_out[5] = debug_register_data ? debug_rd_r[3] : peri_out[5];
    assign uo_out[6] = gpio_out_sel[6] ? peri_out[6] : debug_uart_txd;
    assign uo_out[7] = peri_out[7];

    tinyQV_peripherals #(.CLOCK_KHZ(CLOCK_KHZ)) i_peripherals (
        .clk(clk),
        .rst_n(rst_reg_n),

        .ui_in(ui_in_sync),
        .ui_in_raw(ui_in),
        .uo_out(peri_out),

        .audio(audio),
        .audio_select(audio_select),

        .uart_rx(uart_rx_sync),
        .uart_tx(uart_tx),
        .uart_rts(uart_rts),

        .addr_in(addr[10:0]),
        .data_in(data_to_write),

        .data_write_n(write_n | {2{connect_peripheral != PERI_USER}}),
        .data_read_n(read_n),

        .data_out(peri_data_out),
        .data_ready(peri_data_ready),

        .data_read_complete(read_complete),

        .audio_sample(audio_sample),
        
        .user_interrupts(peri_interrupts)
    );

    always @(*) begin
        if ({addr[27:6], addr[1:0]} == 24'h800000) 
            connect_peripheral = addr[5:2];
        else if (addr[27:11] == 17'h10000)
            connect_peripheral = PERI_USER;
        else if (addr[27:23] == 5'h11)
            connect_peripheral = PERI_VIDEO;
        else
            connect_peripheral = PERI_NONE;
    end

    // Read data
    always @(*) begin
        case (connect_peripheral)
            PERI_ID:          data_from_read = "WS02";
            PERI_GPIO_OUT_SEL:data_from_read = {25'h0, gpio_out_sel, 6'h0};
            PERI_DEBUG_UART_STATUS: data_from_read = {31'h0, debug_uart_tx_busy};
            PERI_TIME_LIMIT:  data_from_read = {25'h0, time_limit, 2'b11};
            PERI_DAC:         data_from_read = {23'h0, dac_select, dac_data};
            PERI_VIDEO:       data_from_read = {24'h0, video_data_out};
            PERI_USER:        data_from_read = peri_data_out;
            default:          data_from_read = 32'hFFFF_FFFF;
        endcase
    end

    assign data_ready = (connect_peripheral == PERI_USER) ? peri_data_ready : 
                        (connect_peripheral == PERI_VIDEO) ? video_data_ready : 1'b1;

    // GPIO Out
    always @(posedge clk) begin
        if (!rst_reg_n) begin
            gpio_out_sel <= 1'b1;
            time_limit <= 5'd5;
        end
        if (write_n != 2'b11) begin
            if (connect_peripheral == PERI_GPIO_OUT_SEL) gpio_out_sel <= data_to_write[6:6];
            if (connect_peripheral == PERI_TIME_LIMIT) time_limit <= data_to_write[6:2];
        end
    end

    uart_tx #(.CLK_HZ(CLOCK_KHZ * 1_000), .BIT_RATE(1_000_000)) i_debug_uart_tx(
        .clk(clk),
        .resetn(rst_reg_n),
        .uart_txd(debug_uart_txd),
        .uart_tx_en(debug_uart_tx_start),
        .uart_tx_data(data_to_write[7:0]),
        .uart_tx_busy(debug_uart_tx_busy) 
    );

    reg [6:0] time_count;

    always @(posedge clk) begin
        if (!rst_reg_n) begin
            time_count <= 0;
        end else begin
            if (time_pulse) time_count <= 0;
            else time_count <= time_count + 1;
        end
    end
    assign time_pulse = time_count == {time_limit, 2'b11};

    // Debug
    always @(posedge clk) begin
        if (!rst_reg_n)
            debug_register_data <= ui_in[1];
        else if (write_n != 2'b11 && connect_peripheral == PERI_DEBUG)
            debug_register_data <= data_to_write[0];
    end

    always @(posedge clk) begin
        debug_rd_r <= debug_rd;
    end

    reg [15:0] debug_signals;
    always @(*) begin
        debug_signals  = {debug_instr_complete,
                          debug_instr_ready,
                          debug_instr_valid,
                          debug_fetch_restart,
                          read_n != 2'b11,
                          write_n != 2'b11,
                          debug_data_ready,
                          debug_interrupt_pending,
                          debug_branch,
                          debug_early_branch,
                          debug_ret,
                          debug_reg_wen,
                          debug_counter_0,
                          debug_data_continue,
                          debug_stall_txn,
                          debug_stop_txn};
    end
    assign debug_signal = debug_signals[ui_in[6:3]];

    tinyQV_text_mode_video i_video(
        .clk(clk),
        .clk5x(clk5x),
        .rst_n(rst_reg_n),
        .use_hdmi_n(use_hdmi_n),
        .addr_in(addr[11:0]),
        .data_in(data_to_write[7:0]),
        .data_write_n(write_n == 2'b11 || connect_peripheral != PERI_VIDEO),
        .data_read_n(read_n == 2'b11 || connect_peripheral != PERI_VIDEO),
        .data_out(video_data_out),
        .data_ready(video_data_ready),
        .data_read_complete(read_complete),
        .interrupt(video_interrupt),
        .video_out(video_out)
    );

    always @(posedge clk) begin
        if (!rst_reg_n) begin
            dac_select <= 0;
            dac_data <= '0;
        end else if (write_n != 2'b11 && connect_peripheral == PERI_DAC) begin
            dac_data <= data_to_write[8] ? audio_sample : data_to_write[7:0];
            dac_select <= data_to_write[8];
        end else if (dac_select) dac_data <= audio_sample;
    end

    wire [7:0] dac_buffered;
    gf180mcu_as_sc_mcu7t3v3__buff_4 dac_buf [7:0] (.A(dac_data), .Y(dac_buffered));

    r2r i_r2r(
        .b0(dac_buffered[0]),
        .b1(dac_buffered[1]),
        .b2(dac_buffered[2]),
        .b3(dac_buffered[3]),
        .b4(dac_buffered[4]),
        .b5(dac_buffered[5]),
        .b6(dac_buffered[6]),
        .b7(dac_buffered[7]),
        .out(dac_out)
    );

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, uio_in[7:6], uio_in[3], uio_in[0], read_complete, 1'b0};

endmodule

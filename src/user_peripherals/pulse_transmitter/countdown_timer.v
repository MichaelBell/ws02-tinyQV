/*
 * Copyright (c) 2025 HX2003
 * SPDX-License-Identifier: Apache-2.0
 */

// This module implements a repeating countdown timer.
// When en is 1, it generates a 1-cycle pulse after (duration + 2) << prescaler) number of clock cycles
// 
// When prescaler = 0, the total duration is (duration + 2) * 1 = duration + 2
// When prescaler = 1, the total duration is (duration + 2) * 2
// When prescaler = 2, the total duration is (duration + 2) * 4
// and so on...
//
// On pulse_out, the next counter value is loaded base on prescaler and duration parameters
//
// Note that prescaler and duration must be provided 1 cycle before en is 1

module countdown_timer #(
    parameter PRESCALER_WIDTH = 16,
    parameter TIMER_WIDTH = 8
) (
    input wire clk,
    input wire sys_rst_n,
    input wire en,
    input wire [($clog2(PRESCALER_WIDTH) - 1):0] prescaler,
    input wire [(TIMER_WIDTH - 1):0] duration,
    output wire request_data,
    output wire pulse_out
);  
    reg out;
    
    // shifting the duration is the simplest, but takes more logic gates
    // wire [(COUNTER_WIDTH - 1):0] counter_start = {1'b0, {{PRESCALER_WIDTH{1'b0}}, duration} << prescaler};

    simple_rising_edge_detector out_rising_edge_detector(
        .clk(clk),
        .rst_n(sys_rst_n),
        .sig_in(out),
        .pulse_out(pulse_out)
    );
    
    wire prescaler_overflow = prescaler_counter[PRESCALER_WIDTH] == 1'b1;
    wire counter_overflow = counter[TIMER_WIDTH] == 1'b1;

    // Request data when the counter reaches 0, provided the timer is enabled.
    assign request_data = en && (counter == 0) && prescaler_overflow;

    reg [(PRESCALER_WIDTH):0] prescaler_counter;
    wire [PRESCALER_WIDTH:0] prescaler_start_count = {1'b0, {{(PRESCALER_WIDTH - 1){1'b0}}, 1'b1} << prescaler} - 2;
    
    reg [TIMER_WIDTH:0] counter; // extra bit for rollover
    wire [TIMER_WIDTH:0] start_count = {1'b0, duration};  // extra bit for rollover

    always @(posedge clk) begin
        if (!sys_rst_n || !en) begin
            counter <= start_count;
            prescaler_counter <= prescaler_start_count;
            out <= 1'b0;
        end else begin
            if (prescaler_overflow) begin
                prescaler_counter <= prescaler_start_count;
                if (counter_overflow) begin
                    counter <= start_count;
                    out <= 1'b1;
                end else begin
                    out <= 1'b0;
                    counter <= counter - 1;
                end
            end else begin
                out <= 1'b0;
                prescaler_counter <= prescaler_counter - 1;
            end
        end
    end

endmodule
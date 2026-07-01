/*
 * Copyright (c) 2025 HX2003
 * SPDX-License-Identifier: Apache-2.0
 */

// Generates a 50% duty cycle wave

module carrier #(
    parameter TIMER_WIDTH = 11
) (
    input wire clk,           
    input wire sys_rst_n,            
    input wire en,
    input wire [(TIMER_WIDTH - 1): 0] duration,
    output reg out
);          

    reg [(TIMER_WIDTH - 1): 0] carrier_counter;

    always @(posedge clk) begin
        if (!sys_rst_n || !en) begin
            carrier_counter <= duration;
            out <= 0;
        end else begin
            if (carrier_counter == 0) begin
                carrier_counter <= duration;
                out <= !out;
            end else begin
                carrier_counter <= carrier_counter - 1;
            end
        end
    end
 
endmodule 
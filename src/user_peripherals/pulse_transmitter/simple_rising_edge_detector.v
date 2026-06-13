/*
 * Copyright (c) 2025 HX2003
 * SPDX-License-Identifier: Apache-2.0
 */

// Simple synchronous rising edge detector

module simple_rising_edge_detector (
    input wire clk,           
    input wire rst_n,            
    input wire sig_in,
    output wire pulse_out
);          

    reg sig_delayed;

    always @(posedge clk) begin
        if (!rst_n) begin
            sig_delayed <= 0;
        end else begin
            sig_delayed <= sig_in;
        end
    end

    assign pulse_out = sig_in && !sig_delayed;            
 
endmodule 
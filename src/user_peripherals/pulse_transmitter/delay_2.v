/*
 * Copyright (c) 2025 HX2003
 * SPDX-License-Identifier: Apache-2.0
 */

module delay_2 (
    input  wire clk,
    input  wire sys_rst_n,
    input  wire sig_in,
    output reg  sig_delayed_1_out,
    output reg  sig_delayed_2_out
);

    always @(posedge clk) begin
        if (!sys_rst_n) begin
            sig_delayed_1_out <= 1'b0;
            sig_delayed_2_out <= 1'b0;
        end else begin
            sig_delayed_1_out <= sig_in;
            sig_delayed_2_out <= sig_delayed_1_out;
        end
    end

endmodule
`default_nettype none

// Modified from htfab's version, https://github.com/htfab/tinyqv-baby-vga

module vga_timing_gfx (
    input wire clk,
    input wire rst_n,
    output reg [9:0] x,
    output reg [3:0] y_hi,
    output reg [5:0] y_lo,
    output reg hsync,
    output reg vsync,
    output wire blank
);

// 640x480 ~60Hz, (512x480 visible)

`define H_FPORCH (36 * 16)
`define H_SYNC   (37 * 16)
`define H_BPORCH (43 * 16)
`define H_NEXT   (45 * 16 + 15)
`define H_RST    (60 * 16)

`define V_ROLL   59
`define V_FPORCH (8 * 64)
`define V_SYNC   (8 * 64 + 10)
`define V_BPORCH (8 * 64 + 12)
`define V_NEXT   (8 * 64 + 34)

always @(posedge clk) begin
    if (!rst_n) begin
        x <= `H_RST;
        y_hi <= 0;
        y_lo <= 0;
        hsync <= 0;
        vsync <= 0;
    end else begin
        if (x == `H_NEXT) begin
            x <= `H_RST;
        end else begin
            x <= x + 1;
        end
        if (x == `H_SYNC) begin
            if({y_hi, y_lo} == `V_NEXT) begin
                y_hi <= 0;
                y_lo <= 0;
            end else if (y_lo == `V_ROLL) begin
                y_hi <= y_hi + 1;
                y_lo <= 0;
            end else begin
                y_lo <= y_lo + 1;
            end
        end
        // TODO: Check polarity
        hsync <= !(x >= `H_SYNC && x < `H_BPORCH);
        vsync <= !({y_hi, y_lo} >= `V_SYNC && {y_hi, y_lo} < `V_BPORCH);
    end
end

assign blank = (x[9] || y_hi[3]);

endmodule
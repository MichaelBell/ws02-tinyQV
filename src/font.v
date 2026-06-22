`default_nettype none

module font_8x16  (
    input         clk,
    input         rstn,

    input [9:0]   data_addr,
    input         data_write_n,

    input [7:0]   data_in,
    output [7:0]  data_out,

    input         char_read, // Data interface inactive on cycles when this is high
    input [6:0]   char_in,
    input [3:0]   y,
    input         x,
    output [7:0]  char_data
);

    wire [9:0] font_ram_addr;
    wire [7:0] font_ram_out;

    /* verilator lint_off PINMISSING */
    gf180mcu_ocd_ip_sram__sram1024x8m8wm1 i_sram (
        .CLK(clk),
        .CEN(!rstn),
        .GWEN(data_write_n | char_read),
        .WEN(8'hff),
        .A(font_ram_addr),
        .D(data_in),
        .Q(font_ram_out)
    );

    assign font_ram_addr = char_read ? {char_in[4:0], y, x} : data_addr;
    assign data_out = font_ram_out;

    reg [7:0] line_data;
    always @(*) begin
        case ({char_in, y, x})
`include "font/font_case.v"
            default: line_data = font_ram_out;
        endcase
    end

    reg [7:0] line_data_r;
    always @(posedge clk) begin
        line_data_r <= line_data;
    end

    assign char_data = line_data_r;

endmodule

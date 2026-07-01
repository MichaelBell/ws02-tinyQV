`default_nettype none

module text_ram #(parameter ADDR_BITS=12) (
    input         clk,
    input         rstn,

    input [ADDR_BITS-1:0] data_addr,
    input         data_write_n,

    input [7:0]   data_in,
    output [7:0]  data_out
);

    wire [2:0] write_enable_n;
    reg [1:0] ram_select_r;
    wire [7:0] data_out0;
    wire [7:0] data_out1;
    wire [7:0] data_out2;

    /* verilator lint_off PINMISSING */
    gf180mcu_ocd_ip_sram__sram1024x8m8wm1 i_sram0 (
        .CLK(clk),
        .CEN(!rstn),
        .GWEN(write_enable_n[0]),
        .WEN(8'h00),
        .A(data_addr[9:0]),
        .D(data_in),
        .Q(data_out0)
    );
    gf180mcu_ocd_ip_sram__sram1024x8m8wm1 i_sram1 (
        .CLK(clk),
        .CEN(!rstn),
        .GWEN(write_enable_n[1]),
        .WEN(8'h00),
        .A(data_addr[9:0]),
        .D(data_in),
        .Q(data_out1)
    );
    gf180mcu_ocd_ip_sram__sram512x8m8wm1 i_sram2 (
        .CLK(clk),
        .CEN(!rstn),
        .GWEN(write_enable_n[2]),
        .WEN(8'h00),
        .A(data_addr[8:0]),
        .D(data_in),
        .Q(data_out2)
    );
    /* verilator lint_on PINMISSING */

    generate
        for (genvar i=0; i<3; i += 1) begin : select
            assign write_enable_n[i] = data_write_n || (i != data_addr[11:10]);
        end
    endgenerate

    always @(posedge clk) begin
        ram_select_r[0] <= data_addr[11:10] == 0;
        ram_select_r[1] <= data_addr[10];
    end

    assign data_out = ram_select_r[0] ? data_out0 :
                      ram_select_r[1] ? data_out1 : data_out2;

endmodule

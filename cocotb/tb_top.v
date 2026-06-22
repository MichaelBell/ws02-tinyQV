

`default_nettype none

`include "slot_defines.svh"

module tb_top #(
    // Signal pads
    parameter NUM_INPUT_PADS = `NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS = `NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS = `NUM_ANALOG_PADS
)(
    inout [3:0] qspi_data
);

    reg uart_rx;
    reg prog_n;
    wire [3:0] input_PAD;
    assign input_PAD = {2'b00, prog_n, uart_rx};
    wire uart_tx;
    wire uart_rts;

    reg prog_cs;
    reg prog_sck;
    reg prog_mosi;
    wire prog_miso;

    reg [7:0] ui_in;
    wire [7:0] uio;
    wire [7:0] uo_out;
    wire audio;

    wire [NUM_BIDIR_PADS-1:0] bidir_PAD;

    assign bidir_PAD[7:0] = ui_in;
    assign uio[5:4] = qspi_data[3:2];
    assign uio[2:1] = qspi_data[1:0];
    assign bidir_PAD[15:8] = uio;
    assign uo_out = bidir_PAD[23:16];
    assign audio = bidir_PAD[24];
    assign uart_tx = bidir_PAD[25];
    assign uart_rts = bidir_PAD[26];
    assign prog_miso = bidir_PAD[29];
    assign bidir_PAD[32:30] = {prog_sck, prog_mosi, prog_cs};

    reg clk_PAD;
    reg rst_n_PAD;

    wire [3:0] analog_PAD;

`ifdef USE_POWER_PINS
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

    chip_top uut (
`ifdef USE_POWER_PINS
        .VDD(VPWR),
        .VSS(VGND),
`endif

        .clk_PAD(clk_PAD),
        .rst_n_PAD(rst_n_PAD),
        
        .input_PAD(input_PAD),
        .bidir_PAD(bidir_PAD),
        
        .analog_PAD(analog_PAD)
    );

endmodule


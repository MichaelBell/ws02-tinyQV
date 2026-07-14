`default_nettype none 
`timescale 1ns / 100ps

`include "slot_defines.svh"

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb #(
    // Signal pads
    parameter NUM_INPUT_PADS = `NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS = `NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS = `NUM_ANALOG_PADS
)();

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg clk5x;
  reg prog_clk;

  wire [NUM_INPUT_PADS-1:0] input_in;
  wire [NUM_INPUT_PADS-1:0] input_pu;
  wire [NUM_INPUT_PADS-1:0] input_pd;

  reg [NUM_BIDIR_PADS-1:0] bidir_in;
  wire [NUM_BIDIR_PADS-1:0] bidir_out;
  wire [NUM_BIDIR_PADS-1:0] bidir_oe;
  wire [NUM_BIDIR_PADS-1:0] bidir_cs;
  wire [NUM_BIDIR_PADS-1:0] bidir_sl;
  wire [NUM_BIDIR_PADS-1:0] bidir_ie;
  wire [NUM_BIDIR_PADS-1:0] bidir_pu;
  wire [NUM_BIDIR_PADS-1:0] bidir_pd;

  wire [NUM_ANALOG_PADS-1:0] analog;

  wire [7:0] ui_in;
  reg [7:0] ui_in_base;
  wire [8:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  assign uio_out = bidir_out[15:8];
  assign uo_out = bidir_out[24:16];
  assign uio_oe = bidir_oe[15:8];

  reg [3:0] qspi_data_in;
  reg [2:0] latency_cfg;
  reg use_latency_cfg_n;

  wire [3:0] qspi_data_out = {uio_out[5:4], uio_out[2:1]};
  wire [3:0] qspi_data_oe  = {uio_oe[5:4],  uio_oe[2:1]};
  wire qspi_clk_out = uio_out[3];
  wire qspi_flash_select = uio_out[0];
  wire qspi_ram_a_select = uio_out[6];
  wire qspi_ram_b_select = uio_out[7];

  wire spi_miso = ui_in_base[2];
  wire spi_cs = uo_out[4];
  wire spi_sck = uo_out[5];
  wire spi_mosi = uo_out[3];
  wire spi_dc = uo_out[2];

  wire audio = uo_out[8];

  wire mhz_clk = ui_in_base[3];
  wire game_latch = ui_in_base[4];
  wire game_clk = ui_in_base[5];
  wire game_data = ui_in_base[6];

  wire uart_tx = bidir_out[25];
  wire uart_rts = bidir_out[26];
  wire debug_uart_tx = bidir_out[27];
  wire debug_signal = bidir_out[28];
  reg uart_rx;
  assign ui_in = {uart_rx, game_data, game_clk, game_latch, mhz_clk, spi_miso, ui_in_base[1:0]};
  assign bidir_in[15:0] = {2'b00, use_latency_cfg_n ? qspi_data_in[3:2] : {1'b0, latency_cfg[2]}, 1'b0, use_latency_cfg_n ? qspi_data_in[1:0] : latency_cfg[1:0], 1'b0, ui_in};

  reg use_hdmi_n;
  assign input_in = {2'b00, use_hdmi_n, 1'b1, uart_rx};

  wire hsync = bidir_out[36];
  wire vsync = bidir_out[35];
  wire [1:0] red   = {bidir_out[29], bidir_out[30]};
  wire [1:0] green = {bidir_out[31], bidir_out[32]};
  wire [1:0] blue  = {bidir_out[33], bidir_out[34]};

  wire [3:0] dvi_p = {bidir_out[35], bidir_out[29], bidir_out[31], bidir_out[33]};
  wire [3:0] dvi_n = {bidir_out[36], bidir_out[30], bidir_out[32], bidir_out[34]};

`ifdef USE_POWER_PINS
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  chip_core #(
        .NUM_INPUT_PADS  (NUM_INPUT_PADS),
        .NUM_BIDIR_PADS  (NUM_BIDIR_PADS),
        .NUM_ANALOG_PADS (NUM_ANALOG_PADS)
    ) uut (

      // Include power ports for the Gate Level test:
`ifdef USE_POWER_PINS
      .VDD(VPWR),
      .VSS(VGND),
`endif

      .clk(clk),
      .rst_n(rst_n),
      .clk5x(clk5x),
      .prog_clk(prog_clk),

      .input_in(input_in),
      .input_pu(input_pu),
      .input_pd(input_pd),

      .bidir_in(bidir_in),
      .bidir_out(bidir_out),
      .bidir_oe(bidir_oe),
      .bidir_cs(bidir_cs),
      .bidir_sl(bidir_sl),
      .bidir_ie(bidir_ie),
      .bidir_pu(bidir_pu),
      .bidir_pd(bidir_pd),

      .dac_out(analog)
  );

endmodule

`default_nettype wire 

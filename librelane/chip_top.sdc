current_design $::env(DESIGN_NAME)
set_units -time ns

set clock_port __VIRTUAL_CLK__
if { [info exists ::env(CLOCK_PORT)] } {
    set port_count [llength $::env(CLOCK_PORT)]

    if { $port_count == "0" } {
        puts "\[WARNING] No CLOCK_PORT found. A dummy clock will be used."
    } elseif { $port_count != "1" } {
        puts "\[WARNING] Multi-clock files are not currently supported by the base SDC file. Only the first clock will be constrained."
    }

    if { $port_count > "0" } {
        set ::clock_port [lindex $::env(CLOCK_PORT) 0]
    }
}

if { $::env(CLOCK_PORT) == $::env(CLOCK_NET) } {
    set port_args [get_ports $clock_port]
} else {
    # This should actually use CLOCK_PIN?
    set port_args [get_pins [lindex $::env(CLOCK_NET) 0]]
}

puts "\[INFO] Using clock $clock_port…"
create_clock {*}$port_args -name clk_PAD -period $::env(CLOCK_PERIOD)
create_clock [get_pins clk5x_pad/Y] -name fast_clk -period [expr $::env(CLOCK_PERIOD) * 0.2]

set input_setup_delay_value [expr $::env(CLOCK_PERIOD) * 0.6]
set input_hold_delay_value [expr $::env(CLOCK_PERIOD) * 0.25]
set output_setup_delay_value [expr $::env(CLOCK_PERIOD) * 0.65]
set output_hold_delay_value 1

puts "\[INFO] Setting output delay to: $output_hold_delay_value / $output_setup_delay_value"
puts "\[INFO] Setting input delay to: $input_hold_delay_value / $input_setup_delay_value"

set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
}

set clocks [get_clocks $clock_port]

# Bidirectional pads
set clk_core_inout_ports [get_ports { 
    bidir_PAD[*]
}] 

set_input_delay -min $input_hold_delay_value -clock $clocks $clk_core_inout_ports
set_input_delay -max $input_setup_delay_value -clock $clocks $clk_core_inout_ports
set_output_delay -min $output_hold_delay_value -clock $clocks $clk_core_inout_ports
set_output_delay -max $output_setup_delay_value -clock $clocks $clk_core_inout_ports

# Lower delay on SPI clock output because it can be driven at negedge for timing tweaking
set spi_clk_setup_delay_value [expr $::env(CLOCK_PERIOD) * 0.18]
set_output_delay -clock $clocks -max $spi_clk_setup_delay_value {bidir_PAD[11]}

# Delays on user outputs
set_output_delay -clock $clocks -min 3 {bidir_PAD[16] bidir_PAD[17] bidir_PAD[18] bidir_PAD[19] bidir_PAD[20] bidir_PAD[21] bidir_PAD[22] bidir_PAD[23] bidir_PAD[24] bidir_PAD[25] bidir_PAD[26] bidir_PAD[27] bidir_PAD[28] bidir_PAD[29]}
set_output_delay -clock $clocks -max 1 {bidir_PAD[16] bidir_PAD[17] bidir_PAD[18] bidir_PAD[19] bidir_PAD[20] bidir_PAD[21] bidir_PAD[22] bidir_PAD[23] bidir_PAD[24] bidir_PAD[25] bidir_PAD[26] bidir_PAD[27] bidir_PAD[28] bidir_PAD[29]}

# Input-only pads
set_input_delay -min $input_hold_delay_value -clock $clocks input_PAD[0]
set_input_delay -max $input_setup_delay_value -clock $clocks input_PAD[0]

# Reset
set_input_delay 2 -clock $clocks {rst_n_PAD}

# Prog - basically ignore timing
set_input_delay 2 -clock $clocks {input_PAD[1]}
set_output_delay 2 -clock $clocks {bidir_PAD[37]}
set_input_delay 2 -clock $clocks {input_PAD[3]}
set_input_delay 2 -clock $clocks {input_PAD[4]}
set_input_delay 2 -clock $clocks {prog_clk_PAD}

# HDMI
set_input_delay 0 -clock fast_clk {input_PAD[2]}
set_output_delay -clock fast_clk -min 3 {bidir_PAD[29] bidir_PAD[30] bidir_PAD[31] bidir_PAD[32] bidir_PAD[33] bidir_PAD[34] bidir_PAD[35] bidir_PAD[36]}
set_output_delay -clock fast_clk -max -1 {bidir_PAD[29] bidir_PAD[30] bidir_PAD[31] bidir_PAD[32] bidir_PAD[33] bidir_PAD[34] bidir_PAD[35] bidir_PAD[36]}

# Output load
set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]
puts "\[INFO] Setting load to: $cap_load"
set_load $cap_load [all_outputs]

puts "\[INFO] Setting clock uncertainty to: $::env(CLOCK_UNCERTAINTY_CONSTRAINT)"
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $clocks

puts "\[INFO] Setting clock transition to: $::env(CLOCK_TRANSITION_CONSTRAINT)"
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) $clocks

puts "\[INFO] Setting timing derate to: $::env(TIME_DERATING_CONSTRAINT)%"
set_timing_derate -early [expr 1-[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]
set_timing_derate -late [expr 1+[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]

#set rst_pins {i_chip_core.tt.i_peripherals.rst_n_rebuf_gf180mcu_as_sc_mcu7t3v3__dfxtp_2_Q/Q i_chip_core.tt.i_peripherals.rst_n_rebuf_negedge_gf180mcu_as_sc_mcu7t3v3__dfxtn_2_Q/Q}

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
#    set_case_analysis 1 ${rst_pins}
} else {
    set_propagated_clock [all_clocks]
}

# Ignore switch of setup/ctrl mux on QSPI output paths
set_false_path -from *.tt.rst_reg_n_gf180mcu_as_sc_mcu7t3v3__dfxtn_2_Q -to $clk_core_inout_ports

#!/bin/bash

verilator --lint-only -DSIM --timing -Wall -Wno-DECLFILENAME -Wno-MULTITOP *.v ../../gf180mcu/gf180mcuD/libs.ref/gf180mcu_ocd_ip_sram/verilog/*.blackbox.v

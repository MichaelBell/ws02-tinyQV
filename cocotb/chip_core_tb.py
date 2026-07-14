# SPDX-FileCopyrightText: © 2025 Project Template Contributors
# SPDX-License-Identifier: Apache-2.0

import os
import random
import logging
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, Edge, RisingEdge, FallingEdge, ClockCycles
from cocotb_tools.runner import get_runner

sim = os.getenv("SIM", "icarus")
pdk_root = os.getenv("PDK_ROOT", Path("~/.ciel").expanduser())
pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_as_sc_mcu7t3v3")
pad = os.getenv("PAD", "gf180mcu_fd_io")
sram = os.getenv("SRAM", "gf180mcu_ocd_ip_sram")
gl = os.getenv("GL", False)
slot = os.getenv("SLOT", "1x1")

hdl_toplevel = "tb"


def chip_core_runner():

    proj_path = Path(__file__).resolve().parent

    sources = []
    defines = {f"SLOT_{slot.upper()}": True}
    includes = [proj_path / "../src/"]

    # Set the LibreLane PDK/SCL/PAD defines
    defines[f"PDK_{pdk.replace('-','_')}"] = True
    defines[f"SCL_{scl}"] = True
    defines[f"PAD_{pad}"] = True
    defines[f"SRAM_{sram}"] = True

    if gl:
        # SCL models
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "primitives.v")

        # We use the powered netlist
        sources.append(proj_path / f"../final/pnl/{hdl_toplevel}.pnl.v")

        defines.update({"FUNCTIONAL": True, "USE_POWER_PINS": True})
    else:
        src_path = proj_path / "../src/"
        sources.append(src_path / "chip_top.sv")
        sources.append(src_path / "chip_core.sv")
        sources.append(src_path / "project.v")
        sources.append(src_path / "text_ram.v")
        sources.append(src_path / "tinyQV/cpu/tinyqv.v")
        sources.append(src_path / "tinyQV/cpu/alu.v")
        sources.append(src_path / "tinyQV/cpu/buffer.v")
        sources.append(src_path / "tinyQV/cpu/core.v")
        sources.append(src_path / "tinyQV/cpu/counter.v")
        sources.append(src_path / "tinyQV/cpu/cpu.v")
        sources.append(src_path / "tinyQV/cpu/decode.v")
        sources.append(src_path / "tinyQV/cpu/mem_ctrl.v")
        sources.append(src_path / "tinyQV/cpu/qspi_ctrl.v")
        sources.append(src_path / "tinyQV/cpu/qspi_setup.v")
        sources.append(src_path / "tinyQV/cpu/register.v")
        sources.append(src_path / "tinyQV/cpu/latch_reg.v")
        sources.append(src_path / "tinyQV/cpu/time.v")
        sources.append(src_path / "tinyQV/cpu/internal_ram.v")
        sources.append(src_path / "tinyQV/peri/uart/uart_tx.v")
        sources.append(src_path / "peripherals.v")
        sources.append(src_path / "peri_byte_empty.v")
        sources.append(src_path / "peri_full_empty.v")
        sources.append(src_path / "user_peripherals/uart/peri_uart.v")
        sources.append(src_path / "user_peripherals/uart/uart_rx.v")
        sources.append(src_path / "user_peripherals/uart/uart_tx.v")
        sources.append(src_path / "user_peripherals/spi.v")
        sources.append(src_path / "user_peripherals/game_pmod.v")
        sources.append(src_path / "user_peripherals/matt_pwm/matt_pwm.v")
        sources.append(src_path / "user_peripherals/matt_pwm/pwm_strobe_gen.v")
        sources.append(src_path / "user_peripherals/matt_pwm/pwm.v")
        sources.append(src_path / "user_peripherals/pulse_transmitter/peripheral.v")
        sources.append(src_path / "user_peripherals/pulse_transmitter/carrier.v")
        sources.append(src_path / "user_peripherals/pulse_transmitter/countdown_timer.v")
        sources.append(src_path / "user_peripherals/pulse_transmitter/delay_1.v")
        sources.append(src_path / "user_peripherals/pulse_transmitter/delay_2.v")
        sources.append(src_path / "user_peripherals/pulse_transmitter/simple_falling_edge_detector.v")
        sources.append(src_path / "user_peripherals/pulse_transmitter/simple_rising_edge_detector.v")
        sources.append(src_path / "user_peripherals/ubcd/ascii.v")
        sources.append(src_path / "user_peripherals/ubcd/cistercian.v")
        sources.append(src_path / "user_peripherals/ubcd/kaktovik.v")
        sources.append(src_path / "user_peripherals/ubcd/peripheral.v")
        sources.append(src_path / "user_peripherals/ubcd/ubcd.v")
        sources.append(src_path / "user_peripherals/pwl_synth/pwl_synth.sv")
        sources.append(src_path / "user_peripherals/pwl_synth/pwl_synth_memory.sv")
        sources.append(src_path / "user_peripherals/AY8913/attenuation.v")
        sources.append(src_path / "user_peripherals/AY8913/envelope.v")
        sources.append(src_path / "user_peripherals/AY8913/noise.v")
        sources.append(src_path / "user_peripherals/AY8913/pwm.v")
        sources.append(src_path / "user_peripherals/AY8913/signal_edge.v")
        sources.append(src_path / "user_peripherals/AY8913/tone.v")
        sources.append(src_path / "user_peripherals/AY8913/ay8913.v")
        sources.append(src_path / "user_peripherals/AY8913/peripheral.v")
        sources.append(src_path / "user_peripherals/vga_gfx/peripheral.v")
        sources.append(src_path / "user_peripherals/vga_gfx/vga_timing.v")
        sources.append(src_path / "user_peripherals/vga_gfx/latch_config.v")

        includes.append(src_path / "user_peripherals/pwl_synth/")
        includes.append(src_path)

        defines.update({"SIM": True})

    sources += [
        # IO pad models
        Path(pdk_root) / pdk / f"libs.ref/{pad}/verilog/{pad}.v",
        
        # SRAM macros
        Path(pdk_root) / pdk / f"libs.ref/{sram}/verilog/{sram}__sram512x8m8wm1.v",
        Path(pdk_root) / pdk / f"libs.ref/{sram}/verilog/{sram}__sram1024x8m8wm1.v",
                
        # Custom IP
        proj_path / "../ip/gf180mcu_ws_ip__id/vh/gf180mcu_ws_ip__id.v",
        proj_path / "../ip/gf180mcu_ws_ip__logo/vh/gf180mcu_ws_ip__logo.v",

        # Testbench
        "tb.v"
    ]

    build_args = []

    if sim == "icarus":
        # For debugging
        # build_args = ["-Winfloop", "-pfileline=1"]
        pass

    if sim == "verilator":
        build_args = ["--timing", "--trace", "--trace-fst", "--trace-structs"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        defines=defines,
        always=True,
        includes=includes,
        build_args=build_args,
        waves=True,
    )

    plusargs = []

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="test,",
        plusargs=plusargs,
        waves=True,
    )


if __name__ == "__main__":
    chip_core_runner()

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
gl = os.getenv("GL", False)
pdk_root = os.getenv("PDK_ROOT", Path(__file__).resolve().parent / "../gf180mcu")
pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_as_sc_mcu7t3v3")
pad = os.getenv("PAD", "gf180mcu_fd_io")
sram = os.getenv("SRAM", "gf180mcu_ocd_ip_sram")
slot = os.getenv("SLOT", "1x1")

hdl_toplevel = "tb_top"

async def set_defaults(dut):
    dut.uart_rx.value = 1
    dut.ui_in.value = 0
    dut.prog_n.value = 1

async def start_clock(clock, freq=25):
    """Start the clock @ freq MHz"""
    c = Clock(clock, 1 / freq * 1000, "ns")
    cocotb.start_soon(c.start())


async def reset(clk, reset, dut, active_low=True):
    """Reset dut"""
    await Timer(200, "ns")

    cocotb.log.info("Reset asserted...")

    reset.value = not active_low
    await Timer(200, "ns")

    dut.qspi_data.value = 1
    await Timer(800, "ns")
    await RisingEdge(clk)

    reset.value = active_low
    await FallingEdge(clk)

    dut.qspi_data.value = "ZZZZ"

    cocotb.log.info("Reset deasserted.")


async def start_up(dut):
    """Startup sequence"""
    await set_defaults(dut)
    await start_clock(dut.clk_PAD)
    await reset(dut.clk_PAD, dut.rst_n_PAD, dut)

def check_qspi_data_out(dut, val):
    assert dut.bidir_PAD.value[9] == (1 if val & 1 else 0)
    assert dut.bidir_PAD.value[10] == (1 if val & 2 else 0)
    assert dut.bidir_PAD.value[12] == (1 if val & 4 else 0)
    assert dut.bidir_PAD.value[13] == (1 if val & 8 else 0)

def check_spi_data_out(dut, val):
    assert dut.bidir_PAD.value[9] == (1 if val & 1 else 0)
    assert dut.bidir_PAD.value[10] == 0 # Pulled down

def set_qspi_data(dut, val):
    dut.qspi_data.value = val

async def setup_flash(dut):
    assert dut.bidir_PAD.value[8] == 0
    assert dut.bidir_PAD.value[14] == 1
    assert dut.bidir_PAD.value[15] == 1
    assert dut.bidir_PAD.value[11] == 0

    # Reset
    cmd = 0xFF
    for i in range(8):
        check_spi_data_out(dut, (1 if cmd & 0x80 else 0))
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 1
        check_spi_data_out(dut, (1 if cmd & 0x80 else 0))
        cmd <<= 1
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == (0 if i < 7 else 1)
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 0

    for _ in range(2):
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 1
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 0

    await ClockCycles(dut.clk_PAD, 1, False)
    assert dut.bidir_PAD.value[8] == 0
    assert dut.bidir_PAD.value[14] == 1
    assert dut.bidir_PAD.value[15] == 1
    assert dut.bidir_PAD.value[11] == 0

    # Command
    cmd = 0xEB
    for i in range(8):
        check_spi_data_out(dut, (1 if cmd & 0x80 else 0))
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 1
        check_spi_data_out(dut, (1 if cmd & 0x80 else 0))
        cmd <<= 1
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 0

    # Address
    addr = 0
    for i in range(6):
        check_qspi_data_out(dut, (addr >> (20 - i * 4)) & 0xF)
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 1
        check_qspi_data_out(dut, (addr >> (20 - i * 4)) & 0xF)
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 0

    # Continuous read
    for i in range(2):
        check_qspi_data_out(dut, 0xA)
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 1
        check_qspi_data_out(dut, 0xA)
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 0

    for i in range(8):
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 1
        if i == 7:
            break
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 0
        assert dut.bidir_PAD.value[14] == 1
        assert dut.bidir_PAD.value[15] == 1
        assert dut.bidir_PAD.value[11] == 0

async def setup_ram(dut, ram_a):
    assert dut.bidir_PAD.value[8] == 1
    assert dut.bidir_PAD.value[14] == (0 if ram_a else 1)
    assert dut.bidir_PAD.value[15] == (1 if ram_a else 0)
    assert dut.bidir_PAD.value[11] == 0

    # Command
    cmd = 0x35
    for i in range(8):
        check_spi_data_out(dut, (1 if cmd & 0x80 else 0))
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 1
        assert dut.bidir_PAD.value[14] == (0 if ram_a else 1)
        assert dut.bidir_PAD.value[15] == (1 if ram_a else 0)
        assert dut.bidir_PAD.value[11] == 1
        check_spi_data_out(dut, (1 if cmd & 0x80 else 0))
        cmd <<= 1
        if i == 7:
            break
        await ClockCycles(dut.clk_PAD, 1, False)
        assert dut.bidir_PAD.value[8] == 1
        assert dut.bidir_PAD.value[14] == (0 if ram_a else 1)
        assert dut.bidir_PAD.value[15] == (1 if ram_a else 0)
        assert dut.bidir_PAD.value[11] == 0

select = None

def check_selected(dut):
    assert dut.bidir_PAD.value[8] == (0 if "FLASH" == select else 1)
    assert dut.bidir_PAD.value[14] == (0 if "RAM A" == select else 1)
    assert dut.bidir_PAD.value[15] == (0 if "RAM B" == select else 1)

def is_selected(dut):
    if "FLASH" == select: return dut.bidir_PAD.value[8] == 0
    if "RAM A" == select: return dut.bidir_PAD.value[14] == 0
    if "RAM B" == select: return dut.bidir_PAD.value[15] == 0
    return False

async def start_read(dut, addr, allow_interrupt=False):
    global select

    if addr is None:
        select = "FLASH"
    elif addr >= 0x1800000:
        select = "RAM B"
    elif addr >= 0x1000000:
        select = "RAM A"
    else:
        select = "FLASH"

    check_selected(dut)
    assert dut.bidir_PAD.value[11] == 0

    if select != "FLASH":
        # Command
        cmd = 0x0B
        for i in range(2):
            await ClockCycles(dut.clk_PAD, 1)
            check_selected(dut)
            assert dut.bidir_PAD.value[11] == 1
            check_qspi_data_out(dut, (cmd & 0xF0) >> 4)
            cmd <<= 4
            await ClockCycles(dut.clk_PAD, 1)
            check_selected(dut)
            assert dut.bidir_PAD.value[11] == 0

    # Address
    for i in range(6):
        await ClockCycles(dut.clk_PAD, 1)
        if allow_interrupt and not is_selected(dut): return False
        check_selected(dut)
        assert dut.bidir_PAD.value[11] == 1
        if addr is not None:
            check_qspi_data_out(dut, (addr >> (20 - i * 4)) & 0xF)
        await ClockCycles(dut.clk_PAD, 1)
        if allow_interrupt and not is_selected(dut): return False
        check_selected(dut)
        assert dut.bidir_PAD.value[11] == 0

    # Dummy
    if select == "FLASH":
        for i in range(2):
            await ClockCycles(dut.clk_PAD, 1)
            if allow_interrupt and not is_selected(dut): return False
            check_selected(dut)
            assert dut.bidir_PAD.value[11] == 1
            check_qspi_data_out(dut, 0xA)
            await ClockCycles(dut.clk_PAD, 1)
            if allow_interrupt and not is_selected(dut): return False
            check_selected(dut)
            assert dut.bidir_PAD.value[11] == 0

    for i in range(4):
        await ClockCycles(dut.clk_PAD, 1)
        if allow_interrupt and not is_selected(dut): return False
        check_selected(dut)
        assert dut.bidir_PAD.value[11] == 1
        await ClockCycles(dut.clk_PAD, 1)
        if allow_interrupt and not is_selected(dut): return False
        check_selected(dut)
        assert dut.bidir_PAD.value[11] == 0

    return True

nibble_shift_order = [4, 0, 12, 8, 20, 16, 28, 24]

async def send_instr(dut, data, ok_to_exit=False, allow_long_delay=False):
    instr_len = 8 if (data & 3) == 3 else 4
    for i in range(instr_len):
        set_qspi_data(dut, (data >> (nibble_shift_order[i])) & 0xF)
        await ClockCycles(dut.clk_PAD, 1)
        for _ in range(400 if allow_long_delay else 20):
            if ok_to_exit and not is_selected(dut):
                return
            check_selected(dut)
            if dut.bidir_PAD.value[11] == 0:
                await ClockCycles(dut.clk_PAD, 1)
            else:
                break
        assert dut.bidir_PAD.value[11] == 1
        await ClockCycles(dut.clk_PAD, 1)
        assert dut.bidir_PAD.value[11] == 0
        if i != instr_len - 1:
            if ok_to_exit and not is_selected(dut):
                return
            check_selected(dut)

@cocotb.test()
async def test_start(dut):
    """Run a simple GPIO test"""

    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut)

    logger.info("Running the test...")

    #assert dut.bidir_PAD.value[15:8] == "11ZZ0ZZ1"
    assert dut.bidir_PAD.value[23:16] == "00000011"
    assert dut.bidir_PAD.value[26:24] == "110"

    await ClockCycles(dut.clk_PAD, 2)

    # Expect flash and RAM init
    await setup_flash(dut)
    await ClockCycles(dut.clk_PAD, 2)
    await setup_ram(dut, True)
    await ClockCycles(dut.clk_PAD, 2)
    await setup_ram(dut, False)
    await ClockCycles(dut.clk_PAD, 3)

    # Read starts at address 0
    await start_read(dut, 0)

    # Set up GPIO
    await send_instr(dut, 0x0ff00093)
    await send_instr(dut, 0x00122623)
    await send_instr(dut, 0x00100093)
    for j in range(8):
        await send_instr(dut, 0x06122023 + 0x200 * j)

    # Test GPIO
    for i in range(40):
        gpio_out = random.randint(0, 255)
        await send_instr(dut, 0x00000093 + gpio_out * 0x100000)
        await send_instr(dut, 0x04122023)
        for j in range(4):
            await send_instr(dut, 0x00000013) # NOP
        for j in range(8):
            assert dut.bidir_PAD.value[j+16] == (1 if (gpio_out >> j) & 1 else 0)

    logger.info("Done!")

def chip_top_runner():

    proj_path = Path(__file__).resolve().parent

    sources = []
    defines = {f"SLOT_{slot.upper()}": True}
    includes = [proj_path / "../src/"]
    src_path = proj_path / "../src/"

    # Set the LibreLane PDK/SCL/PAD defines
    defines[f"PDK_{pdk.replace('-','_')}"] = True
    defines[f"SCL_{scl}"] = True
    defines[f"PAD_{pad}"] = True
    defines[f"SRAM_{sram}"] = True

    if gl:
        # SCL models
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        if scl != "gf180mcu_as_sc_mcu7t3v3":
            sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "primitives.v")
        else:
            sources.append(proj_path / "gf180mcu_as_sc_mcu7t3v3_missing_cells.v")

        # We use the powered netlist
        sources.append(proj_path / f"../final/pnl/chip_top.pnl.v")

        defines.update({"FUNCTIONAL": True, "USE_POWER_PINS": True})
    else:
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

        defines.update({"SIM": True})

    includes.append(src_path)
    sources += [
        # IO pad models
        Path(pdk_root) / pdk / f"libs.ref/{pad}/verilog/{pad}.v",
        
        # SRAM macros
        Path(pdk_root) / pdk / f"libs.ref/{sram}/verilog/{sram}__sram512x8m8wm1.v",
        Path(pdk_root) / pdk / f"libs.ref/{sram}/verilog/{sram}__sram1024x8m8wm1.v",
        
        # Custom IP
        proj_path / "../ip/gf180mcu_ws_ip__logo/vh/gf180mcu_ws_ip__logo.v",
        proj_path / "../ip/gf180mcu_ws_ip__qrcode_id/vh/gf180mcu_ws_ip__qrcode_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__shuttle_id/vh/gf180mcu_ws_ip__shuttle_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__project_id/vh/gf180mcu_ws_ip__project_id.v",
        

        # Testbench
        "tb_top.v"
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
        test_module="chip_top_tb,",
        plusargs=plusargs,
        waves=True,
    )


if __name__ == "__main__":
    chip_top_runner()

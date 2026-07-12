# SPDX-FileCopyrightText: © 2025 Project Template Contributors
# SPDX-License-Identifier: Apache-2.0

import os
import random
import logging
from pathlib import Path

from PIL import Image

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, Edge, RisingEdge, FallingEdge, ClockCycles
from cocotb_tools.runner import get_runner

from riscvmodel.insn import *

from riscvmodel.regnames import x0, x1, sp, gp, tp, a0, a1, a2, a3, a4
from riscvmodel import csrnames
from riscvmodel.variant import RV32E

sim = os.getenv("SIM", "icarus")
gl = os.getenv("GL", False)
pdk_root = os.getenv("PDK_ROOT", Path(__file__).resolve().parent / "../gf180mcu")
pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_as_sc_mcu7t3v3")
pad = os.getenv("PAD", "gf180mcu_fd_io")
sram = os.getenv("SRAM", "gf180mcu_ocd_ip_sram")
slot = os.getenv("SLOT", "1x1")

hdl_toplevel = "tb_top"

if not os.path.exists("output"):
    os.mkdir("output")

async def set_defaults(dut):
    dut.uart_rx.value = 1
    dut.ui_in.value = 0x80
    dut.prog_n.value = 1
    dut.use_hdmi_n.value = 1


async def start_clock(clock):
    """Start the clock"""
    c = Clock(clock, 39.682, "ns")
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

def check_qspi_data_out(dut, val):
    assert dut.bidir_PAD.value[9] == (1 if val & 1 else 0)
    assert dut.bidir_PAD.value[10] == (1 if val & 2 else 0)
    assert dut.bidir_PAD.value[12] == (1 if val & 4 else 0)
    assert dut.bidir_PAD.value[13] == (1 if val & 8 else 0)

def get_qspi_data_out(dut):
    val = 0
    if dut.bidir_PAD.value[9] == 1: val |= 1
    if dut.bidir_PAD.value[10] == 1: val |= 2
    if dut.bidir_PAD.value[12] == 1: val |= 4
    if dut.bidir_PAD.value[13] == 1: val |= 8
    return val

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

async def start_write(dut, addr):
    global select

    if addr >= 0x1800000:
        select = "RAM B"
    else:
        select = "RAM A"

    check_selected(dut)
    assert dut.bidir_PAD.value[11] == 0
    dut.qspi_data.value = "ZZZZ"

    # Command
    cmd = 0x02
    for i in range(2):
        await ClockCycles(dut.clk_PAD, 1, False)
        check_selected(dut)
        assert dut.bidir_PAD.value[11] == 1
        check_qspi_data_out(dut, (cmd & 0xF0) >> 4)
        cmd <<= 4
        await ClockCycles(dut.clk_PAD, 1, False)
        check_selected(dut)
        assert dut.bidir_PAD.value[11] == 0

    # Address
    for i in range(6):
        await ClockCycles(dut.clk_PAD, 1, False)
        check_selected(dut)
        assert dut.bidir_PAD.value[11] == 1
        check_qspi_data_out(dut, (addr >> (20 - i * 4)) & 0xF)
        await ClockCycles(dut.clk_PAD, 1, False)
        check_selected(dut)
        assert dut.bidir_PAD.value[11] == 0

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

async def expect_store(dut, addr, bytes=4, allow_long_delay=False, allow_interrupt=False):
    global select

    val = 0
    for i in range(12):
        if addr >= 0x1800000:
            select = "RAM B"
        else:
            select = "RAM A"

        if is_selected(dut):
            await start_write(dut, addr)
            for j in range(bytes*2):
                await ClockCycles(dut.clk_PAD, 1, False)
                check_selected(dut)
                if j > 0 and (j % 8) == 0:
                    await ClockCycles(dut.clk_PAD, 1, False)
                    check_selected(dut)
                    assert dut.bidir_PAD.value[11] == 0
                    await ClockCycles(dut.clk_PAD, 1, False)
                assert dut.bidir_PAD.value[11] == 1
                val |= get_qspi_data_out(dut) << (nibble_shift_order[j % 8])
                await ClockCycles(dut.clk_PAD, 1, False)
                if j != bytes*2-1:
                    check_selected(dut)
                else:
                    assert not is_selected(dut)
                assert dut.bidir_PAD.value[11] == 0
            await ClockCycles(dut.clk_PAD, 1, False)
            assert not is_selected(dut)
            break
        elif dut.bidir_PAD.value[8] == 0:
            select = "FLASH"
            await send_instr(dut, 0x0001, True, allow_long_delay)
        else:
            await ClockCycles(dut.clk_PAD, 1, False)
    else:
        assert False

    for i in range(8):
        await ClockCycles(dut.clk_PAD, 1)
        if dut.bidir_PAD.value[8] == 0:
            if hasattr(dut.uut, "tt"):
                interrupted = not await start_read(dut, dut.uut.tt.i_tinyqv.instr_addr.value.to_unsigned() * 2, allow_interrupt)
            else:
                interrupted = not await start_read(dut, None, allow_interrupt)
            if interrupted:
                allow_interrupt = False
            else:
                break
    else:
        assert False

    return val

async def read_reg(dut, reg, allow_long_delay=False):
    offset = random.randint(-0x400, 0x3FF)
    instr = InstructionSW(gp, reg, offset).encode()
    await send_instr(dut, instr)

    return await expect_store(dut, 0x1000400 + offset, 4, allow_long_delay)

send_nops = True
nop_task = None

async def nops_loop(dut):
    while send_nops:
        await send_instr(dut, InstructionADDI(x0, x0, 0).encode())

async def start_nops(dut):
    global send_nops, nop_task
    send_nops = True
    nop_task = cocotb.start_soon(nops_loop(dut))

    # This ensures that the nop task is actually started, so that it can be instantly stopped.
    await Timer(2, "ps")

async def stop_nops():
    global send_nops, nop_task
    send_nops = False
    if nop_task is not None:
        await nop_task
    nop_task = None

async def read_byte(dut, reg, expected_val):
  await send_instr(dut, InstructionSW(tp, reg, 0x18).encode())

  await start_nops(dut)
  for i in range(240):
      if dut.bidir_PAD.value[27] == 0:
          break
      else:
          await Timer(5, "ns")
  assert dut.bidir_PAD.value[27] == 0
  bit_time = 1000
  await Timer(bit_time / 2, "ns")
  assert dut.bidir_PAD.value[27] == 0
  for i in range(8):
      await Timer(bit_time, "ns")
      assert dut.bidir_PAD.value[27] == (expected_val & 1)
      expected_val >>= 1
  await Timer(bit_time, "ns")
  assert dut.bidir_PAD.value[27] == 1

  await stop_nops()

VSYNC_PAD = 35
HSYNC_PAD = 36
R0_PAD = 30
G0_PAD = 32
B0_PAD = 34
R1_PAD = 29
G1_PAD = 31
B1_PAD = 33

async def capture_vga_frames(dut, n=1, capture_start=0, frame_num_start=0):
    image = Image.new("RGB", (640, 480))

    await ClockCycles(dut.clk_PAD, 19)

    # Test sync
    for i in range(525*n+5):
        vsync = 0 if (480+10) <= i % 525 < (480+12) else 1
        for j in range(640+16):
            assert dut.bidir_PAD.value[VSYNC_PAD] == vsync
            assert dut.bidir_PAD.value[HSYNC_PAD] == 1
            if i % 525 < 480 and j < 640 and i >= capture_start:
                red = ((int(dut.bidir_PAD.value[R1_PAD]) << 1) | int(dut.bidir_PAD.value[R0_PAD])) * 85
                green = ((int(dut.bidir_PAD.value[G1_PAD]) << 1) | int(dut.bidir_PAD.value[G0_PAD])) * 85
                blue = ((int(dut.bidir_PAD.value[B1_PAD]) << 1) | int(dut.bidir_PAD.value[B0_PAD])) * 85
                image.putpixel((j, i % 525), (red, green, blue))
            await ClockCycles(dut.clk_PAD, 1)
        for j in range(96):
            assert dut.bidir_PAD.value[VSYNC_PAD] == vsync
            assert dut.bidir_PAD.value[HSYNC_PAD] == 0
            await ClockCycles(dut.clk_PAD, 1)
        for j in range(48):
            assert dut.bidir_PAD.value[VSYNC_PAD] == vsync
            assert dut.bidir_PAD.value[HSYNC_PAD] == 1
            await ClockCycles(dut.clk_PAD, 1)

        if i % 525 == 480:
            image.save(f"output/frame_top{frame_num_start + (i // 525)}.png")



@cocotb.test()
async def test_start(dut):
    """Run a simple GPIO test"""

    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut)

    logger.info("Running the GPIO test...")

    # Read ID
    await send_instr(dut, InstructionLW(x1, tp, 0x8).encode())
    assert await read_reg(dut, x1) == ord('2') | (ord('0') << 8) | (ord('S') << 16) | (ord('W') << 24)

    # Set up GPIO
    await send_instr(dut, InstructionADDI(x1, x0, 0xff).encode())
    await send_instr(dut, InstructionSW(tp, x1, 0x0c).encode())
    await send_instr(dut, InstructionADDI(x1, x0, 1).encode())
    for j in range(17):
        await send_instr(dut, InstructionSW(tp, x1, 0x60 + j).encode())

    # All IOs to outputs
    dut.ui_in.value = "ZZZZZZZZ"
    await send_instr(dut, InstructionADDI(x1, x0, -1).encode())
    await send_instr(dut, InstructionSW(tp, x1, 0x48).encode())

    for i in range(40):
        gpio_sel = random.randint(0, (1 << 17) - 1)
        gpio_out = random.randint(0, (1 << 17) - 1)
        await send_instr(dut, InstructionLUI(x1, (gpio_out >> 12) + ((gpio_out >> 11) & 1)).encode())
        await send_instr(dut, InstructionADDI(x1, x1, (gpio_out & 0xfff) - (0x1000 if gpio_out & 0x800 else 0)).encode())
        await send_instr(dut, InstructionSW(tp, x1, 0x40).encode())
        for _ in range(3):
            await send_instr(dut, InstructionADDI(x0, x0, 0).encode())
        for j in range(8):
            assert dut.bidir_PAD.value[j+16] == (1 if (gpio_out >> j) & 1 else 0)
        for j in range(8,16):
            assert dut.bidir_PAD.value[j-8] == (1 if (gpio_out >> j) & 1 else 0)
        assert dut.bidir_PAD.value[24] == (1 if (gpio_out >> 16) & 1 else 0)

    logger.info("Done!")

@cocotb.test()
async def test_uart(dut):
    """Run a simple UART test"""

    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut)

    logger.info("Running the UART test...")

    # Set UART RX pin
    await send_instr(dut, InstructionADDI(x1, x0, 2).encode())
    await send_instr(dut, InstructionSW(tp, x1, 0x8c).encode())

    # Test UART TX
    uart_byte = 0x54
    await send_instr(dut, InstructionADDI(x1, x0, uart_byte).encode())
    await send_instr(dut, InstructionSW(tp, x1, 0x80).encode())

    await start_nops(dut)
    bit_time = 8680
    await Timer(bit_time / 2, "ns")
    assert dut.bidir_PAD.value[25] == 0
    for i in range(8):
        await Timer(bit_time, "ns")
        assert dut.bidir_PAD.value[25] == (uart_byte & 1)
        uart_byte >>= 1
    await Timer(bit_time, "ns")
    assert dut.bidir_PAD.value[25] == 1

    # Test UART RX
    for j in range(5):
        assert dut.bidir_PAD.value[26] == 0

        uart_rx_byte = random.randint(0, 255)
        val = uart_rx_byte
        dut.uart_rx.value = 0
        await Timer(bit_time, "ns")
        for i in range(8):
            dut.uart_rx.value = val & 1
            await Timer(bit_time, "ns")
            assert dut.bidir_PAD.value[26] == 0
            val >>= 1
        dut.uart_rx.value = 1
        await Timer(bit_time, "ns")
        assert dut.bidir_PAD.value[26] == 0

        uart_rx_byte2 = random.randint(0, 255)
        val = uart_rx_byte2
        dut.uart_rx.value = 0
        await Timer(bit_time, "ns")
        for i in range(8):
            dut.uart_rx.value = val & 1
            await Timer(bit_time, "ns")
            assert dut.bidir_PAD.value[26] == 1
            val >>= 1
        dut.uart_rx.value = 1
        await Timer(bit_time, "ns")
        assert dut.bidir_PAD.value[26] == 1

        await stop_nops()

        await send_instr(dut, InstructionLW(x1, tp, 0x84).encode())
        await read_byte(dut, x1, 0x2)
        await send_instr(dut, InstructionLW(x1, tp, 0x80).encode())
        await read_byte(dut, x1, uart_rx_byte)
        assert dut.bidir_PAD.value[26] == 0
        await send_instr(dut, InstructionLW(x1, tp, 0x84).encode())
        await read_byte(dut, x1, 0x2)
        await send_instr(dut, InstructionLW(x1, tp, 0x80).encode())
        await read_byte(dut, x1, uart_rx_byte2)
        assert dut.bidir_PAD.value[26] == 0
        await send_instr(dut, InstructionLW(x1, tp, 0x84).encode())
        await read_byte(dut, x1, 0)

        if j != 4:
            await start_nops(dut)

    # Test Debug UART TX
    uart_byte = 0x5A
    await send_instr(dut, InstructionADDI(x1, x0, uart_byte).encode())
    await read_byte(dut, x1, uart_byte)

    logger.info("Done!")

@cocotb.test()
async def test_prog(dut):
    """Check prog works"""

    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")
    logger.info("Startup sequence...")

    await set_defaults(dut)
    await start_clock(dut.clk_PAD)
    assert dut.prog_miso.value == 'Z'
    dut.rst_n_PAD.value = 0
    dut.qspi_data.value = "ZZZZ"
    await Timer(200, "ns")
    assert dut.prog_miso.value == 'Z'

    dut.prog_n.value = 0

    for i in range(16):
        dut.prog_cs.value = (1 if (i & 1) else 0)
        dut.prog_clk_PAD.value = (1 if (i & 2) else 0)
        dut.prog_mosi.value = (1 if (i & 4) else 0)
        dut.qspi_data.value = f"ZZ{1 if (i & 8) else 0}Z"

        await Timer(10, "ns")

        assert dut.bidir_PAD.value[8] == (1 if (i & 1) else 0)
        assert dut.bidir_PAD.value[11] == (1 if (i & 2) else 0)
        assert dut.bidir_PAD.value[9] == (1 if (i & 4) else 0)
        assert dut.prog_miso.value == (1 if (i & 8) else 0)

    dut.prog_n.value = 1
    await Timer(10, "ns")
    assert dut.prog_miso.value == 'Z'

@cocotb.test()
async def test_scratch_memory(dut):
    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut)

    logger.info("Running the Scratch memory test...")

    RAM_SIZE = 512
    RAM = [0]*RAM_SIZE
    for i in range(0, RAM_SIZE, 4):
        await send_instr(dut, InstructionADDI(x1, x0, i).encode())
        await send_instr(dut, InstructionSW(x0, x1, i-0x400).encode())
        RAM[i] = i & 0xff
        RAM[i+1] = i >> 8

    for i in range(0, RAM_SIZE, 4):
        await send_instr(dut, InstructionLW(x1, x0, i-0x400).encode())
        assert await read_reg(dut, x1) == i

    mask = [0xfff, 0xffe, 0xffc]
    for i in range(20):
        write_len = random.randint(0,2)
        write_addr = random.randint(0,RAM_SIZE - (1 << write_len)) & mask[write_len]
        write_val = random.randint(0,0xffffffff)
        await send_instr(dut, InstructionLUI(x1, (write_val >> 12) + ((write_val >> 11) & 1)).encode())
        await send_instr(dut, InstructionADDI(x1, x1, (write_val & 0xfff) - (0x1000 if write_val & 0x800 else 0)).encode())

        if write_len == 0: await send_instr(dut, InstructionSB(x0, x1, write_addr-0x400).encode())
        elif write_len == 1: await send_instr(dut, InstructionSH(x0, x1, write_addr-0x400).encode())
        else: await send_instr(dut, InstructionSW(x0, x1, write_addr-0x400).encode())

        read_len = write_len
        read_addr = write_addr
        read_val = write_val
        if write_len == 0: read_val &= 0xff
        if write_len == 1: read_val &= 0xffff

        RAM[write_addr] = write_val & 0xff
        if write_len > 0: RAM[write_addr + 1] = (write_val >> 8) & 0xff
        if write_len > 1:
            RAM[write_addr + 2] = (write_val >> 16) & 0xff
            RAM[write_addr + 3] = (write_val >> 24) & 0xff

        if read_len == 0: await send_instr(dut, InstructionLBU(x1, x0, read_addr-0x400).encode())
        elif read_len == 1: await send_instr(dut, InstructionLHU(x1, x0, read_addr-0x400).encode())
        else: await send_instr(dut, InstructionLW(x1, x0, read_addr-0x400).encode())
        assert await read_reg(dut, x1) == read_val

    for i in range(1000):
        if random.randint(0, 1) == 0:
            read_len = random.randint(0,2)
            read_addr = random.randint(0,RAM_SIZE - (1 << read_len)) & mask[read_len]
            if read_len == 0: await send_instr(dut, InstructionLB(x1, x0, read_addr-0x400).encode())
            elif read_len == 1: await send_instr(dut, InstructionLH(x1, x0, read_addr-0x400).encode())
            else: await send_instr(dut, InstructionLW(x1, x0, read_addr-0x400).encode())
            read_val = await read_reg(dut, x1)
            assert (read_val & 0xFF) == RAM[read_addr]
            if read_len > 0: assert ((read_val >> 8) & 0xFF) == RAM[read_addr+1]
            if read_len > 1: 
                assert ((read_val >> 16) & 0xFF) == RAM[read_addr+2]
                assert ((read_val >> 24) & 0xFF) == RAM[read_addr+3]
        else:
            write_len = random.randint(0,2)
            write_addr = random.randint(0,RAM_SIZE - (1 << write_len)) & mask[write_len]
            write_val = random.randint(0,0xffffffff)
            await send_instr(dut, InstructionLUI(x1, (write_val >> 12) + ((write_val >> 11) & 1)).encode())
            await send_instr(dut, InstructionADDI(x1, x1, (write_val & 0xfff) - (0x1000 if write_val & 0x800 else 0)).encode())

            if write_len == 0: await send_instr(dut, InstructionSB(x0, x1, write_addr-0x400).encode())
            elif write_len == 1: await send_instr(dut, InstructionSH(x0, x1, write_addr-0x400).encode())
            else: await send_instr(dut, InstructionSW(x0, x1, write_addr-0x400).encode())
            
            RAM[write_addr] = write_val & 0xff
            if write_len > 0: RAM[write_addr + 1] = (write_val >> 8) & 0xff
            if write_len > 1:
                RAM[write_addr + 2] = (write_val >> 16) & 0xff
                RAM[write_addr + 3] = (write_val >> 24) & 0xff

@cocotb.test()
async def test_video_memory(dut):
    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut)

    logger.info("Running the video memory test...")

    await send_instr(dut, InstructionLUI(a4, 0x8800).encode())
    await send_instr(dut, InstructionADDI(a4, a4, 0x400).encode())

    # Enable the video RAM
    # Need to bounce the enable to get the verilog model of the memory to work
    # I don't expect the actual chip to need this.
    await send_instr(dut, InstructionADDI(x1, x0, 1).encode())
    await send_instr(dut, InstructionSB(a4, x1, 0x600).encode())
    await send_instr(dut, InstructionSB(a4, x0, 0x600).encode())
    await send_instr(dut, InstructionSB(a4, x1, 0x600).encode())

    RAM_SIZE = 2560
    RAM = [0]*RAM_SIZE
    for i in range(0, RAM_SIZE, 1):
        await send_instr(dut, InstructionADDI(x1, x0, i-0x400).encode())
        await send_instr(dut, InstructionSB(a4, x1, i-0x400).encode())
        RAM[i] = i & 0xff

    for i in range(0, RAM_SIZE, 1):
        await send_instr(dut, InstructionLBU(x1, a4, i-0x400).encode())
        assert await read_reg(dut, x1) == i & 0xff

    for i in range(20):
        write_addr = random.randint(0,RAM_SIZE - 1)
        write_val = random.randint(0,0xff)
        await send_instr(dut, InstructionADDI(x1, x0, write_val).encode())

        await send_instr(dut, InstructionSB(a4, x1, write_addr-0x400).encode())

        read_addr = write_addr
        read_val = write_val

        RAM[write_addr] = write_val

        await send_instr(dut, InstructionLBU(x1, a4, read_addr-0x400).encode())
        assert await read_reg(dut, x1) == read_val

    for i in range(1000):
        if random.randint(0, 1) == 0:
            read_addr = random.randint(0,RAM_SIZE - 1)
            await send_instr(dut, InstructionLBU(x1, a4, read_addr-0x400).encode())
            read_val = await read_reg(dut, x1)
            assert read_val == RAM[read_addr]
        else:
            write_addr = random.randint(0,RAM_SIZE - 1)
            write_val = random.randint(0,0xff)
            await send_instr(dut, InstructionADDI(x1, x0, write_val).encode())
            await send_instr(dut, InstructionSB(a4, x1, write_addr-0x400).encode())
            RAM[write_addr] = write_val

@cocotb.test()
async def test_font_memory(dut):
    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut)

    logger.info("Running the font memory test...")

    await send_instr(dut, InstructionLUI(a4, 0x8801).encode())

    # Enable the video RAM
    await send_instr(dut, InstructionADDI(x1, x0, 1).encode())
    await send_instr(dut, InstructionSB(a4, x1, -0x600).encode())
    await send_instr(dut, InstructionSB(a4, x0, -0x600).encode())
    await send_instr(dut, InstructionSB(a4, x1, -0x600).encode())

    RAM_SIZE = 1024
    RAM = [0]*RAM_SIZE
    for i in range(0, RAM_SIZE, 1):
        await send_instr(dut, InstructionADDI(x1, x0, i-0x400).encode())
        await send_instr(dut, InstructionSB(a4, x1, i-0x400).encode())
        RAM[i] = i & 0xff

    for i in range(0, RAM_SIZE, 1):
        await send_instr(dut, InstructionLBU(x1, a4, i-0x400).encode())
        assert await read_reg(dut, x1) == i & 0xff

    for i in range(20):
        write_addr = random.randint(0,RAM_SIZE - 1)
        write_val = random.randint(0,0xff)
        await send_instr(dut, InstructionADDI(x1, x0, write_val).encode())

        await send_instr(dut, InstructionSB(a4, x1, write_addr-0x400).encode())

        read_addr = write_addr
        read_val = write_val

        RAM[write_addr] = write_val

        await send_instr(dut, InstructionLBU(x1, a4, read_addr-0x400).encode())
        assert await read_reg(dut, x1) == read_val

    for i in range(1000):
        if random.randint(0, 1) == 0:
            read_addr = random.randint(0,RAM_SIZE - 1)
            await send_instr(dut, InstructionLBU(x1, a4, read_addr-0x400).encode())
            read_val = await read_reg(dut, x1)
            assert read_val == RAM[read_addr]
        else:
            write_addr = random.randint(0,RAM_SIZE - 1)
            write_val = random.randint(0,0xff)
            await send_instr(dut, InstructionADDI(x1, x0, write_val).encode())
            await send_instr(dut, InstructionSB(a4, x1, write_addr-0x400).encode())
            RAM[write_addr] = write_val

@cocotb.test()
async def test_vga_text(dut):
    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut)

    logger.info("Running the VGA text test...")

    await send_instr(dut, InstructionLUI(a4, 0x8801).encode())

    # Enable the video RAM
    await send_instr(dut, InstructionADDI(x1, x0, 1).encode())
    await send_instr(dut, InstructionSB(a4, x1, -0x600).encode())
    await send_instr(dut, InstructionSB(a4, x0, -0x600).encode())
    await send_instr(dut, InstructionSB(a4, x1, -0x600).encode())

    capture_task = cocotb.start_soon(capture_vga_frames(dut, 2, 100))

    # Setup custom font
    for i in range(16):
        for j in range(16):
            addr = i*32+j*2-0x400
            await send_instr(dut, InstructionADDI(x1, x0, 0xe4 if i == j else 0).encode())
            await send_instr(dut, InstructionSB(a4, x1, addr).encode())
            await send_instr(dut, InstructionADDI(x1, x0, 0x1b if i == j else 0).encode())
            await send_instr(dut, InstructionSB(a4, x1, addr+1).encode())
    for i in range(8):
        for j in range(16):
            addr = (i+16)*32+j*2-0x400
            await send_instr(dut, InstructionADDI(x1, x0, (3 << (2*i)) & 0xff).encode())
            await send_instr(dut, InstructionSB(a4, x1, addr).encode())
            await send_instr(dut, InstructionADDI(x1, x0, 3 << (2*i-8) if i >= 4 else 0).encode())
            await send_instr(dut, InstructionSB(a4, x1, addr+1).encode())
    for i in range(8):
        for j in range(16):
            addr = (i+24)*32+j*2-0x400
            await send_instr(dut, InstructionADDI(x1, x0, ~(i*16 + j) & 0xff).encode())
            await send_instr(dut, InstructionSB(a4, x1, addr).encode())
            await send_instr(dut, InstructionADDI(x1, x0, i*16 + j).encode())
            await send_instr(dut, InstructionSB(a4, x1, addr+1).encode())

    await send_instr(dut, InstructionLUI(a4, 0x8800).encode())
    await send_instr(dut, InstructionADDI(a4, a4, 0x400).encode())

    # Setup video data
    for i in range(30*80):
        await send_instr(dut, InstructionADDI(x1, x0, i & 0xff).encode())
        await send_instr(dut, InstructionSB(a4, x1, i-0x400).encode())

    await start_nops(dut)

    await capture_task
    await stop_nops()


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

    # SCL models - needed for ddr implementation even non-GL
    sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
    if gl:
        # SCL models
        if scl != "gf180mcu_as_sc_mcu7t3v3":
            sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "primitives.v")

        # We use the powered netlist
        sources.append(proj_path / f"../final/pnl/chip_top.pnl.v")

        defines.update({"FUNCTIONAL": True, "USE_POWER_PINS": True})
    else:
        sources.append(src_path / "chip_top.sv")
        sources.append(src_path / "chip_core.sv")
        sources.append(src_path / "project.v")
        sources.append(src_path / "video/text_ram.v")
        sources.append(src_path / "video/text_mode_video.v")
        sources.append(src_path / "video/hsync_generator.v")
        sources.append(src_path / "video/font.v")
        sources.append(src_path / "video/simple_tmds_encode.v")
        sources.append(src_path / "video/smoldvi.v")
        sources.append(src_path / "video/smoldvi_clock_driver.v")
        sources.append(src_path / "video/smoldvi_fast_gearbox.v")
        sources.append(src_path / "video/smoldvi_serialiser.v")
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
        includes.append(src_path / "video/")

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
        proj_path / "../ip/gf180mcu_ws_ip__marker/vh/gf180mcu_ws_ip__marker.v",
        proj_path / "../ip/gf180mcu_ws_ip__qrcode_id/vh/gf180mcu_ws_ip__qrcode_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__shuttle_id/vh/gf180mcu_ws_ip__shuttle_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__project_id/vh/gf180mcu_ws_ip__project_id.v",
        
        proj_path / "../ip/ddr_driver/verilog/ddr_driver.v",
        proj_path / "../ip/r2r/vh/r2r.vh",
        proj_path / "../ip/analog_connect/analog_connect.vh",

        # Testbench
        "tb_top.v"
    ]

    build_args = []

    if sim == "icarus":
        # For debugging
        # build_args = ["-Winfloop", "-pfileline=1"]
        build_args += ["-gno-strict-declaration"]

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

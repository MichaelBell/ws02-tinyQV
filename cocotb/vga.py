# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import os
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, FallingEdge, RisingEdge
from cocotb.utils import get_sim_time

from PIL import Image

from riscvmodel.insn import *

from riscvmodel.regnames import x0, x1, sp, gp, tp, a0, a1, a2, a3, a4
from riscvmodel import csrnames
from riscvmodel.variant import RV32E

from test_util import reset, start_read, send_instr, start_nops, stop_nops, read_byte, read_reg, load_reg, expect_load, expect_store

if not os.path.exists("output"):
    os.mkdir("output")

async def capture_frames(dut, n=1, capture_start=0, frame_num_start=0):
    image = Image.new("RGB", (640, 480))

    await ClockCycles(dut.clk, 20)

    # Test sync
    for i in range(525*n+5):
        vsync = 0 if (480+10) <= i % 525 < (480+12) else 1
        for j in range(640+16):
            assert dut.vsync.value == vsync
            assert dut.hsync.value == 1
            if i % 525 < 480 and j < 640 and i > capture_start:
                red = dut.red.value.to_unsigned() * 85
                green = dut.green.value.to_unsigned() * 85
                blue = dut.blue.value.to_unsigned() * 85
                image.putpixel((j, i % 525), (red, green, blue))            
            await ClockCycles(dut.clk, 1)
            #print(j, end="")
        for j in range(96):
            assert dut.vsync.value == vsync
            assert dut.hsync.value == 0
            await ClockCycles(dut.clk, 1)
        for j in range(48):
            assert dut.vsync.value == vsync
            assert dut.hsync.value == 1
            await ClockCycles(dut.clk, 1)

        if i % 525 == 480:
            image.save(f"output/frame{frame_num_start + (i // 525)}.png")


@cocotb.test()
async def test_vga_frames(dut):
    dut._log.info("Start")

    # Set the clock period to 39.68 ns (~25.2MHz)
    clock = Clock(dut.clk, 39.68, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    await reset(dut)

    # Should start reading flash after 1 cycle
    await ClockCycles(dut.clk, 1)

    await start_read(dut, 0)

    await send_instr(dut, InstructionLUI(a4, 0x8800).encode())
    await send_instr(dut, InstructionADDI(a4, a4, 0x400).encode())

    # Enable the video RAM
    await send_instr(dut, InstructionADDI(x1, x0, 1).encode())
    await send_instr(dut, InstructionSB(a4, x1, 0x600).encode())
    await send_instr(dut, InstructionSB(a4, x0, 0x600).encode())
    await send_instr(dut, InstructionSB(a4, x1, 0x600).encode())

    capture_task = cocotb.start_soon(capture_frames(dut, 2, 16))

    RAM_SIZE = 2560
    RAM = [0]*RAM_SIZE
    for i in range(0, RAM_SIZE, 1):
        await send_instr(dut, InstructionADDI(x1, x0, i-0x400).encode())
        await send_instr(dut, InstructionSB(a4, x1, i-0x400).encode())
        RAM[i] = i & 0xff

    await start_nops(dut)

    await capture_task
    await stop_nops()

    # Scroll 1
    await send_instr(dut, InstructionADDI(x1, x0, 1).encode())
    await send_instr(dut, InstructionSB(a4, x1, 0x601).encode())
    await send_instr(dut, InstructionSB(a4, x0, 0x600).encode())
    await send_instr(dut, InstructionSB(a4, x1, 0x600).encode())

    await start_nops(dut)
    await capture_frames(dut, 1, 0, 2)

    await stop_nops()

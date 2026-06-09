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

async def get_hdmi_pixel(dut):
    channels = [0,0,0,0]

    for i in range(5):
        await ClockCycles(dut.clk5x, 1, True)
        await Timer(1, "ns")
        for j in range(4):
            channels[j] >>= 1
            channels[j] |= 0x200 if dut.dvi_p.value[j] else 0
            assert dut.dvi_p.value[j] != dut.dvi_n.value[j]
        #print(i)
        assert (channels[3] & 0x200) == (0x200 if i > 2 else 0)
        await ClockCycles(dut.clk5x, 1, False)
        await Timer(1, "ns")
        for j in range(4):
            channels[j] >>= 1
            channels[j] |= 0x200 if dut.dvi_p.value[j] else 0
            assert dut.dvi_p.value[j] != dut.dvi_n.value[j]
        assert (channels[3] & 0x200) == (0x200 if i >= 2 else 0)

    return channels

def decode_ctrl(sym):
    if sym == 0b1101010100: v, h = 0, 0
    elif sym == 0b0010101011: v, h = 0, 1
    elif sym == 0b0101010100: v, h = 1, 0
    elif sym == 0b1010101011: v, h = 1, 1
    else: 
        print(f"{sym:010b}")
        assert False

    return v, h

def decode_sym(sym):
    if sym & 0x200:
        sym ^= 0xff
    data = sym & 1
    xor = ((sym & 0xff) >> 1) ^ sym
    data |= (xor << 1) & 0xfe
    if (sym & 0x100) == 0:
        data ^= 0xfe
    return data

async def capture_frames(dut, n=1, capture_start=0, frame_num_start=0):
    image = Image.new("RGB", (640, 480))

    await ClockCycles(dut.clk, 24)
    await ClockCycles(dut.clk5x, 2, False)

    # Test sync
    for i in range(525*n+5):
        vsync = 0 if (480+10) <= i % 525 < (480+12) else 1
        for j in range(640+16):
            channels = await get_hdmi_pixel(dut)
            if i % 525 < 480 and j < 640:
                if i > capture_start:
                    red = decode_sym(channels[2])
                    green = decode_sym(channels[1])
                    blue = decode_sym(channels[0])
                    image.putpixel((j, i % 525), (red, green, blue))            
            else:
                v, h = decode_ctrl(channels[0])
                assert v == vsync
                assert h == 1
            #print(j, end="")
        for j in range(96):
            channels = await get_hdmi_pixel(dut)
            v, h = decode_ctrl(channels[0])
            assert v == vsync
            assert h == 0
        for j in range(48):
            channels = await get_hdmi_pixel(dut)
            v, h = decode_ctrl(channels[0])
            assert v == vsync
            assert h == 1

        if i % 525 == 480:
            image.save(f"output/dvi_frame{frame_num_start + (i // 525)}.png")


@cocotb.test()
async def test_dvi_frames(dut):
    dut._log.info("Start")

    # Set the clock period to 39.68 ns (~25.2MHz)
    clock = Clock(dut.clk, 39.68, unit="ns")
    cocotb.start_soon(clock.start())
    clock5 = Clock(dut.clk5x, 39.68/5, unit="ns")
    cocotb.start_soon(clock5.start())

    # Reset
    await reset(dut, use_hdmi=True)

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

    for i in range(80*30):
        await send_instr(dut, InstructionADDI(x1, x0, i-0x400).encode())
        await send_instr(dut, InstructionSB(a4, x1, i-0x400).encode())

    await start_nops(dut)

    await capture_task
    await stop_nops()

# The rest of the console as the recompiled code meets it: the memory map, the CPU's registers,
# DMA, the vertical blank's NMI and joypads, the H/V timer's IRQ.

import recomp.snes.console

fn poke(addr u32, v u8):
	console.write8(addr, v)

fn peek(addr u32):
	console.read8(addr)

# the CPU's internal cycles, an interrupt they saw entered after each
fn idleCycles(n i64):
	loop n:
		console.idle()
		console.catchUp()

test "work RAM, its mirrors and its port":
	console.powerOn()
	poke(0x7E_0010, 0x12)
	poke(0x00_1FFF, 0x34)
	poke(0x7F_0005, 0x56)
	console.cpuRead(0x7E_0010)   # the bus carries 12: a read of nothing gives it back
	print("{peek(0x00_0010):X} {peek(0x80_0010):X} {peek(0x7E_1FFF):X} {peek(0x00_2010):X}")
	poke(0x2181, 0x05)
	poke(0x2182, 0x00)
	poke(0x2183, 0x01)
	poke(0x2180, 0x78)
	print("{peek(0x7F_0005):X} {peek(0x7F_0006):X} {console.read16(0x7E_1FFF):X}")
	prints """
		12 12 34 12
		78 0 34
		"""

# the CPU's cycles a multiplication (8) or a division (16) takes before its result is whole
fn waitCycles(count i64):
	loop count + 1:
		console.idle()

test "the multiplier and the divider":
	console.powerOn()
	poke(0x4202, 12)
	poke(0x4203, 13)
	waitCycles(8)
	print("{peek(0x4216)} {peek(0x4217)} {peek(0x4214)}")
	poke(0x4204, 0xE8)
	poke(0x4205, 0x03)
	poke(0x4206, 7)
	waitCycles(16)
	print("{peek(0x4214)} {peek(0x4216)}")
	poke(0x4206, 0)
	waitCycles(16)
	print("{peek(0x4214):X} {peek(0x4215):X} {console.read16(0x4216)}")
	prints """
		156 0 13
		142 6
		FF FF 1000
		"""

test "a result read before the multiplication ends is the partial one":
	console.powerOn()
	poke(0x4202, 0xFF)
	poke(0x4203, 0xFF)
	waitCycles(3)
	print("{console.read16(0x4216)}")
	waitCycles(8)
	print("{console.read16(0x4216)}")
	prints """
		1785
		65025
		"""

test "DMA from work RAM to VRAM and CGRAM; VRAM read back and remapped":
	console.powerOn()
	for i, b in [0x34, 0x12, 0x78, 0x56, 0x1F, 0x00, 0xE0, 0x03]:
		poke(0x7E_0100 + u32(i), u8(b))
	poke(0x2115, 0x80)
	poke(0x2116, 0x00)
	poke(0x2117, 0x01)
	poke(0x4300, 0x01)                 # two registers, 2118 then 2119
	poke(0x4301, 0x18)
	poke(0x4302, 0x00)
	poke(0x4303, 0x01)
	poke(0x4304, 0x7E)
	poke(0x4305, 4)
	poke(0x4306, 0)
	poke(0x2121, 1)
	poke(0x4310, 0x00)                 # one register, 2122
	poke(0x4311, 0x22)
	poke(0x4312, 0x04)
	poke(0x4313, 0x01)
	poke(0x4314, 0x7E)
	poke(0x4315, 4)
	poke(0x4316, 0)
	poke(0x420B, 0x03)
	idleCycles(4)                      # line 0 asked for the HDMA's tables first: the DMA runs after
	print(
		"{console.vram[0x100]:X} {console.vram[0x101]:X} {console.cgram[1]:X} {console.cgram[2]:X}"
	)
	print("{peek(0x4302):X} {peek(0x4303):X} {peek(0x4305)} {peek(0x430F):X}")
	poke(0x2116, 0x00)
	poke(0x2117, 0x01)
	print("{peek(0x2139):X} {peek(0x213A):X}")
	poke(0x2115, 0x84)                 # remapped: address 1 is word 8
	poke(0x2116, 0x01)
	poke(0x2117, 0x00)
	poke(0x2118, 0xCD)
	poke(0x2119, 0xAB)
	print("{console.vram[8]:X}")
	prints """
		1234 5678 1F 3E0
		4 1 0 FF
		34 12
		ABCD
		"""

mut entered i64[] = []

fn onNmi():
	entered.push(console.line)

fn onIrq():
	entered.push(1000 + console.line)
	_ = peek(0x4211)

fn irqAllowed():
	true

test "the vertical blank: its NMI, its flags, the joypad read":
	console.powerOn()
	entered = []
	console.hooks = console.Hooks(nmi = onNmi)
	console.buttons = console.buttonA | console.buttonStart
	poke(0x4200, 0x81)
	console.runFrame(l: pass)
	idleCycles(3)                      # the NMI is seen 6 master cycles into the line
	print("{entered} {console.frameCount} {peek(0x4212) & 0x80:X}")
	console.cpuRead(0x7E_0000)   # 4210's bits 4-6 are the bus's: 00 here
	print("{peek(0x4210):X} {peek(0x4210):X} {peek(0x4218):X} {peek(0x4219):X}")
	console.runFrame(l: pass)
	idleCycles(3)
	print("{entered}")
	console.hooks = console.Hooks()
	prints """
		[225] 1 80
		82 2 80 10
		[225, 225]
		"""

test "the V timer raises the IRQ at its line, once a frame":
	console.powerOn()
	entered = []
	console.hooks = console.Hooks(irq = onIrq, irqAllowed = irqAllowed)
	poke(0x4209, 100)
	poke(0x420A, 0)
	poke(0x4200, 0x20)
	console.runFrame(l: pass)
	console.runFrame(l: pass)
	print(entered)
	console.hooks = console.Hooks()
	prints "[1100, 1100]"

test "WAI runs the hardware to the NMI":
	console.powerOn()
	entered = []
	console.hooks = console.Hooks(nmi = onNmi)
	poke(0x4200, 0x80)
	console.waitForInterrupt()
	print("{entered} {console.line}")
	console.hooks = console.Hooks()
	prints "[225] 225"

test "a blank frame and cleared work RAM hash as Mesen 2's first frames do":
	console.powerOn()
	console.runFrame(l: pass)
	print("{console.screenHash():08x} {console.wramHash():08x}")
	prints "5b8f41c5 bcc31dc5"

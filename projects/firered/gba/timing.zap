# Time, counted in the CPU's cycles (16.78 MHz): the recompiled code adds each block's cycles
# and, at the heads of its loops, runs the events that are due. The screen draws a line in 1,232
# cycles (1,006 then the horizontal blank), 228 lines a frame (160 then the vertical blank); the
# four timers count at their rate and overflow; an interrupt asked for and allowed runs its
# handler then and there, as the BIOS enters it.

import cpu

pub mut cycles i64 = 0
pub mut nextEvent i64 = 0

pub cyclesPerLine = 1232
hdrawCycles = 1006
pub linesPerFrame = 228
pub visibleLines = 160

pub mut line = 0
mut lineStart i64 = 0
mut inHblank = false
pub mut frameCount = 0

pub irqVblank u32 = 1
pub irqHblank u32 = 2
pub irqVcount u32 = 4
pub irqTimer0 u32 = 8
pub irqDma0 u32 = 0x100
pub irqKeypad u32 = 0x1000

fn lineEvent():
	lineStart + (cyclesPerLine if inHblank else hdrawCycles)

fn scheduleEvents():
	nextEvent = lineEvent().min(nextTimerOverflow())

# something that the next check must see (an interrupt asked for, allowed): due now
pub fn interruptsChanged():
	nextEvent = nextEvent.min(cycles)

# Runs the events up to now, then the interrupt that is asked for and allowed.
pub fn catchUp():
	while cycles >= nextEvent:
		stepEvent()
		scheduleEvents()
		if interruptPending(): break
	enterInterrupt()

fn stepEvent():
	runTimersTo(cycles)
	if cycles < lineEvent(): return
	if not inHblank:
		inHblank = true
		if line < visibleLines:
			drawLine(line)
			dmaOnTiming(2)
		if ioHalf(regDispstat) & 0x10 != 0: raise(irqHblank)
		return
	inHblank = false
	lineStart += cyclesPerLine
	line += 1
	if line == linesPerFrame: line = 0
	if line == visibleLines:
		if ioHalf(regDispstat) & 8 != 0: raise(irqVblank)
		dmaOnTiming(1)
		frameCount += 1
		frameDone()
	if line == (ioHalf(regDispstat) >> 8) and ioHalf(regDispstat) & 0x20 != 0: raise(irqVcount)

pub fn dispstat() u32:
	v = ioHalf(regDispstat) & 0xFFF8
	vblank = line >= visibleLines and line < linesPerFrame - 1
	stamp = cpu.bit(vblank) | (cpu.bit(cycles - lineStart >= hdrawCycles) << 1) |
		(cpu.bit(line == (v >> 8)) << 2)
	v | stamp

fn interruptPending():
	ioHalf(regIme) & 1 == 1 and ioHalf(regIe) & ioHalf(regIf) != 0 and
		cpu.control & cpu.irqDisabled == 0

# The interrupt entered as the BIOS enters it: in IRQ mode, interrupts off, r0-r3, r12 and lr
# pushed on the IRQ stack, then the handler at 0x03007FFC called. Every register comes back as
# it was.
pub mut interruptCount = 0

fn enterInterrupt():
	if not interruptPending(): return
	interruptCount += 1
	saved u32[15] = [
		cpu.r0,
		cpu.r1,
		cpu.r2,
		cpu.r3,
		cpu.r4,
		cpu.r5,
		cpu.r6,
		cpu.r7,
		cpu.r8,
		cpu.r9,
		cpu.r10,
		cpu.r11,
		cpu.r12,
		cpu.r13,
		cpu.r14
	]
	control = cpu.control
	cpu.setControl(cpu.modeIrq | cpu.irqDisabled)
	cpu.spsr = control
	cpu.r13 -= 24
	for k, r in [saved[0], saved[1], saved[2], saved[3], saved[12], saved[14]]:
		store32(cpu.r13 + u32(4 * k), r)
	cpu.r0 = 0x0400_0000
	cpu.r14 = 0x0000_0138
	cpu.hooks.call(load32(0x0300_7FFC))
	cpu.r13 += 24
	cpu.setControl(control)
	cpu.r0 = saved[0]
	cpu.r1 = saved[1]
	cpu.r2 = saved[2]
	cpu.r3 = saved[3]
	cpu.r4 = saved[4]
	cpu.r5 = saved[5]
	cpu.r6 = saved[6]
	cpu.r7 = saved[7]
	cpu.r8 = saved[8]
	cpu.r9 = saved[9]
	cpu.r10 = saved[10]
	cpu.r11 = saved[11]
	cpu.r12 = saved[12]
	cpu.r13 = saved[13]
	cpu.r14 = saved[14]

# the CPU halted until an interrupt is asked for (one allowed by IE, whatever IME says)
pub fn halt():
	rounds = 0
	while ioHalf(regIe) & ioHalf(regIf) == 0:
		cycles = nextEvent.max(cycles)
		stepEvent()
		scheduleEvents()
		rounds += 1
		if rounds > 10_000_000:
			fail("halted with no interrupt that can come (IE 0x{ioHalf(regIe):X})")
	enterInterrupt()

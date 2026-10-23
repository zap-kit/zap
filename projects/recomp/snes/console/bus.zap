# The CPU's bus cycles, as Mesen 2's 65816 runs them. Each takes the speed of what it reaches (6
# master cycles for an internal cycle, the fast ROM and the registers, 8 for work RAM and the slow
# ROM, 12 for the old joypad ports); at its start a DMA or HDMA the hardware asked for takes its
# turn and the NMI and IRQ lines are seen (cycleStart, Mesen's ProcessCpuCycle); then its time
# passes, the hardware's events running at theirs. A read takes its value 4 master cycles before
# the cycle ends, a write at its end.

pub mut needNmi = false   # the NMI seen: entered after the instruction
pub mut irqSeen = false   # the IRQ line seen with the I flag clear: entered after the instruction
mut waiOver = false       # a cycle of a WAI saw an interrupt
mut halted = false        # in a WAI
mut nmiCountdown = 0      # the cycles that see the NMI line before it counts, from nmiFrom on
mut nmiFrom i64 = 0
pub mut cpuCycles i64 = 0   # the CPU's cycles since power-on (the multiplier's clock, alu.zap)

pub fn isHalted() bool:
	halted

fn cpuLinesPowerOn():
	needNmi = false
	irqSeen = false
	waiOver = false
	halted = false
	nmiCountdown = 0

fn busFields(mut f StateFile):
	needNmi = f.isSet(needNmi)
	irqSeen = f.isSet(irqSeen)
	waiOver = f.isSet(waiOver)
	halted = f.isSet(halted)
	nmiCountdown = f.int(nmiCountdown)
	nmiFrom = f.int(nmiFrom)
	cpuCycles = f.int(cpuCycles)
	busCodeAt = f.long(busCodeAt)
	busData = f.byte(busData)
	busFromCode = f.isSet(busFromCode)

# The open bus: what a read of an address nothing answers gives, the last byte the bus carried as
# Mesen 2 counts them: a code byte the CPU fetched, a byte it read (not of the registers at
# 4000-4FFF, which sit on the CPU's own bus), a byte a DMA moved; the CPU's writes leave it. The
# fetches are kept as where their last byte is, read only when an open bus is.
mut busCodeAt u32 = 0
mut busData u8 = 0
mut busFromCode = true

pub fn openBus() u8:
	if not busFromCode: return busData
	memoryByte(busCodeAt) ?? busData   # code fetched from no memory: the bus as it was

fn noteBusCode(at u32):
	busCodeAt = at
	busFromCode = true

fn noteBusData(v u8):
	busData = v
	busFromCode = false

fn isCpuRegister(addr u32):
	off = addr & 0xFFFF
	addr & 0x40_0000 == 0 and off >= 0x4000 and off < 0x5000

# n fetches of the code at `at`
pub fn fetch(n i64, at u32):
	noteBusCode((at & 0xFF_0000) | ((at + u32(n) - 1) & 0xFFFF))
	speed = accessCycles(at)
	loop n:
		busCycle(speed)

pub fn idle():
	busCycle(6)

# an implied instruction's second cycle: a read of the code at `at` when an interrupt is about to
# be taken, else an internal cycle
pub fn idleOrRead(at u32):
	nmiNext = nmiCountdown == 1 and cycles >= nmiFrom   # the line is up and counts at the next cycle
	irqNow = irqLineUp() and hooks.irqAllowed()   # raised since this cycle's start, as Mesen's IrqSource
	if irqSeen or irqNow or needNmi or nmiNext:
		noteBusCode((at & 0xFF_0000) | ((at + 1) & 0xFFFF))   # the byte after it, where the PC is
		busCycle(accessCycles(at))
	else:
		busCycle(6)

pub fn cpuRead(addr u32) u8:
	speed = accessCycles(addr)
	cycleStart(speed)
	cycles += speed - 4
	runDue()
	v = read8(addr)
	if not isCpuRegister(addr): noteBusData(v)
	cycles += 4
	runDue()
	v

pub fn cpuWrite(addr u32, v u8):
	speed = accessCycles(addr)
	cycleStart(speed)
	cycles += speed
	runDue()
	write8(addr, v)

fn busCycle(speed i64):
	cycleStart(speed)
	cycles += speed
	runDue()

fn runDue():
	if cycles >= lineEventAt or irqAt >= 0 and cycles >= irqAt: advance()

# A cycle's start: the transfer asked for run (the cycle then sees no interrupt), the NMI counted
# down, the IRQ line looked at.
fn cycleStart(speed i64):
	cpuCycles += 1
	locked = false
	if transferAsked: locked = runAskedTransfers(speed)
	if nmiCountdown > 0 and cycles >= nmiFrom:
		nmiCountdown -= 1
		if nmiCountdown == 0 and locked:
			nmiCountdown = 1
		elif nmiCountdown == 0:
			needNmi = true
			waiOver = true
			updateDue()
	irqSeen = false
	if locked or not irqLineUp(): return
	waiOver = true
	irqSeen = hooks.irqAllowed()

# the IRQ line up: the H/V timer's flag raised and enabled, its time come
fn irqLineUp():
	irqFlag and nmitimen & 0x30 != 0 and cycles >= irqLineAt

# The NMI line rises: it counts at the `count`-th CPU cycle that starts at `from` or after.
fn raiseNmi(from i64, count i64):
	nmiFrom = from
	nmiCountdown = count

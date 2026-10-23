# The eight DMA channels (43x0-43xA): a general transfer between the A bus (any address) and a
# B-bus port (2100-21FF: VRAM 2118-2119, CGRAM 2122, OAM 2104...), run whole once 420B asks for
# it, and the HDMA (hdma.zap). The channels' registers are kept as written; a transfer moves their
# addresses and counts on.
#
# Timed as Mesen 2 times them: the hardware asks (420B written, the HDMA's events) and the CPU's
# second cycle after runs the transfer at its start (runAskedTransfers, from bus.zap's
# cycleStart): it waits for a whole multiple of 8 master cycles, takes 8, and 8 a channel and a
# byte (4 to read it, 4 to write it), and ends on a whole CPU cycle (that cycle's length) from where
# it began, the cycles it counted for that (Mesen counting a channel's bytes in 8 bits) shared
# with an HDMA run inside it.

pub mut dmaRegs u8[] = fill(0x80, 0xFF)
pub mut hdmaChannels u8 = 0
pub mut transferAsked = false   # a transfer waits for the CPU's next cycle
mut dmaAsked = false
mut dmaChannels u8 = 0   # those 420B started that have not run yet
mut startDelay = false   # the CPU's next cycle is the one after the asking
mut dmaRunning = false
mut transferCounted = 0   # the cycles counted for the end's wait

fn dmaPowerOn():
	dmaRegs = fill(0x80, 0xFF)
	hdmaChannels = 0
	transferAsked = false
	dmaAsked = false
	dmaChannels = 0
	startDelay = false
	dmaRunning = false
	hdmaPowerOn()

fn dmaFields(mut f StateFile):
	f.byteList(dmaRegs)
	hdmaChannels = f.byte(hdmaChannels)
	transferAsked = f.isSet(transferAsked)
	dmaAsked = f.isSet(dmaAsked)
	dmaChannels = f.byte(dmaChannels)
	startDelay = f.isSet(startDelay)
	dmaRunning = f.isSet(dmaRunning)
	transferCounted = f.int(transferCounted)
	for k in 0..8:
		hdmaDone[k] = f.isSet(hdmaDone[k])
		hdmaDoTransfer[k] = f.isSet(hdmaDoTransfer[k])
	hdmaAsked = f.isSet(hdmaAsked)
	hdmaInitAsked = f.isSet(hdmaInitAsked)

# the bytes a unit of each transfer mode moves, and the port each goes to past the channel's
transferBytes = [1, 2, 2, 4, 4, 4, 2, 4]
transferPorts = [
	0,
	0,
	0,
	0,
	0,
	1,
	0,
	1,
	0,
	0,
	0,
	0,
	0,
	0,
	1,
	1,
	0,
	1,
	2,
	3,
	0,
	1,
	0,
	1,
	0,
	0,
	0,
	0,
	0,
	0,
	1,
	1
]

fn dmaRegisterRead(off u32):
	r = i64(off & 0x7F)
	if r & 0xF > 0xB and r & 0xF != 0xF: return openBus()
	dmaRegs[r & 0x7B if r & 0xF == 0xF else r]

fn dmaRegisterWrite(off u32, v u8):
	r = i64(off & 0x7F)
	if r & 0xF > 0xB and r & 0xF != 0xF: return
	dmaRegs[r & 0x7B if r & 0xF == 0xF else r] = v

fn reg(ch i64, r i64) i64:
	dmaRegs[ch * 16 + r]

fn reg16(ch i64, r i64):
	reg(ch, r) | (reg(ch, r + 1) << 8)

fn setReg16(ch i64, r i64, v i64):
	dmaRegs[ch * 16 + r] = v & 0xFF
	dmaRegs[ch * 16 + r + 1] = (v >> 8) & 0xFF

fn port(ch i64, unit i64) u32:
	0x2100 | ((reg(ch, 1) + transferPorts[(reg(ch, 0) & 7) * 4 + (unit & 3)]) & 0xFF)

# A byte between the buses, 4 master cycles to read it and 4 to write it. The A bus does not reach
# the B bus nor the DMA's own registers; work RAM to 2180 (or back) moves nothing.
fn copyByte(a u32, b u32, toA bool):
	bank = (a >> 16) & 0xFF
	off = a & 0xFFFF
	isWram = bank == 0x7E or bank == 0x7F or (bank & 0x40 == 0 and off < 0x2000)
	if b == 0x2180 and isWram:
		transferTakes(8)
		if toA: write8(a, 0xFF)
		return
	transferTakes(4)
	aBus = bank & 0x40 != 0 or
		not (off >= 0x2100 and off < 0x2200 or off >= 0x4300 and off < 0x4380)
	v = read8(b) if toA else read8(a) if aBus else openBus()
	noteBusData(v)
	transferTakes(4)
	if toA:
		write8(a, v)
	else:
		busBWrite(b, v)

# the transfer's time: the CPU stalled, the hardware's events running at theirs
fn transferTakes(n i64):
	cycles += n
	runDue()

# 420B written: its channels asked for.
fn askDma(enable u8):
	dmaChannels |= enable
	if enable == 0: return
	dmaAsked = true
	startDelay = true
	transferAsked = true

# At a CPU cycle's start: the transfer asked for, run unless this is the cycle right after the
# asking; whether one ran (the cycle then sees no interrupt).
fn runAskedTransfers(speed i64) bool:
	ran = false
	if startDelay:
		startDelay = false
	elif hdmaAsked:
		ran = runHdma(speed)
	elif hdmaInitAsked:
		ran = runHdmaInit(speed)
	elif dmaAsked:
		dmaAsked = false
		runDma(speed)
		ran = true
	transferAsked = startDelay or dmaAsked or hdmaAsked or hdmaInitAsked
	ran

fn runDma(speed i64):
	syncTransfer()
	transferTakes(8)
	transferCounted += 8
	dmaRunning = true
	if transferAsked: runAskedTransfers(speed)
	for ch in 0..8:
		if dmaChannels & (u8(1) << u8(ch)) != 0: runChannel(ch, speed)
	dmaChannels = 0
	dmaRunning = false
	endTransfer(speed)

fn runChannel(ch i64, speed i64):
	control = reg(ch, 0)
	toA = control & 0x80 != 0
	step = 0 if control & 0x08 != 0 else -1 if control & 0x10 != 0 else 1
	bank = u32(reg(ch, 4)) << 16
	count = reg16(ch, 5)
	if count == 0: count = 0x1_0000
	at = reg16(ch, 2)
	transferTakes(8)
	transferCounted += 8
	if transferAsked: runAskedTransfers(speed)
	for unit in 0..count:
		copyByte(bank | u32(at), port(ch, unit), toA)
		at = (at + step) & 0xFFFF
		if transferAsked: runAskedTransfers(speed)
	transferCounted += 8 * (count & 0xFF)
	setReg16(ch, 2, at)
	setReg16(ch, 5, 0)

# the wait for a whole multiple of 8 master cycles since power-on, which starts the count
fn syncTransfer():
	transferCounted = 8 - (cycles & 7)
	transferTakes(transferCounted)

# the wait for a whole CPU cycle (`speed`) since the transfer began
fn endTransfer(speed i64):
	transferTakes(speed - transferCounted % speed)

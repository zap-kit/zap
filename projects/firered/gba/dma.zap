# The four DMA channels: a transfer of halfwords or words from one address to another, started
# at once, at the vertical or the horizontal blank, or (channels 1 and 2) when a sound FIFO runs
# low. At each start the count and the addresses are those the registers last set, or where the
# last transfer of a repeating channel left them.

mut sources u32[4] = [0, 0, 0, 0]
mut targets u32[4] = [0, 0, 0, 0]

fn dmaBase(ch i64):
	0xB0 + 12 * ch

fn dmaEnabled(ch i64):
	io.u16le(dmaBase(ch) + 10) >> 15 == 1

fn dmaTiming(ch i64):
	i64(io.u16le(dmaBase(ch) + 10) >> 12) & 3

# the control written: a channel turned on takes its addresses, and runs if it is immediate
pub fn dmaControl(ch i64, before u16, v u16):
	if ch < 0 or ch > 3: fail("dma {ch} {before} {v}")
	if before >> 15 == 1 or v >> 15 == 0: return
	sources[ch] = io.u32le(dmaBase(ch))
	targets[ch] = io.u32le(dmaBase(ch) + 4)
	if dmaTiming(ch) == 0: runDma(ch)

# the channels waiting for a timing (1 vertical blank, 2 horizontal blank, 3 the FIFOs) run
pub fn dmaOnTiming(timing i64):
	for ch in 0..4:
		if dmaEnabled(ch) and dmaTiming(ch) == timing: runDma(ch)

fn step(control u32, shift u32, size u32):
	match (control >> shift) & 3:
		0, 3: size
		1: 0 - size
		_: 0

fn runDma(ch i64):
	base = dmaBase(ch)
	control = u32(io.u16le(base + 10))
	words = control & 0x400 != 0
	fifo = dmaTiming(ch) == 3 and (ch == 1 or ch == 2)
	count = i64(io.u16le(base + 8))
	if count == 0: count = 0x1_0000 if ch == 3 else 0x4000
	if fifo: count = 4
	size u32 = 4 if words or fifo else 2
	srcStep = step(control, 7, size)
	dstStep = u32(0) if fifo else step(control, 5, size)
	src = sources[ch]
	dst = targets[ch]
	loop count:
		if size == 4:
			store32(dst & ~u32(3), load32(src & ~u32(3)))
		else:
			store16(dst & ~u32(1), load16(src & ~u32(1)))
		src += srcStep
		dst += dstStep
	sources[ch] = src
	targets[ch] = io.u32le(base + 4) if (control >> 5) & 3 == 3 else dst
	cycles += count * 2
	if control & 0x4000 != 0: raise(irqDma0 << u32(ch))
	if control & 0x200 == 0 or dmaTiming(ch) == 0:
		io.setU16le(base + 10, control & 0x7FFF)

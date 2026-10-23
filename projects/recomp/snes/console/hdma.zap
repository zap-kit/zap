# The HDMA: each channel 420C enables walks its table down the frame, writing its line's bytes at
# the horizontal blank of the line before (direct, or through an indirect address), a table entry
# a count of lines: below 0x80 written once and held, above it written every line. Line 0 asks for
# the tables' first entries, each of lines 0-224 for its transfer (timing.zap's events), and the
# CPU's cycles run them as they run a DMA (dma.zap): the sync to 8 and its 8, 8 a byte moved and a
# table byte read (16 an indirect address), the end on a whole CPU cycle; inside a DMA, neither
# wait, their cycles counted with the DMA's.

mut hdmaDone bool[8] = [false, false, false, false, false, false, false, false]
mut hdmaDoTransfer bool[8] = [false, false, false, false, false, false, false, false]
mut hdmaAsked = false
mut hdmaInitAsked = false

fn hdmaPowerOn():
	hdmaDone = [false, false, false, false, false, false, false, false]
	hdmaDoTransfer = [false, false, false, false, false, false, false, false]
	hdmaAsked = false
	hdmaInitAsked = false

fn askHdmaInit():
	hdmaInitAsked = true
	startDelay = true
	transferAsked = true

fn askHdma():
	if hdmaChannels == 0: return
	hdmaAsked = true
	startDelay = true
	transferAsked = true

# the frame's start: every enabled channel takes its table's first entry (its line count and, for
# an indirect one, its address: one byte when the count ends it); whether it ran
fn runHdmaInit(speed i64):
	hdmaInitAsked = false
	for ch in 0..8:
		hdmaDone[ch] = false
		hdmaDoTransfer[ch] = false
	if hdmaChannels == 0: return false
	beginHdma()
	for ch in 0..8:
		hdmaDoTransfer[ch] = true
		if hdmaChannels & (u8(1) << u8(ch)) == 0: continue
		setReg16(ch, 8, reg16(ch, 2))
		count = tableByte(ch)
		dmaRegs[ch * 16 + 10] = count
		if count == 0: hdmaDone[ch] = true
		if reg(ch, 0) & 0x40 != 0:
			low = i64(tableByte(ch))
			setReg16(ch, 5, low << 8 if hdmaDone[ch] else low | (i64(tableByte(ch)) << 8))
	endHdma(speed)
	true

# A line's HDMA: each live channel's bytes written if its entry says so, then its count stepped
# and, when it runs out, the next entry read; whether it ran.
fn runHdma(speed i64):
	hdmaAsked = false
	if hdmaChannels == 0: return false
	beginHdma()
	for ch in 0..8:
		if not isHdmaLive(ch) or not hdmaDoTransfer[ch]: continue
		indirect = reg(ch, 0) & 0x40 != 0
		toA = reg(ch, 0) & 0x80 != 0
		for unit in 0..transferBytes[reg(ch, 0) & 7]:
			transferCounted += 8
			if indirect:
				at = reg16(ch, 5)
				copyByte((u32(reg(ch, 7)) << 16) | u32(at), port(ch, unit), toA)
				setReg16(ch, 5, at + 1)
			else:
				at = reg16(ch, 8)
				copyByte((u32(reg(ch, 4)) << 16) | u32(at), port(ch, unit), toA)
				setReg16(ch, 8, at + 1)
	for ch in 0..8:
		if isHdmaLive(ch): hdmaStep(ch)
	endHdma(speed)
	true

fn beginHdma():
	if not dmaRunning: syncTransfer()
	transferTakes(8)
	transferCounted += 8

fn endHdma(speed i64):
	if not dmaRunning: endTransfer(speed)

fn isHdmaLive(ch i64):
	hdmaChannels & (u8(1) << u8(ch)) != 0 and not hdmaDone[ch]

# the table's next byte (4 master cycles, and 4 after), its address moved on
fn tableByte(ch i64):
	v = peekTable(ch)
	setReg16(ch, 8, reg16(ch, 8) + 1)
	v

fn peekTable(ch i64):
	transferTakes(4)
	v = read8((u32(reg(ch, 4)) << 16) | u32(reg16(ch, 8)))
	transferTakes(4)
	transferCounted += 8
	v

# a channel's count stepped, its table's next byte read either way
fn hdmaStep(ch i64):
	count = (reg(ch, 10) - 1) & 0xFF
	dmaRegs[ch * 16 + 10] = count
	hdmaDoTransfer[ch] = count & 0x80 != 0
	next = peekTable(ch)
	if count & 0x7F != 0: return
	setReg16(ch, 8, reg16(ch, 8) + 1)
	dmaRegs[ch * 16 + 10] = next
	if reg(ch, 0) & 0x40 != 0:
		# the last live channel ending its table reads one byte of the address, not two
		if next == 0 and not (ch + 1..8).any(isHdmaLive(it)):
			setReg16(ch, 5, i64(tableByte(ch)) << 8)
		else:
			low = i64(tableByte(ch))
			setReg16(ch, 5, low | (i64(tableByte(ch)) << 8))
	if next == 0: hdmaDone[ch] = true
	hdmaDoTransfer[ch] = true

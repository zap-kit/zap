# The PPU's registers (2100-213F) and its memories: VRAM (32K words, written through 2116-2119
# with the address remapped as 2115 says), CGRAM (256 BGR555 colours, two writes a colour), OAM
# (128 sprites of 4 bytes, then the 32-byte high table). Most registers are kept as written in
# `ppuRegs` and read by the drawing; the ports, the scrolls and the matrix keep their latches.
# A write first draws the line up to the dot it lands on, so a change mid-line splits it.

pub mut vram u16[] = zeros(0x8000)
pub mut cgram u16[] = zeros(256)
pub mut oam u8[] = zeros(544)
pub mut ppuRegs u8[] = zeros(0x40)

pub mut hScroll i64[4] = [0, 0, 0, 0]
pub mut vScroll i64[4] = [0, 0, 0, 0]
mut scrollLatch = 0
mut hScrollLatch = 0
mut matrixLatch = 0

mut vramAddress = 0
pub mut fixedColor = 0   # 2132's colour, BGR555
mut vramBuffer u16 = 0
mut cgramAddress = 0
mut cgramHigh = false
mut cgramBuffer u8 = 0
pub mut cgramRead = 0   # the colour the drawing read last, which CGRAM writes during it hit
mut oamAddress = 0      # 2102-2103, in words
pub mut oamInternal = 0 # in bytes, stepped by 2104 and 2138
mut oamBuffer u8 = 0
mut ppu1Bus u8 = 0
mut ppu2Bus u8 = 0
mut hLatched = 0
mut vLatched = 0
mut hLatchHigh = false
mut vLatchHigh = false
mut counterLatched = false
pub mut rangeOver = false
pub mut timeOver = false

# the PPU's memories, registers and latches; the mosaic's count and the line's drawing so far
fn ppuFields(mut f StateFile):
	f.wordList(vram)
	f.wordList(cgram)
	f.byteList(oam)
	f.byteList(ppuRegs)
	for k in 0..4:
		hScroll[k] = f.int(hScroll[k])
		vScroll[k] = f.int(vScroll[k])
		mosaicHeld[k] = f.int(mosaicHeld[k])
	mosaicCounter = f.int(mosaicCounter)
	drawnTo = f.int(drawnTo)
	scrollLatch = f.int(scrollLatch)
	hScrollLatch = f.int(hScrollLatch)
	matrixLatch = f.int(matrixLatch)
	vramAddress = f.int(vramAddress)
	fixedColor = f.int(fixedColor)
	vramBuffer = f.word(vramBuffer)
	cgramAddress = f.int(cgramAddress)
	cgramHigh = f.isSet(cgramHigh)
	cgramBuffer = f.byte(cgramBuffer)
	cgramRead = f.int(cgramRead)
	oamAddress = f.int(oamAddress)
	oamInternal = f.int(oamInternal)
	oamBuffer = f.byte(oamBuffer)
	ppu1Bus = f.byte(ppu1Bus)
	ppu2Bus = f.byte(ppu2Bus)
	hLatched = f.int(hLatched)
	vLatched = f.int(vLatched)
	hLatchHigh = f.isSet(hLatchHigh)
	vLatchHigh = f.isSet(vLatchHigh)
	counterLatched = f.isSet(counterLatched)
	rangeOver = f.isSet(rangeOver)
	timeOver = f.isSet(timeOver)

pub fn isBlanked() bool:
	ppuRegs[0] & 0x80 != 0

fn brightness() i64:
	(ppuRegs[0] & 0x0F)

fn vramIncrement():
	match ppuRegs[0x15] & 3:
		0: 1
		1: 32
		_: 128

fn isVramStepOnHigh():
	ppuRegs[0x15] & 0x80 != 0

# the word 2118-2119 reach: the address with its low bits turned as 2115's remapping says
fn vramWord():
	a = vramAddress
	match (ppuRegs[0x15] >> 2) & 3:
		1: (a & 0xFF00) | ((a & 0xE0) >> 5) | ((a & 0x1F) << 3)
		2: (a & 0xFE00) | ((a & 0x1C0) >> 6) | ((a & 0x3F) << 3)
		3: (a & 0xFC00) | ((a & 0x380) >> 7) | ((a & 0x7F) << 3)
		_: a

fn canReachVram():
	line >= vblankLine or isBlanked()

fn canReachCgram():
	h = clock - lineStart
	line >= vblankLine or line == 0 or isBlanked() or h < 88 or h >= 1096

fn stepVram():
	vramAddress = (vramAddress + vramIncrement()) & 0x7FFF

fn fillVramBuffer():
	vramBuffer = vram[vramWord()] if canReachVram() else 0

pub fn ppuWrite(off u32, v u8):
	advance()
	if line < vblankLine: drawTo(dot() - 22)
	r = i64(off & 0x3F)
	match r:
		0x00:
			if isBlanked() and line == vblankLine: oamInternal = oamAddress << 1
			noteBlankWrite()
			ppuRegs[0] = v
		0x02, 0x03:
			ppuRegs[r] = v
			oamAddress = i64(ppuRegs[2]) | (i64(ppuRegs[3] & 1) << 8)
			oamInternal = oamAddress << 1
		0x04: oamWrite(v)
		0x06:
			if v & 0x0F != 0 and ppuRegs[6] & 0x0F == 0: restartMosaic(v)
			ppuRegs[6] = v
		0x0D..0x15: scrollWrite(r, v)
		0x15: ppuRegs[r] = v
		0x16:
			vramAddress = (vramAddress & 0x7F00) | i64(v)
			fillVramBuffer()
		0x17:
			vramAddress = (vramAddress & 0xFF) | (i64(v & 0x7F) << 8)
			fillVramBuffer()
		0x18, 0x19: vramWrite(r == 0x19, v)
		0x1B..0x21: mode7MatrixWrite(r, v)
		0x21:
			cgramAddress = v
			cgramHigh = false
		0x22: cgramWrite(v)
		0x32:
			for (bit, shift) in [(0x20, 0), (0x40, 5), (0x80, 10)]:
				if v & bit != 0:
					fixedColor = (fixedColor & ~(0x1F << shift)) | (i64(v & 0x1F) << shift)
		0x05, 0x33:
			ppuRegs[r] = v
			widenOutput(drawnTo)
		_: ppuRegs[r] = v

fn scrollWrite(r i64, v u8):
	bg = (r - 0x0D) >> 1
	if r == 0x0D or r == 0x0E: mode7ScrollWrite(r, v)
	if r & 1 == 1:
		hScroll[bg] = ((i64(v) << 8) | (scrollLatch & ~7) | (hScrollLatch & 7)) & 0x3FF
		hScrollLatch = v
	else:
		vScroll[bg] = ((i64(v) << 8) | scrollLatch) & 0x3FF
	scrollLatch = v

fn vramWrite(high bool, v u8):
	if canReachVram():
		at = vramWord()
		vram[at] = (vram[at] & 0xFF) | (u16(v) << 8) if high else (vram[at] & 0xFF00) | v
	if high == isVramStepOnHigh(): stepVram()

fn cgramWrite(v u8):
	if cgramHigh:
		at = cgramAddress if canReachCgram() else cgramRead
		cgram[at] = u16(cgramBuffer) | (u16(v & 0x7F) << 8)
		cgramAddress = (cgramAddress + 1) & 0xFF
	else:
		cgramBuffer = v
	cgramHigh = not cgramHigh

fn oamWrite(v u8):
	at = oamInternal
	if at < 512:
		if at & 1 == 1:
			oam[at - 1] = oamBuffer
			oam[at] = v
		else:
			oamBuffer = v
	else:
		if at & 1 == 0: oamBuffer = v
		oam[0x200 | (at & 0x1F)] = v
	oamInternal = (oamInternal + 1) & 0x3FF

pub fn ppuRead(off u32) u8:
	advance()
	r = i64(off & 0x3F)
	match r:
		0x34, 0x35, 0x36:
			m7 = mode7Matrix[0] * (mode7Matrix[1] >> 8)
			ppu1Bus = (m7 >> (8 * (r - 0x34))) & 0xFF
			ppu1Bus
		0x37:
			if ioPort & 0x80 != 0: latchCounters()
			openBus()
		0x38: oamRead()
		0x39, 0x3A: vramRead(r == 0x3A)
		0x3B: cgramReadPort()
		0x3C:
			ppu2Bus = counterByte(hLatched, hLatchHigh)
			hLatchHigh = not hLatchHigh
			ppu2Bus
		0x3D:
			ppu2Bus = counterByte(vLatched, vLatchHigh)
			vLatchHigh = not vLatchHigh
			ppu2Bus
		0x3E:
			ppu1Bus = (0x80 if timeOver else 0) | (0x40 if rangeOver else 0) | (ppu1Bus & 0x10) | 1
			ppu1Bus
		0x3F:
			ppu2Bus = (0x80 if isOddFrame() else 0) | (0x40 if counterLatched else 0) |
				(ppu2Bus & 0x20) | (0x10 if linesPerFrame == 312 else 0) | 3
			if ioPort & 0x80 != 0: counterLatched = false
			hLatchHigh = false
			vLatchHigh = false
			ppu2Bus
		_: ppuOpenBus(off)

# A read of 2000-2FFF no register answers, as Mesen 2 decodes it: the PPU1's last byte where the
# address reads as 21x4-6 or 21x8-A, the CPU's open bus elsewhere.
fn ppuOpenBus(off u32):
	reg = off & 0x210F
	if reg >= 0x2104 and reg <= 0x2106 or reg >= 0x2108 and reg <= 0x210A: return ppu1Bus
	openBus()

# 2137: the dot and the line where the beam is
pub fn latchCounters():
	hLatched = dot()
	vLatched = line
	counterLatched = true

fn counterByte(v i64, high bool) u8:
	if high: return u8((v >> 8) & 1) | (ppu2Bus & 0xFE)
	v & 0xFF

fn oamRead():
	at = oamInternal
	ppu1Bus = oam[at] if at < 512 else oam[0x200 | (at & 0x1F)]
	oamInternal = (oamInternal + 1) & 0x3FF
	ppu1Bus

fn vramRead(high bool):
	ppu1Bus = u8(vramBuffer >> 8) if high else u8(vramBuffer & 0xFF)
	if high == isVramStepOnHigh():
		fillVramBuffer()
		stepVram()
	ppu1Bus

fn cgramReadPort():
	at = cgramAddress if canReachCgram() else cgramRead
	if cgramHigh:
		ppu2Bus = u8((cgram[at] >> 8) & 0x7F) | (ppu2Bus & 0x80)
		cgramAddress = (cgramAddress + 1) & 0xFF
	else:
		ppu2Bus = cgram[at] & 0xFF
	cgramHigh = not cgramHigh
	ppu2Bus

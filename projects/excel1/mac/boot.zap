# The Mac Plus as the Finder leaves it for an application: 1 MB of memory (Excel 1.00 keeps its
# heap below 1 MB) with the screen at its
# top, the low-memory globals, the trap tables, the system heap with the System file's resources,
# the application heap, the application's resources open over them, its A5 world and its stack.

import cpu

pub memTop u32 = 0x10_0000
pub screenBase u32 = memTop - 0x5900
pub screenWidth = 512
pub screenHeight = 342
pub screenRowBytes = 64
sysZoneStart u32 = 0x1400
sysZoneLimit u32 = 0x4_0000
defaultStack u32 = 0x6000

fn setLow16(at u32, v i64):
	cpu.write16(at, u32.wrap(v))

fn setLow32(at u32, v u32):
	cpu.write32(at, v)

fn initLowMemory():
	setLow32(memTopAt, memTop)
	setLow32(bufPtrAt, screenBase)
	setLow32(scrnBaseAt, screenBase)
	setLow16(screenRowAt, screenRowBytes)
	setLow16(scrVResAt, 72)   # the screen's dots per inch
	setLow16(scrHResAt, 72)
	setLow32(romBaseAt, romBase)
	setLow32(ramBaseAt, 0)
	setLow16(rom85At, 0x7FFF)
	setLow16(sysVersionAt, 0x0300)
	setLow32(lo3BytesAt, 0xFF_FFFF)
	setLow32(minusOneAt, 0xFFFF_FFFF)
	setLow32(oneOneAt, 0x0001_0001)
	setLow32(defltStackAt, defaultStack)
	setLow32(minStackAt, 0x400)
	setLow16(mBarHeightAt, 20)
	setLow16(kbdTypeAt, 3)
	setLow16(keyThreshAt, 16)
	setLow16(keyRepThreshAt, 4)
	setLow32(doubleTimeAt, 32)
	setLow32(caretTimeAt, 32)
	setLow16(sysEvtMaskAt, 0xFFEF)
	cpu.write8(resLoadAt, 1)
	cpu.write8(hiliteModeAt, 0xFF)
	setLow32(timeAt, 0xA0A1_B2C3)   # a date of 1989, fixed so that every run draws the same
	setLow16(apFontIdAt, 3)
	setLow16(curApRefNumAt, 0)

# the application's name, as the Finder sets CurApName
fn setAppName(name str):
	cpu.write8(curApNameAt, u32(name.len))
	for i in 0..name.len:
		cpu.write8(curApNameAt + 1 + u32(i), name[i])

# Readies the machine for the application in the prepared file: the address to start it at.
pub fn boot(volume str, application str) u32:
	initLowMemory()
	initTrapTables()
	initSony()
	cpu.readPast = readPastMemory
	cpu.writePast = writePastMemory
	initZone(sysZoneStart, sysZoneLimit, 64)
	setLow32(sysZoneAt, sysZoneStart)
	setLow32(theZoneAt, sysZoneStart)
	_ = openResFile("", "System") ?? fail("no System file prepared in {assetsDir}")
	# the desktop's pattern, as the System file keeps it (PAT 16)
	desk = getResource(osType("PAT "), 16, [], false)
	if desk != 0: moveBytes(deskPatternAt, address(cpu.read32(desk)), 8)
	# the application's zone up to its stack, which lies below the A5 world
	applStart = sysZoneLimit
	setLow32(applZoneAt, applStart)
	initZone(applStart, applStart + 0x1_0000, 64)
	setLow32(theZoneAt, applStart)
	setLow32(heapEndAt, cpu.read32(applStart))
	refNum = openResFile(volume, application) ?? fail("no {application} prepared on {volume}")
	setLow16(curApRefNumAt, refNum)
	setAppName(application)
	world = makeWorld(screenBase)
	stack = cpu.read32(curStackBaseAt)
	setLow32(applLimitAt, stack - defaultStack)
	cpu.a5 = world.a5
	cpu.a7 = stack
	cpu.push32(returnToZap)
	world.jumpTable + 2

# a read past the memory: the ROM's version words, the disk controller's registers and the VIA's
# register A, nothing else
fn readPastMemory(at i64, size i64):
	if isIwm(at): return iwmRead(at)
	if at == viaBufA: return 0x80
	if at >= romBase and at < (romBase + romSize):
		offset = at - romBase
		if offset == 8 and size == 2: return 0x0075
		return 0
	0

fn writePastMemory(at i64, size i64, v u32):
	if isIwm(at): iwmSwitch(at)

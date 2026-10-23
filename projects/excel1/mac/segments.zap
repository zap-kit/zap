# The Segment Loader: CODE 0 gives the A5 world (the bytes above A5, the application's globals
# below it, the jump table's length and offset) and the jump table, whose entries are each 8
# bytes, unloaded `offset, MOVE.W #segment,-(SP), _LoadSeg` and loaded `segment, JMP address`.
# _LoadSeg brings a CODE segment in, locked, and turns its entries into jumps.

import cpu

codeType = 0x434F_4445   # 'CODE'
loadSegWord u32 = 0xA9F0
jmpWord u32 = 0x4EF9

pub fn osType(text str) u32:
	text.bytes().u32be(0)

pub type World:
	a5 u32
	jumpTable u32   # its first entry
	jumpTableLength u32

pub mut world = World(a5 = 0, jumpTable = 0, jumpTableLength = 0)

# The A5 world laid out below `top` from CODE 0: A5, with the jump table copied above it.
pub fn makeWorld(top u32) World:
	h = getResource(codeType, 0, [], false)
	if h == 0: cpu.stop("the application has no CODE 0")
	p = address(cpu.read32(h))
	above = cpu.read32(p)
	below = cpu.read32(p + 4)
	length = cpu.read32(p + 8)
	offset = cpu.read32(p + 12)
	a5 = (top - above) & ~u32(3)
	fillBytes(a5 - below, below + above, 0)
	moveBytes(a5 + offset, p + 16, length)
	cpu.write32(currentA5At, a5)
	cpu.write32(curStackBaseAt, a5 - below)
	cpu.write16(curJtOffsetAt, offset)
	releaseResource(h)
	World(a5, jumpTable = a5 + offset, jumpTableLength = length)

# the handles of the segments _LoadSeg brought in, by number (a purged one's master pointer is 0)
pub mut segmentHandles {i64: u32} = {}

# _LoadSeg: segment n's code in a locked handle, its jump table entries turned into jumps
pub fn loadSegment(n i64) u32:
	h = getResource(codeType, n, [], false)
	if h == 0: cpu.stop("no CODE {n} for _LoadSeg")
	segmentHandles[n] = h
	setFlag(h, lockedBit, true)
	setFlag(h, purgeableBit, false)
	p = address(cpu.read32(h))
	if traceTraps: eprint("  segment {n}: handle {h:x}, code at {p:x}, {handleSize(h)} bytes")
	first = cpu.read16(p)
	count = i64(cpu.read16(p + 2))
	for i in 0..count:
		entry = world.jumpTable + first + u32(i * 8)
		if cpu.read16(entry + 4) != u32(n): continue
		offset = cpu.read16(entry)
		cpu.write16(entry, u32(n))
		cpu.write16(entry + 2, jmpWord)
		cpu.write32(entry + 4, p + 4 + offset)
	noteWritten(world.jumpTable, world.jumpTableLength)
	h

# _UnloadSeg: the segment of a routine's address made purgeable, its entries unloaded again
pub fn unloadSegment(routine u32):
	at = address(routine)
	e = world.jumpTable
	while e < world.jumpTable + world.jumpTableLength:
		if cpu.read16(e + 2) == jmpWord and address(cpu.read32(e + 4)) == at:
			n = i64(cpu.read16(e))
			h = getResource(codeType, n, [], false)
			if h == 0: return
			p = address(cpu.read32(h))
			first = cpu.read16(p)
			for i in 0..i64(cpu.read16(p + 2)):
				entry = world.jumpTable + first + u32(i * 8)
				if cpu.read16(entry + 2) != jmpWord or cpu.read16(entry) != u32(n): continue
				offset = address(cpu.read32(entry + 4)) - (p + 4)
				cpu.write16(entry, offset)
				cpu.write16(entry + 2, 0x3F3C)
				cpu.write16(entry + 4, n)
				cpu.write16(entry + 6, loadSegWord)
				noteWritten(entry, 8)
			setFlag(h, lockedBit, false)
			setFlag(h, purgeableBit, true)
			return
		e += 8

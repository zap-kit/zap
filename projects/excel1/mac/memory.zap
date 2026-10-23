# The Memory Manager of the 24-bit Mac, in the machine's memory as the ROM kept it, since programs
# read its zones and blocks themselves. A zone is a header (bkLim, purgePtr, hFstFree, zcbFree,
# gzProc, moreMast, ...) then its blocks up to the trailer at bkLim. A block is a header of 8 bytes
# (the tag in the top two bits of byte 0, 00 free, 01 nonrelocatable, 10 relocatable, and the
# size correction in its low nibble; the physical size in bytes 1-3; then a relocatable block's
# master pointer as an offset from the zone, or a nonrelocatable block's zone) and its data. A
# handle is the address of a master pointer: the data's address in its low 24 bits, the flags in
# its top byte (locked, purgeable, a resource). Free master pointers are linked from hFstFree.

import cpu

pub noErr = 0
pub memFullErr = -108
pub nilHandleErr = -109
pub memWZErr = -111
pub memPurErr = -112

zoneBkLim u32 = 0
zoneHFstFree u32 = 8
zoneZcbFree u32 = 12
zoneGzProc u32 = 16
zoneMoreMast u32 = 20
pub zoneHeapData u32 = 52
blockHeader u32 = 8
minBlock u32 = 12

pub lockedBit u32 = 0x80
pub purgeableBit u32 = 0x40
pub resourceBit u32 = 0x20

tagFree u32 = 0
tagFixed u32 = 0x40
tagRelocatable u32 = 0x80

fn rd(a u32):
	cpu.read32(a)

fn wr(a u32, v u32):
	cpu.write32(a, v)

# what follows a change of memory that may hold code (the interpreter forgets what it decoded
# there): set by the program
pub mut onCodeMoved fn(i64, i64) = (_, _): pass

pub fn noteWritten(at u32, n i64):
	moved = onCodeMoved
	moved(address(at), n)

# BlockMove: n bytes from `from` to `to`, the ranges may overlap
pub fn moveBytes(to u32, from u32, n i64):
	noteWritten(to, n)
	t = i64(address(to))
	f = i64(address(from))
	if t < f:
		for i in 0..n:
			cpu.mem[t + i] = cpu.mem[f + i]
	else:
		i = n - 1
		while i >= 0:
			cpu.mem[t + i] = cpu.mem[f + i]
			i -= 1

pub fn fillBytes(at u32, n i64, v u8):
	noteWritten(at, n)
	a = i64(address(at))
	for i in a..a + n:
		cpu.mem[i] = v

pub fn address(v u32) u32:
	v & 0xFF_FFFF

pub fn setMemErr(e i64):
	cpu.write16(memErrAt, u32.wrap(e))

pub fn theZone() u32:
	rd(theZoneAt)

fn tagOf(block u32):
	cpu.read8(block) & 0xC0

fn sizeOf(block u32):
	size = rd(block) & 0xFF_FFFF
	if size == 0: cpu.stop("a heap block of no size at {block:x}")
	size

fn setHeader(block u32, tag u32, physical u32, correction u32, link u32):
	wr(block, (tag | correction & 15) << 24 | physical)
	wr(block + 4, link)

# the logical size of the block whose data is at `data`
pub fn blockDataSize(data u32) u32:
	block = data - blockHeader
	sizeOf(block) - blockHeader - (cpu.read8(block) & 15)

fn physicalFor(size u32):
	((size + blockHeader + 1) & ~u32(1)).max(minBlock)

# Makes a zone from `start` up to `limit` with `masters` master pointers allocated at first.
pub fn initZone(start u32, limit u32, masters i64):
	for i in 0..i64(zoneHeapData) / 4:
		wr(start + u32(4 * i), 0)
	trailer = limit - minBlock
	wr(start + zoneBkLim, trailer)
	cpu.write16(start + zoneMoreMast, u32(masters))
	first = start + zoneHeapData
	setHeader(first, tagFree, trailer - first, 0, 0)
	setHeader(trailer, tagFixed, minBlock, 0, start)
	wr(start + zoneZcbFree, trailer - first)
	previous = theZone()
	wr(theZoneAt, start)
	moreMasters(start)
	wr(theZoneAt, previous)

fn freeBytes(zone u32):
	total u32 = 0
	b = zone + zoneHeapData
	limit = rd(zone + zoneBkLim)
	while b < limit:
		if tagOf(b) == tagFree: total += sizeOf(b)
		b += sizeOf(b)
	total

fn noteFree(zone u32):
	wr(zone + zoneZcbFree, freeBytes(zone))

# joins each free block with the free blocks after it
fn coalesce(zone u32):
	b = zone + zoneHeapData
	limit = rd(zone + zoneBkLim)
	while b < limit:
		if tagOf(b) == tagFree:
			size = sizeOf(b)
			while b + size < limit and tagOf(b + size) == tagFree:
				size += sizeOf(b + size)
			setHeader(b, tagFree, size, 0, 0)
		b += sizeOf(b)

# the first free block of at least `physical` bytes, 0 for none
fn firstFit(zone u32, physical i64):
	b = zone + zoneHeapData
	limit = rd(zone + zoneBkLim)
	while b < limit:
		if tagOf(b) == tagFree and sizeOf(b) >= physical: return b
		b += sizeOf(b)
	0

# the block taken from free block b: its front `physical` bytes, the rest left free
fn carve(b u32, physical u32, tag u32, correction u32, link u32):
	size = sizeOf(b)
	if size - physical >= minBlock:
		setHeader(b + physical, tagFree, size - physical, 0, 0)
		setHeader(b, tag, physical, correction, link)
	else:
		setHeader(b, tag, size, correction + (size - physical), link)

fn isMovable(zone u32, b u32):
	if tagOf(b) != tagRelocatable: return false
	mp = zone + rd(b + 4)
	cpu.read8(mp) & lockedBit == 0

# Moves the unlocked relocatable blocks down over the free space, their master pointers following.
pub fn compact(zone u32):
	coalesce(zone)
	b = zone + zoneHeapData
	limit = rd(zone + zoneBkLim)
	while b < limit:
		if tagOf(b) == tagFree:
			next = b + sizeOf(b)
			if next < limit and isMovable(zone, next):
				gap = sizeOf(b)
				moved = sizeOf(next)
				moveBytes(b, next, moved)
				mp = zone + rd(b + 4)
				wr(mp, (rd(mp) & 0xFF00_0000) | (b + blockHeader))
				setHeader(b + moved, tagFree, gap, 0, 0)
				coalesce(zone)
				b += moved
				continue
		b += sizeOf(b)
	noteFree(zone)

# frees the purgeable unlocked relocatable blocks, their master pointers emptied
pub fn purge(zone u32):
	b = zone + zoneHeapData
	limit = rd(zone + zoneBkLim)
	while b < limit:
		if tagOf(b) == tagRelocatable:
			mp = zone + rd(b + 4)
			flags = cpu.read8(mp)
			if flags & lockedBit == 0 and flags & purgeableBit != 0:
				wr(mp, rd(mp) & 0xFF00_0000)
				setHeader(b, tagFree, sizeOf(b), 0, 0)
		b += sizeOf(b)
	coalesce(zone)

# the application zone grown to its limit when the zone is it: whether it grew
fn grow(zone u32, physical u32):
	if zone != rd(applZoneAt): return false
	trailer = rd(zone + zoneBkLim)
	room = rd(applLimitAt) - minBlock
	if trailer >= room: return false
	wanted = physical.max(0x4000)
	newTrailer = (trailer + wanted).min(room) & ~u32(3)
	setHeader(trailer, tagFree, newTrailer - trailer, 0, 0)
	setHeader(newTrailer, tagFixed, minBlock, 0, zone)
	wr(zone + zoneBkLim, newTrailer)
	wr(heapEndAt, newTrailer)
	coalesce(zone)
	true

# A block of `size` bytes of the tag in the zone, compacting, growing and purging it as needed:
# its header's address, 0 when there is no room.
fn allocate(zone u32, size u32, tag u32, link u32) u32:
	physical = physicalFor(size)
	correction = physical - blockHeader - size
	coalesce(zone)
	b = firstFit(zone, physical)
	if b == 0:
		compact(zone)
		b = firstFit(zone, physical)
	while b == 0 and grow(zone, physical):
		b = firstFit(zone, physical)
	if b == 0:
		purge(zone)
		compact(zone)
		b = firstFit(zone, physical)
	if b == 0: return 0
	carve(b, physical, tag, correction, link)
	fillBytes(b + blockHeader, sizeOf(b) - blockHeader, 0)
	noteFree(zone)
	b

# MoreMasters: a nonrelocatable block of moreMast master pointers, linked into the free ones
pub fn moreMasters(zone u32) i64:
	count = cpu.read16(zone + zoneMoreMast).max(1)
	b = allocate(zone, count * 4, tagFixed, zone)
	if b == 0: return memFullErr
	data = b + blockHeader
	for i in 0..i64(count):
		at = data + u32(4 * i)
		wr(at, rd(zone + zoneHFstFree) if i == i64(count) - 1 else at + 4)
	wr(zone + zoneHFstFree, data)
	noErr

fn freeMaster(zone u32) u32:
	if rd(zone + zoneHFstFree) == 0 and moreMasters(zone) != noErr: return 0
	mp = rd(zone + zoneHFstFree)
	wr(zone + zoneHFstFree, rd(mp))
	wr(mp, 0)
	mp

# NewHandle: a relocatable block's handle, 0 when there is no room
pub fn newHandle(zone u32, size u32) u32:
	mp = freeMaster(zone)
	if mp == 0:
		setMemErr(memFullErr)
		return 0
	if size == 0:
		setMemErr(noErr)
		return mp
	b = allocate(zone, size, tagRelocatable, mp - zone)
	if b == 0:
		wr(mp, rd(zone + zoneHFstFree))
		wr(zone + zoneHFstFree, mp)
		setMemErr(memFullErr)
		return 0
	wr(mp, b + blockHeader)
	setMemErr(noErr)
	mp

pub fn newPtr(zone u32, size u32) u32:
	b = allocate(zone, size, tagFixed, zone)
	if b == 0:
		setMemErr(memFullErr)
		return 0
	setMemErr(noErr)
	b + blockHeader

# the zone a block's data lies in
pub fn zoneOf(data i64) u32:
	sys = rd(sysZoneAt)
	if data >= sys and data < rd(sys + zoneBkLim): return sys
	rd(applZoneAt)

fn freeBlock(data u32):
	block = data - blockHeader
	setHeader(block, tagFree, sizeOf(block), 0, 0)

pub fn disposePtr(p u32):
	if p == 0: return
	freeBlock(address(p))
	noteFree(zoneOf(address(p)))
	setMemErr(noErr)

# the zone a handle's master pointer lies in
pub fn handleZone(h i64) u32:
	zoneOf(h)

pub fn disposeHandle(h u32):
	if h == 0: return setMemErr(nilHandleErr)
	zone = handleZone(h)
	data = address(rd(h))
	if data != 0: freeBlock(data)
	wr(h, rd(zone + zoneHFstFree))
	wr(zone + zoneHFstFree, h)
	noteFree(zone)
	setMemErr(noErr)

pub fn handleSize(h u32) u32:
	if h == 0: return 0
	data = address(rd(h))
	if data == 0: return 0
	blockDataSize(data)

# the room after a block that is free, joined to it: whether the block now holds `physical` bytes
fn growInPlace(zone u32, block u32, physical u32, correction u32):
	coalesce(zone)
	size = sizeOf(block)
	next = block + size
	limit = rd(zone + zoneBkLim)
	room = size + (sizeOf(next) if next < limit and tagOf(next) == tagFree else 0)
	if traceTraps: eprint("  grow in place: zone {zone:x} block {block:x} size {size:x} next {next:x} limit {limit:x} room {room:x} physical {physical:x}")
	if room < physical: return false
	tag = tagOf(block)
	link = rd(block + 4)
	if room - physical >= minBlock:
		setHeader(block + physical, tagFree, room - physical, 0, 0)
		setHeader(block, tag, physical, correction, link)
	else:
		setHeader(block, tag, room, correction + room - physical, link)
	true

fn resize(zone u32, data u32, size u32):
	block = data - blockHeader
	physical = physicalFor(size)
	correction = physical - blockHeader - size
	old = blockDataSize(data)
	if growInPlace(zone, block, physical, correction):
		if size > old: fillBytes(data + old, size - old, 0)
		noteFree(zone)
		return true
	false

pub fn setHandleSize(h u32, size u32) i64:
	if h == 0: return nilHandleErr
	zone = handleZone(h)
	data = address(rd(h))
	if data == 0:
		b = allocate(zone, size, tagRelocatable, h - zone)
		if b == 0: return memFullErr
		wr(h, (rd(h) & 0xFF00_0000) | (b + blockHeader))
		return noErr
	if resize(zone, data, size): return noErr
	if cpu.read8(h) & lockedBit != 0: return memFullErr
	old = blockDataSize(data)
	# moved: the old block locked while the new one is found, so it is not moved under the copy
	flags = rd(h) & 0xFF00_0000
	wr(h, rd(h) | lockedBit << 24)
	b = allocate(zone, size, tagRelocatable, h - zone)
	if b == 0:
		wr(h, rd(h) & 0xFF_FFFF | flags)
		return memFullErr
	from = address(rd(h))
	moveBytes(b + blockHeader, from, old.min(size))
	freeBlock(from)
	wr(h, flags | (b + blockHeader))
	noteFree(zone)
	noErr

pub fn setPtrSize(p u32, size u32) i64:
	if resize(zoneOf(address(p)), address(p), size): return noErr
	memFullErr

# the handle whose master pointer points at the data
pub fn recoverHandle(data u32) u32:
	block = address(data) - blockHeader
	zoneOf(address(data)) + rd(block + 4)

# the largest block the zone could give after compacting and purging
pub fn maxBlock(zone u32) u32:
	compact(zone)
	best u32 = 0
	b = zone + zoneHeapData
	limit = rd(zone + zoneBkLim)
	while b < limit:
		if tagOf(b) == tagFree: best = best.max(sizeOf(b))
		b += sizeOf(b)
	if zone == rd(applZoneAt):
		best = best.max(rd(applLimitAt) - limit)
	best - blockHeader if best > blockHeader else 0

pub fn freeMemory(zone u32) u32:
	freeBytes(zone)

# the application zone grown to its limit
pub fn maxApplZone():
	zone = rd(applZoneAt)
	while grow(zone, 0x4000):
		pass
	noteFree(zone)

# EmptyHandle: the block freed, the master pointer kept (empty) with its flags
pub fn emptyHandle(h u32):
	data = address(rd(h))
	if data == 0: return
	freeBlock(data)
	wr(h, rd(h) & 0xFF00_0000)
	noteFree(handleZone(h))

pub fn reallocHandle(h u32, size u32) i64:
	emptyHandle(h)
	setHandleSize(h, size)

pub fn setFlag(h u32, bit u32, on bool):
	v = rd(h)
	wr(h, v | bit << 24 if on else v & ~(bit << 24))

# the zone's blocks walked from its first to its trailer: a description of the first fault, or ""
pub fn zoneFault(zone u32) str:
	b = zone + zoneHeapData
	limit = rd(zone + zoneBkLim)
	while b < limit:
		size = rd(b) & 0xFF_FFFF
		if size < minBlock or size & 1 != 0: return "block {b:x} of size {size:x}"
		b += size
	if b != limit: return "the last block ends at {b:x}, past the trailer at {limit:x}"
	""

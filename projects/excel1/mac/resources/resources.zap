# The Resource Manager: each open resource file's map in a handle, as the file holds it (a copy of
# the header, then the link to the next map, the file's reference number, the attributes, the
# type list's and the name list's offsets), its references' handle fields filled as resources
# load; the maps chained from TopMapHndl to the System's, searched from CurMap down.

import cpu

pub resNotFound = -192
pub resFNotFound = -193
mapLink u32 = 16
mapRefNum u32 = 20
mapTypes u32 = 24
mapNames u32 = 26
pub resSysHeap = 0x40
pub resPurgeable = 0x20
pub resLocked = 0x10

pub fn setResErr(e i64):
	cpu.write16(resErrAt, u32.wrap(e))

fn deref(h u32):
	address(cpu.read32(h))

# Opens the resource fork of a prepared file: its reference number, none when it has no map.
# the map's bytes in an open fork, empty when it has none
fn mapOfFork(refNum i64):
	fork = openForks.get(refNum) ?? return []
	if fork.bytes.len < 16: return []
	mapAt = i64(fork.bytes.u32be(4))
	mapLength = i64(fork.bytes.u32be(12))
	out = fork.bytes[mapAt..mapAt + mapLength].copy()
	# in memory the map begins with a copy of the fork's header
	for i in 0..16:
		out[i] = fork.bytes[i]
	out

pub fn openResFile(volume str, name str) i64?:
	refNum = try openFork(volume, name, true)
	mapBytes = mapOfFork(refNum)
	if mapBytes.isEmpty: return none
	mapLength = mapBytes.len
	isSystem = name == "System"
	h = newHandle(cpu.read32(sysZoneAt) if isSystem else theZone(), u32(mapLength))
	if h == 0: return none
	at = i64(deref(h))
	for i in 0..mapLength:
		cpu.mem[at + i] = mapBytes[i]
	cpu.write32(u32(at) + mapLink, cpu.read32(topMapHndlAt))
	cpu.write16(u32(at) + mapRefNum, u32(refNum))
	clearHandles(at)
	cpu.write32(topMapHndlAt, h)
	cpu.write16(curMapAt, u32(refNum))
	if isSystem:
		cpu.write32(sysMapHndlAt, h)
		cpu.write16(sysMapAt, u32(refNum))
	setResErr(0)
	refNum

# every reference's handle field cleared: nothing of a file just opened is in memory
fn clearHandles(p u32):
	typesAt, types = typeEntries(p)
	for t in 0..types:
		entry = typesAt + 2 + u32(t * 8)
		refs = typesAt + cpu.read16(entry + 6)
		for r in 0..=i64(cpu.read16(entry + 4)):
			cpu.write32(refs + u32(r * 12) + 8, 0)

pub fn curMap() i64:
	cpu.read16(curMapAt)

# the map handle of an open file, 0 when none is open with that number
pub fn mapOf(refNum i64) u32:
	h = cpu.read32(topMapHndlAt)
	while h != 0:
		if cpu.read16(deref(h) + mapRefNum) == refNum: return h
		h = cpu.read32(deref(h) + mapLink)
	0

# A reference found: the map's handle and the reference's offset in the map.
pub type ResRef:
	map u32
	at u32

fn typeEntries(p u32):
	typesAt = p + cpu.read16(p + mapTypes)
	(typesAt, (i64(cpu.read16(typesAt)) + 1) & 0xFFFF)

# the reference of the type and the ID in one map, matching the name instead when it is given
fn findInMap(h u32, kind i64, id i64, name u8[]) ResRef?:
	p = deref(h)
	typesAt, types = typeEntries(p)
	namesAt = p + cpu.read16(p + mapNames)
	for t in 0..types:
		entry = typesAt + 2 + u32(t * 8)
		if cpu.read32(entry) != kind: continue
		refs = typesAt + cpu.read16(entry + 6)
		for r in 0..=i64(cpu.read16(entry + 4)):
			at = refs + u32(r * 12)
			if name.isEmpty:
				if i16.wrap(i64(cpu.read16(at))) == id: return ResRef(map = h, at = at - p)
			else:
				offset = cpu.read16(at + 2)
				if offset != 0xFFFF and pascalEquals(namesAt + offset, name):
					return ResRef(map = h, at = at - p)
	none

fn pascalEquals(at u32, name u8[]):
	n = i64(cpu.read8(at))
	if n != name.len: return false
	for i in 0..n:
		if cpu.read8(at + 1 + u32(i)) != name[i]: return false
	true

# the reference of a resource, searched from the current map down (or in it alone)
pub fn findResource(kind i64, id i64, name u8[], isOneMap bool) ResRef?:
	h = mapOf(curMap())
	while h != 0:
		found = findInMap(h, kind, id, name)
		if found != none or isOneMap: return found
		h = cpu.read32(deref(h) + mapLink)
	none

# the address of a reference's fields now (its map may have moved)
pub fn refAt(r ResRef) u32:
	deref(r.map) + r.at

pub fn refNumOf(r ResRef) i64:
	cpu.read16(deref(r.map) + mapRefNum)

# the bytes of a resource in its file
fn resourceBytes(r ResRef):
	offset = i64(cpu.read32(r.refAt() + 4)) & 0xFF_FFFF
	fork = openForks.get(r.refNumOf()) ?? return []
	dataAt = i64(fork.bytes.u32be(0))
	at = dataAt + offset
	length = i64(fork.bytes.u32be(at))
	fork.bytes[at + 4..at + 4 + length].copy()

# The resource's handle, its data read in when ResLoad is on and it is not in memory.
pub fn loadRef(r ResRef, isLoaded bool) u32:
	h = cpu.read32(r.refAt() + 8)
	if h != 0 and (deref(h) != 0 or not isLoaded): return h
	attributes = cpu.read8(r.refAt() + 4)
	zone = cpu.read32(sysZoneAt) if attributes & u32(resSysHeap) != 0 else theZone()
	bytes = r.resourceBytes() if isLoaded else []
	handle = h
	if handle == 0:
		handle = newHandle(zone, u32(bytes.len))
		if handle == 0: return 0
		cpu.write32(r.refAt() + 8, handle)
	elif setHandleSize(handle, u32(bytes.len)) != noErr:
		return 0
	at = i64(deref(handle))
	noteWritten(at, bytes.len)
	for i, byte in bytes:
		cpu.mem[at + i] = byte
	setFlag(handle, resourceBit, true)
	setFlag(handle, purgeableBit, attributes & u32(resPurgeable) != 0)
	setFlag(handle, lockedBit, attributes & u32(resLocked) != 0)
	handle

pub fn isResLoad() bool:
	cpu.read8(resLoadAt) != 0

# GetResource and its kin: the handle, 0 with ResError set when there is none
pub fn getResource(kind i64, id i64, name u8[], isOneMap bool) u32:
	match findResource(kind, id, name, isOneMap):
		r:
			setResErr(0)
			r.loadRef(isResLoad())
		none:
			setResErr(resNotFound)
			0

# the reference whose handle field holds h, searched in every map
pub fn refOfHandle(h i64) ResRef?:
	m = cpu.read32(topMapHndlAt)
	while m != 0:
		p = deref(m)
		typesAt, types = typeEntries(p)
		for t in 0..types:
			entry = typesAt + 2 + u32(t * 8)
			refs = typesAt + cpu.read16(entry + 6)
			for r in 0..=i64(cpu.read16(entry + 4)):
				at = refs + u32(r * 12)
				if cpu.read32(at + 8) == h: return ResRef(map = m, at = at - p)
		m = cpu.read32(p + mapLink)
	none

pub fn releaseResource(h u32):
	match refOfHandle(h):
		r:
			cpu.write32(r.refAt() + 8, 0)
			disposeHandle(h)
			setResErr(0)
		none: setResErr(resNotFound)

pub fn detachResource(h u32):
	match refOfHandle(h):
		r:
			cpu.write32(r.refAt() + 8, 0)
			setFlag(h, resourceBit, false)
			setResErr(0)
		none: setResErr(resNotFound)

# a resource's size in its file, -1 when the handle is none's
pub fn sizeOfResource(h i64) i64:
	r = refOfHandle(h) ?? return -1
	r.resourceBytes().len

# the resources of a type in the maps from the current one down (or in it alone), in order
pub fn resourcesOfType(kind i64, isOneMap bool) ResRef[]:
	out = []
	h = mapOf(curMap())
	while h != 0:
		p = deref(h)
		typesAt, types = typeEntries(p)
		for t in 0..types:
			entry = typesAt + 2 + u32(t * 8)
			if cpu.read32(entry) != kind: continue
			refs = typesAt + cpu.read16(entry + 6)
			for r in 0..=i64(cpu.read16(entry + 4)):
				out.push(ResRef(map = h, at = refs + u32(r * 12) - p))
		if isOneMap: break
		h = cpu.read32(p + mapLink)
	out

pub fn homeResFile(h i64) i64:
	r = refOfHandle(h) ?? return -1
	r.refNumOf()

# a resource's name, empty when it has none
pub fn resourceName(r ResRef) u8[]:
	p = deref(r.map)
	offset = cpu.read16(p + r.at + 2)
	if offset == 0xFFFF: return []
	at = p + cpu.read16(p + mapNames) + offset
	(0..i64(cpu.read8(at))).map(u8(cpu.read8(at + 1 + u32(it))))

# A resource fork: a header (the data's and the map's offsets and lengths), the data (each
# resource a 4-byte length and its bytes) and the map (after a copy of the header and 8 bytes the
# Resource Manager uses, the attributes, the type list's and the name list's offsets; the type
# list a count less one and per type its OSType, its count less one and its reference list's
# offset; a reference the ID, the name's offset or -1, the attributes and a 3-byte data offset).

pub type Resource:
	kind str   # the OSType
	id i64
	name u8[]
	attributes u8
	bytes u8[]

# The fork's resources in the map's order, or why it is not one.
pub fn readResources(f u8[]) Resource[] ? str:
	if f.len < 16: return "no resource map"
	dataAt = i64(f.u32be(0))
	mapAt = i64(f.u32be(4))
	if mapAt + 30 > f.len or dataAt > f.len: return "a resource map past the fork's end"
	typesAt = mapAt + f.u16be(mapAt + 24)
	namesAt = mapAt + f.u16be(mapAt + 26)
	types = i64(f.u16be(typesAt)) + 1
	out = []
	for t in 0..types:
		entry = typesAt + 2 + t * 8
		kind = osType(f, entry)
		refsAt = typesAt + f.u16be(entry + 6)
		for r in 0..=i64(f.u16be(entry + 4)):
			entryAt = refsAt + r * 12
			nameOffset = f.u16be(entryAt + 2)
			at = dataAt + (i64(f.u32be(entryAt + 4)) & 0xFF_FFFF)
			if at + 4 > f.len: return "a resource past the fork's end"
			length = i64(f.u32be(at))
			if at + 4 + length > f.len: return "a resource past the fork's end"
			out.push(
				Resource(
					kind = kind.copy(),
					id = f.i16be(entryAt),
					name = [] if nameOffset == 0xFFFF else pascalBytes(f, namesAt + nameOffset),
					attributes = f[entryAt + 4],
					bytes = f[at + 4..at + 4 + length].copy()
				)
			)
	out

# the bytes of the Pascal string (a length byte, then the bytes) at `at`
pub fn pascalBytes(d u8[], at i64) u8[]:
	d[at + 1..at + 1 + i64(d[at])].copy()

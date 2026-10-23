# EA's BIG archives of version 3 ("EB"), as Skate 3 keeps its worlds, characters and front end:
# a 48-byte header (the entry count, flags, the alignment shift of the offsets, the sizes of the
# index and of the names), the entries (offset >> shift, stored size, unpacked size, and a
# fourth word when flag 1 is set), a compression byte per entry, then the names (each a dir
# index and the file's name in a fixed-size record) and the dirs. An entry is stored as it
# is (0), RefPack-compressed (1), or as a "chunkref" of chunks each stored, RefPack-compressed or
# deflated (2, 3, 4). The archive is read in place, inside the disc image: only the index is
# loaded, and an entry when it is asked for.

import deflate
import fs
import xbox

pub type BigEntry:
	path str   # dirs split by '/'
	offset i64   # from the archive's start
	stored i64
	size i64   # unpacked
	compression i64

	pub fn pathOf() ref str:
		path

pub type Big:
	name str
	file fs.File   # the disc image, opened for the archive
	base i64   # where the archive starts in the image
	entries xbox.PathList<BigEntry>

# The BIG archive at `path` of the disc, its index read, or why it cannot be.
pub fn openBig(disc xbox.Disc, path str) Big ? str:
	f = disc.files.find(path) ?? return "{path} is not on the disc"
	header = disc.readDiscAt(f.offset, 48) ?? return "{path} is cut short"
	if header.u16be(0) != 0x4542: return "{path} is not an EA BIG archive"
	if header.u16be(2) != 3: return "{path}: BIG version {header.u16be(2)} is not read (3 is)"
	indexSize = i64(header.u32be(12))
	namesSize = i64(header.u32be(16))
	meta = disc.readDiscAt(f.offset, indexSize + namesSize) ??
		return "{path}: its index is cut short"
	count = i64(meta.u32be(4))
	flags = meta.u16be(8)
	shift = i64(meta[10])
	nameRecord = i64(meta[20])
	dirRecord = i64(meta[21])
	entrySize = 20 if (flags & 1) != 0 else 16
	compressionStart = 48 + (entrySize * count).alignUp(16)
	namesStart = indexSize
	dirsStart = namesStart + (nameRecord * count).alignUp(16)
	dirs = []
	at = dirsStart
	while at + dirRecord <= indexSize + namesSize:
		dirs.push(meta.cStringAt(at, dirRecord))
		at += dirRecord
	entries = xbox.PathList<BigEntry>()
	for i in 0..count:
		e = 48 + i * entrySize
		stored = meta.u32be(e + 4)
		unpacked = meta.u32be(e + 8)
		record = namesStart + i * nameRecord
		dirIndex = meta.u16be(record)
		name = meta.cStringAt(record + 2, nameRecord - 2)
		dir = dirs[dirIndex].replace("\\", "/") if dirIndex < dirs.len else ""
		full = name if dir == "" or dir == "." else "{dir}/{name}"
		entries.add(BigEntry(
			path = full,
			offset = i64(meta.u32be(e)) << shift,
			stored = unpacked if stored == 0 else stored,
			size = stored if unpacked == 0 else unpacked,
			compression = meta[compressionStart + i]))
	file = fs.open(disc.path) ?? return "cannot open {disc.path}"
	Big(name = path.copy(), file, base = f.offset, entries)

# the unpacked bytes of an entry, or why they cannot be read
pub fn readBigEntry(b Big, e BigEntry) u8[] ? str:
	packed = b.file.readAt(b.base + e.offset, e.stored) ??
		return "{e.path} is cut short in {b.name}"
	if e.compression == 0: return packed
	if e.compression == 1: return unpackRefPack(packed, e.size)
	if e.compression >= 2 and e.compression <= 4: return unpackChunks(packed, e.size)
	"{e.path}: compression {e.compression} is not read"

# the unpacked bytes of the entry at this path, or why not
pub fn readBigFile(b Big, path str) u8[] ? str:
	e = b.entries.find(path) ?? return "{path} is not in {b.name}"
	b.readBigEntry(e)

# A "chunkref" entry: its header (the magic, version 2, the total size, the size of a chunk,
# their count, their alignment), then each chunk's packed size and method before its bytes.
fn unpackChunks(d u8[], size i64) u8[] ? str:
	if not d.startsWith("chunkref") or d.u32be(8) != 2: return "not a chunkref entry"
	total = i64(d.u32be(12))
	chunk = d.u32be(16)
	count = i64(d.u32be(20))
	alignment = d.u32be(24)
	if total != size or chunk == 0 or alignment == 0: return "a chunkref entry of the wrong size"
	out u8[] = []
	out.reserve(total)
	cursor = 28
	loop count:
		payload = (cursor + 8).alignUp(alignment)
		packedSize = i64(d.u32be(payload - 8))
		method = d.u32be(payload - 4)
		expected = i64(chunk).min(total - out.len)
		bytes = d[payload..payload + packedSize]
		if method == 0 or method == 4:
			out.extend(bytes)
		elif method == 2:
			out.extend(try unpackRefPack(bytes, expected))
		elif method == 3:
			out.extend(try deflate.inflateZlib(bytes))
		else:
			return "chunkref method {method} is not read"
		cursor = payload + packedSize
	if out.len != total: return "a chunkref entry gave {out.len} of {total} bytes"
	out

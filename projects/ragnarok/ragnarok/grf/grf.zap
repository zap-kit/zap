# Gravity's GRF archives, read where they lie: a 46-byte header, then at its offset a
# zlib-compressed table of entries (a NUL-ended name in CP949, the packed, aligned and real
# sizes, flags, the data's offset after the header), each entry's data zlib-compressed and
# sometimes DES-scrambled (des.zap). Version 0x200 is the standard one; 0x300 ("Event Horizon",
# Ragnarok Online LATAM's data.grf) has a 64-bit table offset, four bytes before the table and a
# 64-bit offset in each entry. The archive is read in place: only the table and the entries asked
# for are loaded.

import fs
import deflate
import ragnarok.des

headerSize = 46
flagFile = 1
flagMixed = 2   # DES on the first 20 blocks and then periodically
flagHeader = 4   # DES on the first 20 blocks only

type GrfEntry:
	offset i64
	packed i64
	aligned i64
	size i64
	flags i64

pub type Grf:
	path str
	file fs.File
	entries {str: GrfEntry}

# The key an entry is found by: its name's bytes with ASCII folded to lower case and every run
# of slashes or backslashes made one backslash (the archives hold "data\\sprite\\..." too).
pub fn grfKey(name u8[]) str:
	out u8[] = []
	for b in name:
		if b == '/' or b == '\\':
			if out.isEmpty or out[len - 1] != '\\':
				out.push('\\')
		elif b >= 'A' and b <= 'Z':
			out.push(b + 32)
		else:
			out.push(b)
	str(move out)

# the archive at path with its table read, or why it cannot be
pub fn openGrf(move path str) Grf ? str:
	f = fs.open(path) ?? return "cannot open {path}"
	head = f.readAt(0, headerSize) ?? return "{path} is too short for a GRF"
	version = head.u32le(42)
	table = 0
	trailer = 17
	if version == 0x300:
		table = head.u32le(30) + (i64(head.u32le(34)) << 32) + headerSize + 4
		trailer = 21
	elif version == 0x200:
		table = head.u32le(30) + headerSize
	else:
		return "{path}: GRF version {version} is not read (0x200 and 0x300 are)"
	sizes = f.readAt(table, 8) ?? return "{path}: the file table is missing"
	packed = f.readAt(table + 8, sizes.u32le(0)) ??
		return "{path}: the file table is cut short"
	list = try deflate.inflateZlib(packed)
	if list.len != sizes.u32le(4): return "{path}: the file table does not inflate"
	entries {str: GrfEntry} = {}
	at = 0
	while at < list.len:
		end = at
		while end < list.len and list[end] != 0:
			end += 1
		key = grfKey(list[at..end])
		p = end + 1
		if p + trailer > list.len: break
		flags = i64(list[p + 12])
		offset = i64(list.u32le(p + 13))
		if trailer == 21:
			offset += i64(list.u32le(p + 17)) << 32
		if (flags & flagFile) != 0:
			# a later copy of a name replaces an earlier one, as extracting in order would
			entries[key] = GrfEntry(
				offset = offset + headerSize,
				packed = list.u32le(p),
				aligned = list.u32le(p + 4),
				size = list.u32le(p + 8),
				flags
			)
		at = p + trailer
	Grf(path, file = f, entries)

pub fn grfHas(g Grf, key str) bool:
	key in g.entries

# the bytes of the entry with this key (grfKey), unscrambled and inflated, or why not
pub fn grfRead(g Grf, key str) u8[] ? str:
	e = g.entries.get(key) ?? return "not in {g.path}"
	raw = g.file.readAt(e.offset, e.aligned) ?? return "cut short in {g.path}"
	if (e.flags & flagMixed) != 0:
		des.decodeMixed(raw, e.packed)
	elif (e.flags & flagHeader) != 0:
		des.decodeHeader(raw)
	if e.packed == e.size:
		raw.truncate(e.size)   # stored as it is
		return raw
	out = try deflate.inflateZlib(raw)
	if out.len != e.size: return "does not inflate ({out.len} of {e.size} bytes)"
	out

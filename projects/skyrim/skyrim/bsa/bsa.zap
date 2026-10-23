# Bethesda's BSA archives, version 105 (Skyrim Special and Anniversary Edition), read where they
# lie: a 36-byte header (the "BSA\0" magic, the version, the folder records' offset, the archive
# flags, the folder and file counts, the lengths of the folder and file names, the file flags),
# 24-byte folder records (hash, file count, offset), then per folder its name (a length byte and
# a NUL-ended string, when the flags have folder names) and 16-byte file records (hash, size with
# bit 30 toggling the archive's compression, offset), then the file names (NUL-ended strings, in
# the order of the records). A compressed file is an optional embedded name (a length byte and
# the string), its unpacked size and an LZ4 frame. Only the table and the files asked for are loaded.

import fs
import lz4

headerSize = 36
bsaMagic = 0x0041_5342   # "BSA\0"
groupRecord = 24
fileRecord = 16
flagGroupNames = 1
flagFileNames = 2
flagCompressed = 4
flagEmbeddedNames = 0x100
toggleCompression = 0x4000_0000

# the records, read where they lie (T.fromBytesAt)
type Header:
	magic n32
	version n32
	tableAt u32
	flags u32
	groups u32
	files u32
	groupNames u32
	fileNames u32
	fileFlags u32

type GroupRecord:
	hash u64
	count u32
	pad u32
	offset u64

type FileRecord:
	hash u64
	size u32
	offset u32

type BsaEntry:
	offset i64
	size i64
	compressed bool

pub type Bsa:
	path str
	file fs.File
	embeddedNames bool
	entries {str: BsaEntry}

# The key a file is found by: the folder and file name's bytes with ASCII folded to lower case and
# every run of slashes or backslashes made one slash ("meshes/clutter/x.nif").
pub fn bsaKey(name u8[]) str:
	out u8[] = []
	for b in name:
		if b == '/' or b == 92:
			if out.isEmpty or out[len - 1] != '/':
				out.push('/')
		elif b >= 'A' and b <= 'Z':
			out.push(b + 32)
		else:
			out.push(b)
	str(move out)

# the position after the NUL-ended string at `at`
fn endOfString(t u8[], at i64):
	end = at
	while end < t.len and t[end] != 0:
		end += 1
	end

# The file counts of the folders, in the order of their records, from the table's start.
fn groupCounts(t u8[], groups i64):
	counts = []
	for i in 0..groups:
		if GroupRecord.fromBytesAt(t, i * groupRecord) is g: counts.push(i64(g.count))
	counts

# the archive at path with its table read, or why it cannot be
pub fn openBsa(move path str) Bsa ? str:
	f = fs.open(path) ?? return "cannot open {path}"
	head = f.readAt(0, headerSize) ?? return "{path} is too short for a BSA"
	h = Header.fromBytesAt(head, 0) ?? return "{path} is too short for a BSA"
	if h.magic != bsaMagic: return "{path} is not a BSA"
	if h.version != 105: return "{path}: BSA version {h.version} is not read (105 is)"
	flags = i64(h.flags)
	groups = i64(h.groups)
	files = i64(h.files)
	groupNames = i64(h.groupNames)
	fileNames = i64(h.fileNames)
	tableSize = groups * groupRecord + files * fileRecord
	if (flags & flagGroupNames) != 0: tableSize += groupNames + groups
	if (flags & flagFileNames) != 0: tableSize += fileNames
	t = f.readAt(h.tableAt, tableSize) ?? return "{path}: the file table is cut short"
	entries {str: BsaEntry} = {}
	counts = groupCounts(t, groups)
	records = groups * groupRecord   # the group names and file records follow the group records
	names = tableSize - ((fileNames) if (flags & flagFileNames) != 0 else 0)
	archiveCompressed = (flags & flagCompressed) != 0
	for count in counts:
		groupKey = ""
		if (flags & flagGroupNames) != 0:
			n = i64(t[records])
			groupKey = bsaKey(t[records + 1..records + n])   # without its NUL
			records += 1 + n
		loop count:
			record = FileRecord.fromBytesAt(t, records) ??
				return "{path}: the file table is cut short"
			size = i64(record.size)
			nameKey = ""
			if names < tableSize:
				end = endOfString(t, names)
				nameKey = bsaKey(t[names..end])
				names = end + 1
			key = "{groupKey}/{nameKey}" if not groupKey.isEmpty else nameKey
			entries[key] = BsaEntry(
				offset = record.offset,
				size = size & (toggleCompression - 1),
				compressed = archiveCompressed != ((size & toggleCompression) != 0)
			)
			records += fileRecord
	Bsa(path, file = f, embeddedNames = (flags & flagEmbeddedNames) != 0, entries)

pub fn bsaHas(b Bsa, key str) bool:
	key in b.entries

# how many files the archive holds, and how many of them are compressed
pub fn bsaCount(b Bsa) i64:
	b.entries.len

pub fn bsaCompressedCount(b Bsa) i64:
	n = 0
	for key in b.entries.keys():
		if b.entries[key].compressed: n += 1
	n

# the keys of the files in the archive
pub fn bsaKeys(b Bsa) str[]:
	b.entries.keys()

# the bytes of the file with this key (bsaKey), unpacked, or why not
pub fn bsaRead(b Bsa, key str) u8[] ? str:
	e = b.entries.get(key) ?? return "not in {b.path}"
	raw = b.file.readAt(e.offset, e.size) ?? return "cut short in {b.path}"
	at = 0
	if b.embeddedNames and not raw.isEmpty: at = 1 + i64(raw[0])
	if not e.compressed: return raw[at..].copy()
	if raw.len < at + 4: return "{key}: cut short in {b.path}"
	size = i64(raw.u32le(at))
	lz4.decodeFrame(raw[at + 4..], size)

test "the real Skyrim archive opens and gives a mesh back (skipped without the install)":
	path = "projects/skyrim/assets/game/Data/Skyrim - Meshes0.bsa"
	if not fs.exists(path): return
	b = openBsa(path) ?? fail("cannot open")
	expect b.bsaCount() > 1000
	key = "meshes/clutter/barrel01.nif"
	expect b.bsaHas(key)
	nif = b.bsaRead(key) ?? fail("cannot read")
	expect nif.startsWith("Gamebryo File Format")

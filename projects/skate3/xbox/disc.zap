# An Xbox 360 game disc image (.iso), read where it lies: the XDVDFS file system ("GDFX") of its
# game partition. The partition starts at a fixed place that depends on the disc's generation
# (XGD1, XGD2, XGD3, or 0 for an image rebuilt without the video partition); 32 sectors into it
# the volume descriptor ("MICROSOFT*XBOX*MEDIA") gives the root directory. A directory is a
# binary tree of entries (left and right subtree offsets in 4-byte units, the first sector and
# the size, attributes, the name), sectors of 2048 bytes counted from the partition's start. All
# of it is little-endian. Nothing is extracted: a file is read straight from the image.

import fs

sectorSize = 2048
# where the game partition starts on each kind of disc: a rebuilt image, XGD2, XGD3, XGD1
partitionStarts = [0, 0xFD9_0000, 0x208_0000, 0x1830_0000]
volumeMagic = "MICROSOFT*XBOX*MEDIA"
attrDirectory = 0x10
# where the user's disc image is looked for when none is given
pub discDir = "projects/skate3/disc"

# a file of the disc: its path from the root (dirs split by '/'), where its bytes are in the
# image and how many
pub type DiscFile:
	path str
	offset i64
	size i64

	pub fn pathOf() ref str:
		path

# what a PathList keeps: a record with a path (dirs split by '/')
pub bound Pathed:
	fn pathOf(self Pathed) ref str

# Records found by their path in any case, in the order added.
pub type PathList<T Pathed>:
	items T[] = []
	byPath {str: i64} = {}   # lower-case path -> index in items

	pub mut fn add(move item T):
		byPath[item.pathOf().lower()] = items.len
		items.push(item)

	# the record at this path (any case), or none
	pub fn find(path str) ref T?:
		i = byPath.get(path.lower()) ?? return none
		items[i]

pub type Disc:
	path str
	file fs.File
	partition i64   # the byte where the game partition starts
	files PathList<DiscFile>   # every file, in the order the tree is walked

# The disc image at path with its file tree read, or why it cannot be.
pub fn openDisc(path str) Disc ? str:
	f = fs.open(path) ?? return "cannot open {path}"
	partition = -1
	root = 0
	rootSize = 0
	for start in partitionStarts:
		if f.readAt(start + 32 * sectorSize, sectorSize) is v:
			if v.startsWith(volumeMagic) and v.matchesAt(0x7EC, volumeMagic):
				partition = start
				root = v.u32le(20)
				rootSize = v.u32le(24)
				break
	if partition < 0: return "{path} is not an Xbox disc image (no XDVDFS volume found)"
	d = Disc(path = path.copy(), file = f, partition, files = PathList<DiscFile>())
	_ = try d.walkDirectory(root, rootSize, "")
	d

# The entries of the directory table at `sector` (`size` bytes) added to the disc's files, the
# dirs walked in turn; `prefix` is the dir's path with its trailing '/'.
fn walkDirectory(mut d Disc, sector i64, size i64, prefix str) bool ? str:
	if size == 0: return true
	table = d.file.readAt(d.partition + sector * sectorSize, size) ??
		return "a directory of {d.path} is cut short"
	# the tree in order: left subtree, the entry, right subtree
	stack = [0]
	seen {i64: bool} = {}
	while stack.pop() is at:
		if at + 14 > table.len or at in seen or table.u16le(at) == 0xFFFF: continue
		seen[at] = true
		left = i64(table.u16le(at)) * 4
		right = i64(table.u16le(at + 2)) * 4
		start = i64(table.u32le(at + 4))
		length = table.u32le(at + 8)
		attributes = i64(table[at + 12])
		nameLength = i64(table[at + 13])
		if at + 14 + nameLength > table.len:
			return "a directory entry of {d.path} runs past its table"
		name = []
		name.extend(table[at + 14..at + 14 + nameLength])
		full = prefix + str(move name)
		if right != 0:
			stack.push(right)
		if (attributes & attrDirectory) != 0:
			_ = try d.walkDirectory(start, length, "{full}/")
		else:
			d.files.add(
				DiscFile(path = full, offset = d.partition + start * sectorSize, size = length)
			)
		if left != 0:
			stack.push(left)
	true

# the bytes of the file at this path, or why they cannot be read
pub fn readDiscFile(d Disc, path str) u8[] ? str:
	f = d.files.find(path) ?? return "{path} is not on the disc"
	d.file.readAt(f.offset, f.size) ?? return "{path} is cut short in {d.path}"

# n bytes of the image from byte `at`
pub fn readDiscAt(d Disc, at i64, n i64) u8[] ? fs.Error:
	d.file.readAt(at, n)

# the first .iso in the dir, or none
pub fn findImage(dir str) str?:
	for name in (fs.list(dir) ?? []):
		if name.lower().endsWith(".iso"): return "{dir}/{name}"
	none

# The user's disc image opened: the one given (--iso), else the first .iso in projects/skate3/disc/; or
# why it cannot be.
pub fn openUserDisc(given str?) Disc ? str:
	image = given ?? findImage(discDir) ??
		return "no disc image: put your own Skate 3 (Xbox 360) .iso in {discDir}/ or pass --iso <file>"
	openDisc(image)

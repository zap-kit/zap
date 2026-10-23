# The Macintosh File System of the first Macs (MFS): the volume's information at block 2 (its
# signature D2D7, the directory's first block and length, the allocation blocks' size and first
# block, then a map of 12 bits per allocation block: 0 free, 1 a file's last, else the next), and
# a flat directory of file entries (flags, Finder information, the forks' first allocation block,
# lengths, dates and a Pascal-string name), none crossing a 512-byte block.

pub type MacFile:
	name u8[]   # in Mac Roman
	fileType str
	creator str
	finderInfo u8[]   # the 16 bytes of flUsrWds: type, creator, flags, location, folder
	attributes u8
	number u32   # the file's number on the volume
	dataStart i64   # each fork's first allocation block
	resourceStart i64
	locked bool
	created u32   # seconds since 1904
	modified u32
	dataFork u8[]
	resourceFork u8[]

pub type MfsVolume:
	name u8[]
	files MacFile[]

# the four characters of an OSType as text, a byte past ASCII as '?'
pub fn osType(d u8[], at i64) str:
	out = []
	for i in at..at + 4:
		c = d[i]
		out.push(c if c >= 32 and c < 127 else '?')
	str(out)

type Layout:
	allocationStart i64   # the first allocation block's byte in the volume
	allocationSize i64
	blockMap i64[]   # by allocation block number - 2

fn fork(v u8[], l Layout, first i64, length i64):
	out = []
	b = first
	steps = 0
	while b >= 2 and out.len < length and steps < l.blockMap.len:
		at = l.allocationStart + (b - 2) * l.allocationSize
		out.extend(v[at..at + l.allocationSize])
		b = l.blockMap[b - 2]
		steps += 1
	if out.len > length: out.truncate(length)
	out

# The volume's name and files, or why its blocks hold no MFS volume.
pub fn readMfs(v u8[]) MfsVolume ? str:
	m = 1024
	if v.u16be(m) != 0xD2D7: return "no MFS volume"
	dirStart = i64(v.u16be(m + 14))
	dirBlocks = i64(v.u16be(m + 16))
	count = i64(v.u16be(m + 18))
	blockMap = []
	for i in 0..count:
		at = m + 64 + i * 12 / 8
		word = i64(v.u16be(at))
		blockMap.push(word >> 4 if i % 2 == 0 else word & 0xFFF)
	layout = Layout(
		allocationStart = i64(v.u16be(m + 28)) * 512,
		allocationSize = v.u32be(m + 20),
		blockMap
	)
	files = []
	for b in dirStart..dirStart + dirBlocks:
		at = b * 512
		end = at + 512
		while at + 51 < end and v[at] & 0x80 != 0:
			files.push(
				MacFile(
					name = pascalBytes(v, at + 50),
					fileType = osType(v, at + 2),
					creator = osType(v, at + 6),
					finderInfo = v[at + 2..at + 18].copy(),
					attributes = v[at],
					number = v.u32be(at + 18),
					dataStart = v.u16be(at + 22),
					resourceStart = v.u16be(at + 32),
					locked = v[at] & 1 != 0,
					created = v.u32be(at + 42),
					modified = v.u32be(at + 46),
					dataFork = fork(v, layout, v.u16be(at + 22), v.u32be(at + 24)),
					resourceFork = fork(v, layout, v.u16be(at + 32), v.u32be(at + 34))
				)
			)
			at += 51 + i64(v[at + 50])
			at += at & 1
	MfsVolume(name = pascalBytes(v, m + 36), files)

# a name the file system takes: letters, digits, spaces and . - _ kept, any other byte as _
pub fn fileName(name u8[]) str:
	out = []
	for c in name:
		isKept = c.isAlpha() or c.isDigit() or c == ' ' or c == '.' or c == '-' or c == '_'
		out.push(c if isKept and c < 128 else '_')
	str(out)

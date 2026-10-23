# The Macintosh's 6-and-2 GCR sectors on a 400 KB disk: 80 tracks in five zones of 16 (12, 11,
# 10, 9 and 8 sectors), each sector an address field (D5 AA 96: the track's low six bits, the
# sector, the side and the track's high bits, the format, their checksum) and a data field (D5 AA
# AD, the sector, then 699 nibbles holding 524 bytes, 12 of tags and 512 of data, as three running
# checksums mix them, and those checksums in 4 more nibbles).

gcrCodes = [
	u8(0x96),
	0x97,
	0x9A,
	0x9B,
	0x9D,
	0x9E,
	0x9F,
	0xA6,
	0xA7,
	0xAB,
	0xAC,
	0xAD,
	0xAE,
	0xAF,
	0xB2,
	0xB3,
	0xB4,
	0xB5,
	0xB6,
	0xB7,
	0xB9,
	0xBA,
	0xBB,
	0xBC,
	0xBD,
	0xBE,
	0xBF,
	0xCB,
	0xCD,
	0xCE,
	0xCF,
	0xD3,
	0xD6,
	0xD7,
	0xD9,
	0xDA,
	0xDB,
	0xDC,
	0xDD,
	0xDE,
	0xDF,
	0xE5,
	0xE6,
	0xE7,
	0xE9,
	0xEA,
	0xEB,
	0xEC,
	0xED,
	0xEE,
	0xEF,
	0xF2,
	0xF3,
	0xF4,
	0xF5,
	0xF6,
	0xF7,
	0xF9,
	0xFA,
	0xFB,
	0xFC,
	0xFD,
	0xFE,
	0xFF
]

pub sectorBytes = 512
pub tagBytes = 12
pub dataNibbles = 699
groups = 175   # the data field's groups of four nibbles (three bytes), the last of three

# each disk byte's six bits, -1 for a byte no code writes
pub fn gcrValues() i64[]:
	out = fill(256, -1)
	for i, code in gcrCodes:
		out[code] = i
	out

# the sectors of a track of zone z (z = track / 16)
pub fn sectorsOfTrack(track i64) i64:
	12 - track / 16

# The disk's blocks of 512 bytes in order (track by track, sector by sector), and the blocks no
# turn of the track read whole (a damaged or protected sector, its bytes left zero).
pub type Volume:
	bytes u8[]
	unread i64[]

# The 524 bytes of a data field from its 699 nibbles' values, or none when its checksums disagree.
pub fn decodeDataField(v i64[]) u8[]?:
	b1 = zeros(groups)
	b2 = zeros(groups)
	b3 = zeros(groups)
	p = 0
	for i in 0..groups:
		w4 = v[p]
		b1[i] = v[p + 1] & 0x3F | w4 << 2 & 0xC0
		b2[i] = v[p + 2] & 0x3F | w4 << 4 & 0xC0
		p += 3
		if i != groups - 1:
			b3[i] = v[p] & 0x3F | w4 << 6 & 0xC0
			p += 1
	out = []
	c1 = 0
	c2 = 0
	c3 = 0
	k = 0
	while true:
		c1 = (c1 & 0xFF) << 1
		if c1 & 0x100 != 0: c1 += 1
		x = (b1[k] ^ c1) & 0xFF
		c3 += x
		if c1 & 0x100 != 0:
			c3 += 1
			c1 &= 0xFF
		out.push(u8(x))
		x = (b2[k] ^ c3) & 0xFF
		c2 += x
		if c3 > 0xFF:
			c2 += 1
			c3 &= 0xFF
		out.push(u8(x))
		if out.len == sectorBytes + tagBytes: break
		x = (b3[k] ^ c2) & 0xFF
		c1 += x
		if c2 > 0xFF:
			c1 += 1
			c2 &= 0xFF
		out.push(u8(x))
		k += 1
	c4 = (c1 & 0xC0) >> 6 | (c2 & 0xC0) >> 4 | (c3 & 0xC0) >> 2
	if v[p] != c4 & 0x3F or v[p + 1] != c3 & 0x3F or v[p + 2] != c2 & 0x3F or v[p + 3] != c1 & 0x3F:
		return none
	out

fn isMark(n u8[], at i64, third u8):
	n[at] == 0xD5 and n[at + 1] == 0xAA and n[at + 2] == third

# the values of count nibbles from at, none when one is no code
fn valuesAt(n u8[], at i64, count i64, table i64[]) i64[]?:
	out = []
	for i in at..at + count:
		x = table[n[i]]
		if x < 0: return none
		out.push(x)
	out

# The data of each sector of the track's nibbles that reads whole, by sector number (empty
# where none did).
pub fn trackSectors(n u8[], track i64) u8[,]:
	table = gcrValues()
	count = sectorsOfTrack(track)
	found u8[,] = []
	loop count:
		found.push([])
	reach = 64   # nibbles from an address field's end to its data field's mark, at most
	for i in 0..n.len - 8 - reach - 4 - dataNibbles - 4:
		if not isMark(n, i, 0x96): continue
		head = valuesAt(n, i + 3, 5, table) ?? continue
		if head[0] ^ head[1] ^ head[2] ^ head[3] != head[4]: continue
		number = head[0] | (head[2] & 1) << 6
		sector = head[1]
		if number != track or sector >= count or not found[sector].isEmpty: continue
		j = i + 8
		while j < i + 8 + reach and not isMark(n, j, 0xAD):
			j += 1
		if j == i + 8 + reach: continue
		values = valuesAt(n, j + 4, dataNibbles + 4, table) ?? continue
		data = decodeDataField(values) ?? continue
		found[sector] = data[tagBytes..].copy()
	found

# The volume of a disk's tracks: the blocks of every track in order.
pub fn readVolume(m Moof) Volume:
	bytes = []
	unread = []
	for t, track in m.tracks:
		sectors = trackSectors(nibbles(track), t)
		for data in sectors:
			if data.isEmpty:
				unread.push(bytes.len / sectorBytes)
				bytes.extend(fill(sectorBytes, u8(0)))
			else:
				bytes.extend(data)
	Volume(bytes, unread)

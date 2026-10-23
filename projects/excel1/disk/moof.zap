# Applesauce's MOOF images of 3.5-inch Macintosh disks: a header, then chunks (INFO, TMAP, TRKS,
# FLUX, META). TMAP gives each track and side the index of its entry in TRKS; an entry is the
# track's first 512-byte block in the file, its block count and its length in bits, the bits
# kept as the drive read them, the highest bit of each byte first.

pub type Track:
	bits u8[]
	count i64   # the bits of one turn of the disk

pub type Moof:
	tracks Track[]   # by track number, side 0 (a single-sided 400 KB disk)

fn chunkAt(d u8[], name str) i64?:
	at = 12
	while at + 8 <= d.len:
		size = i64(d.u32le(at + 4))
		if d.matchesAt(at, name): return at + 8
		at += 8 + size
	none

# The tracks of side 0 of an image, or why it is none.
pub fn readMoof(d u8[]) Moof ? str:
	if not d.startsWith("MOOF"): return "not a MOOF image"
	tmap = chunkAt(d, "TMAP") ?? return "no TMAP chunk"
	trks = chunkAt(d, "TRKS") ?? return "no TRKS chunk"
	tracks = []
	for t in 0..80:
		index = i64(d[tmap + t * 2])
		if index == 255: return "track {t} is not in the image"
		entry = trks + index * 8
		start = i64(d.u16le(entry)) * 512
		count = i64(d.u32le(entry + 4))
		if start + (count + 7) / 8 > d.len: return "track {t} runs past the image"
		tracks.push(Track(bits = d[start..start + (count + 7) / 8].copy(), count))
	Moof(tracks)

# The tracks as projects/excel1/prepare.zap writes them for the emulated drive: each track's bit count (4
# bytes, big-endian), then its bits.
pub fn tracksBytes(m Moof) u8[]:
	out = []
	for t in m.tracks:
		out.pushU32be(u32(t.count))
		out.extend(t.bits)
	out

pub fn readTracks(b u8[]) Track[]:
	out = []
	at = 0
	while at + 4 <= b.len:
		count = i64(b.u32be(at))
		end = at + 4 + (count + 7) / 8
		out.push(Track(bits = b[at + 4..end].copy(), count))
		at = end
	out

# The track's nibbles (bytes whose top bit is set, as the disk controller assembles them from the
# bits, leading zeros skipped), read over two turns so that a sector crossing the index is whole.
pub fn nibbles(t Track) u8[]:
	out = []
	v = 0
	for i in 0..t.count * 2:
		k = i % t.count
		bit = i64(t.bits[k >> 3]) >> (7 - (k & 7)) & 1
		v = (v << 1 | bit) & 255
		if v >= 128:
			out.push(u8(v))
			v = 0
	out

# Ogg pages and the packets their segments make (RFC 3533): the container of a Vorbis stream.
# Everything here reads through checked cursors, so a damaged file ends the packets and never
# stops the program.

# where reading stands: in the page whose segments are being taken
pub type Pages:
	at i64 = 0   # the next page's header
	lacing u8[] = []   # the lacing values of the page being read
	next i64 = 0   # the lacing value to take next
	data i64 = 0   # where the next segment's bytes start
	flags i64 = 0   # the page's type: 1 continues a packet, 2 begins the stream, 4 ends it
	granule i64 = -1   # the page's granule position, -1 when it has none
	endsPacket i64 = -1   # the last lacing value of the page that ends a packet (-1 when none)

# a packet and what the page it ends says of it
pub type Packet:
	bytes u8[]
	granule i64 = -1   # the sample position after it, when its page says (-1 else)
	last bool = false   # its page ends the stream

# the page that begins at `at` read, its lacing table in place; false when there is none
fn readPage(mut p Pages, bytes ref u8[]):
	use noStops
	start = count(p.at)
	if not bytes.matchesAt(start, "OggS"): return false
	r = Reader(d = bytes, at = start + 4)
	version = r.u8()
	flags = r.u8()
	granule = r.i64()
	r.u32()   # the stream's serial number
	r.u32()   # the page's sequence number
	r.u32()   # its checksum
	segments = r.u8()
	lacing = r.bytes(segments)
	if r.short or version != 0: return false
	size = 0
	for lace in lacing:
		size += lace
	ends = -1
	if granule != -1:
		for k in 0..lacing.len:
			if lacing[k] != 255:
				ends = k
	p.lacing = lacing
	p.next = 0
	p.data = r.at
	p.flags = flags
	p.granule = granule
	p.at = count(r.at) + count(size)
	p.endsPacket = ends
	true

# the next packet: its bytes gathered from the segments (across pages when a lacing value of 255
# says it goes on); none at the end of the file. A packet left off by a page that does not
# continue it is given as far as it went.
pub fn nextPacket(mut p Pages, bytes ref u8[]) Packet?:
	use noStops
	out = []
	began = false
	dropping = false
	granule = -1
	last = false
	done = false
	while not done:
		if p.next >= p.lacing.len:
			if not p.readPage(bytes): break
			continued = (p.flags & 1) != 0
			if continued and not began:
				dropping = true   # the end of a packet whose start was not read
			elif began and not continued:
				break
		next = count(p.next)
		if next >= p.lacing.len: break
		lace = p.lacing[next]
		seg = Reader(d = bytes, at = count(p.data))
		piece = seg.bytes(lace)
		if seg.short: break
		if not dropping:
			out.extend(piece)
			began = true
		p.data = seg.at
		p.next = next + 1
		if lace < 255:
			if dropping:
				dropping = false
			else:
				ends = p.endsPacket == next
				granule = p.granule if ends else -1
				last = ends and (p.flags & 4) != 0
				done = true
	if not began: return none
	Packet(bytes = out, granule, last)

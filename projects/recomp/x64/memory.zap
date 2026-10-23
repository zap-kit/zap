# The emulated address space: pages of 4 KB made on first touch, those of the image filled from
# its file (image.zap), those of a region the caller opened (the stack, scratch memory) zeroed. An
# access anywhere else is a fault: the read gives 0, the write is dropped, and `fault` says where,
# for the machine to stop at the instruction that made it.

pageBits = 12
pageSize = 4096

pub type Region:
	start u64
	size n64

pub type Memory:
	image Image
	regions Region[] = []
	slots {u64: i64} = {}   # page number -> its slot in store
	store u8[] = []
	lastPage u64 = 0xFFFF_FFFF_FFFF_FFFF
	lastSlot i64 = 0
	fault str = ""

	# opens [start, start + size) as memory of zeros
	fn open(start u64, size n64):
		regions.push(Region(start, size))

	# the offset in store of the page holding `at`, made on first touch; -1 for an address nothing maps
	fn slotOf(at u64):
		page = at >> pageBits
		if page == lastPage: return lastSlot
		slot = slots.get(page) ?? makePage(page)
		if slot >= 0:
			lastPage = page
			lastSlot = slot
		slot

	fn makePage(page u64):
		at = page << pageBits
		mapped = image.holds(at)
		if not mapped:
			for r in regions:
				if at - r.start < u64(r.size) or r.start - at < pageSize: mapped = true
		if not mapped: return -1
		slot = store.len
		if image.holds(at): store.extend(image.mappedBytes(at, pageSize))
		else: store.extend(zeros(pageSize))
		slots[page] = slot
		slot

	# the n bytes (1 to 8) at `at`, little-endian
	mut fn read(at u64, n i64) u64:
		offset = i64(at & (pageSize - 1))
		if offset + n <= pageSize:
			slot = slotOf(at)
			if slot < 0: return faulted("read", at)
			p = slot + offset
			return match n:
				1: store[p]
				2: store.u16le(p)
				4: store.u32le(p)
				_: store.u64le(p)
		v u64 = 0
		for k in 0..n:
			v |= read(at + u64(k), 1) << u64(8 * k)
		v

	# v's low n bytes (1 to 8) at `at`
	fn write(at u64, n i64, v u64):
		offset = i64(at & (pageSize - 1))
		if offset + n <= pageSize:
			slot = slotOf(at)
			if slot < 0:
				faulted("write", at)
				return
			p = slot + offset
			match n:
				1: store[p] = u8.wrap(v)
				2: store.setU16le(p, u16.wrap(v))
				4: store.setU32le(p, u32.wrap(v))
				_: store.setU64le(p, v)
			return
		for k in 0..n:
			write(at + u64(k), 1, v >> u64(8 * k))

	fn faulted(what str, at u64) u64:
		if fault.isEmpty: fault = "{what} of unmapped memory at 0x{at:x}"
		0

	# the n bytes at `at`
	mut fn bytes(at u64, n i64):
		out = []
		for k in 0..n:
			out.push(u8.wrap(read(at + u64(k), 1)))
		out

	# the bytes written from `at` on
	mut fn put(at u64, data u8[]):
		for k in 0..data.len:
			write(at + u64(k), 1, data[k])

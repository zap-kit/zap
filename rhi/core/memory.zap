# GPU memory as both backends manage it: blocks of 4 MB (a larger resource gets a block of its
# own) taken from the driver per kind of memory, cut into ranges by first fit; a freed range
# joins its neighbours. A block is the backend's (a VkDeviceMemory, an ID3D12Heap, a buffer);
# a host-visible one stays mapped, its address where the CPU writes.

# 4 MB; a larger resource gets a block of its own
pub blockSize = 4_194_304

pub type Range:
	offset i64
	size i64

# memory taken from the driver
pub type Block:
	memory i64   # the backend's handle
	typeIndex i64   # the kind of memory, the backend's number
	size i64
	mapped i64   # the CPU's address of its start (0 when not host-visible)
	free Range[]   # the free ranges, by offset

pub type Memory:
	typeFlags i64[]   # per memory type: its property flags (Vulkan's)
	blocks Block[]
	peakDevice i64 = 0   # the most bytes of device memory (blocks not host-visible) held at once
	peakHost i64 = 0   # the same for host-visible blocks

# a range of a block: where a resource's memory is
pub type Allocation:
	block i64
	offset i64
	size i64
	memory i64
	mapped i64   # the CPU's address of the range (0 when not host-visible)

# a range in a block of the kind already there, or none
pub fn rangeIn(mut m Memory, typeIndex i64, size i64, alignment i64) Allocation?:
	for b in 0..m.blocks.len:
		if m.blocks[b].typeIndex == typeIndex:
			if m.blocks[b].takeRange(size, alignment) is offset:
				return m.allocationAt(b, offset, size)
	none

# a range at the start of a new block (memory: the backend's, of the size given)
pub fn rangeInNew(
	mut m Memory,
	memory i64,
	typeIndex i64,
	blockBytes i64,
	mapped i64,
	size i64
) Allocation:
	m.blocks.push(
		Block(
			memory,
			typeIndex,
			size = blockBytes,
			mapped,
			free = [Range(offset = 0, size = blockBytes)]
		)
	)
	b = m.blocks.len - 1
	m.peakDevice = m.peakDevice.max(m.held(false))
	m.peakHost = m.peakHost.max(m.held(true))
	match m.blocks[b].takeRange(size, 1):
		offset: m.allocationAt(b, offset, size)
		none: fail("rhi: a new block has no room")

# the bytes taken from the driver now, in host-visible blocks or in device ones
pub fn held(m Memory, hostVisible bool) i64:
	total = 0
	for b in m.blocks:
		if (b.mapped != 0) == hostVisible: total += b.size
	total

fn allocationAt(m Memory, b i64, offset i64, size i64):
	block = m.blocks[b]
	Allocation(
		block = b,
		offset,
		size,
		memory = block.memory,
		mapped = 0 if block.mapped == 0 else block.mapped + offset
	)

# the first free range that holds `size` bytes at the alignment, cut out: its offset
pub fn takeRange(mut b Block, size i64, alignment i64) i64?:
	for i in 0..b.free.len:
		r = b.free[i]
		start = r.offset.alignUp(alignment.max(1))
		end = r.offset + r.size
		if start + size <= end:
			# what is left before and after the range stays free
			b.free.remove(i)
			if start + size < end:
				b.free.insert(i, Range(offset = start + size, size = end - start - size))
			if start > r.offset:
				b.free.insert(i, Range(..r, size = start - r.offset))
			return start
	none

# A range given back, merged with the free ones beside it. True when that leaves free the whole
# of a block larger than the usual (one resource's own): the backend gives its memory back
# (dropBlock).
pub fn release(mut m Memory, block i64, offset i64, size i64) bool:
	b = mut ref m.blocks[block]
	i = 0
	while i < b.free.len and b.free[i].offset < offset:
		i += 1
	b.free.insert(i, Range(offset, size))
	if i + 1 < b.free.len and b.free[i].offset + b.free[i].size == b.free[i + 1].offset:
		b.free[i].size += b.free[i + 1].size
		b.free.remove(i + 1)
	if i > 0 and b.free[i - 1].offset + b.free[i - 1].size == b.free[i].offset:
		b.free[i - 1].size += b.free[i].size
		b.free.remove(i)
	b.size > blockSize and b.free.len == 1 and b.free[0].size == b.size

# a block whose memory the backend gave back: no range is taken from it again
pub fn dropBlock(mut m Memory, block i64):
	b = mut ref m.blocks[block]
	b.typeIndex = -1
	b.size = 0
	b.free = []

# ---------- a frame's ring ----------

# Where n bytes go in a ring of `size` bytes `used` up to here, at the alignment (16 at least):
# the offset, or -1 when they do not fit.
pub fn ringPlace(used i64, size i64, n i64, alignment i64) i64:
	at = used.alignUp(alignment.max(16))
	-1 if at + n > size else at

# the size of the ring that replaces a full one: twice its size, room for twice n at least
pub fn ringGrown(size i64, n i64) i64:
	(size * 2).max((n * 2).alignUp(65_536))

# The size of a frame slot's ring of `size` bytes when its last frame placed `placed` (`least`
# at least): kept while it holds that and is not over twice what it needs, else a quarter more
# than that.
pub fn ringFitting(size i64, placed i64, least i64) i64:
	needed = (placed + placed / 4).alignUp(65_536).max(least)
	size if size >= placed and size <= needed * 2 else needed

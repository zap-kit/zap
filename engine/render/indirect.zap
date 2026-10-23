# Draws for GPU-driven rendering: a model's vertices drawn through indices of its own (an
# IndexBuffer), a run of them at a time (drawIndexed: from an index, each index plus an offset,
# from an instance), or many runs in one call from a buffer of draw commands the GPU reads
# (drawIndirect), counted by the CPU or by the GPU (the counter's word, which a pass of the GPU may
# write). Instances come from a model of the program's instance struct (`copies`), read from each
# draw's first instance. Direct3D 12 numbers a draw's instances from 0 whatever its first
# instance (Vulkan from the first): a stage reads per-instance values from the instance stream.

import rhi
import rhi.core

# indices into a model's vertices (u32), on the GPU
pub type IndexBuffer:
	buffer GpuBuffer
	count i64

# a draw of indices: `count` from `firstIndex`, each plus `vertexOffset`, `instances` of them from
# `firstInstance` (Vulkan's VkDrawIndexedIndirectCommand, Direct3D's D3D12_DRAW_INDEXED_ARGUMENTS)
pub extern type DrawCommand:
	count u32
	instances u32 = 1
	firstIndex u32 = 0
	vertexOffset i32 = 0
	firstInstance u32 = 0

# draw commands on the GPU, and a counter (a u32 the GPU reads: how many of them to draw)
pub type DrawCommands:
	buffer GpuBuffer
	counter i64   # -1 none yet
	count i64

	# the counter freed where the commands are dropped (their buffer frees itself)
	mut fn drop():
		if counter >= 0:
			gpu.destroyBuffer(counter)

# u32 indices, or their bytes as a prepared file holds them
pub fn newIndexBuffer<T Copy>(indices T[]) IndexBuffer:
	ib = IndexBuffer(buffer = GpuBuffer(), count = 0)
	ib.fillIndexBuffer(indices)
	ib

# the indices replaced (u32s, or their bytes), a buffer of their size made when the old one is too
# small
pub fn fillIndexBuffer<T Copy>(mut ib IndexBuffer, indices T[]):
	ib.buffer.fillBuffer(indices, core.bufIndex)
	ib.count = indices.byteSize / 4

# the counter starts at their number
pub fn newDrawCommands(commands DrawCommand[]) DrawCommands:
	c = DrawCommands(buffer = GpuBuffer(), counter = -1, count = 0)
	c.fillDrawCommands(commands)
	c

# the commands replaced, and the counter set to their number
pub fn fillDrawCommands(mut c DrawCommands, commands DrawCommand[]):
	c.buffer.fillBuffer(commands, core.bufIndirect)
	if c.counter < 0:
		c.counter = gpu.newBuffer(16, core.bufIndirect, false)
	gpu.writeBufferWords(c.counter, 0, [u32(commands.len)])
	c.count = commands.len

# the counter set to n (what a pass of the GPU that culls the commands would write): a counted
# drawIndirect draws that many
pub fn setDrawCount(c DrawCommands, n i64):
	gpu.writeBufferWords(c.counter, 0, [u32(n)])

# `count` of the indices from `firstIndex` drawn by a program, each plus `vertexOffset` (a vertex of
# the model), `instances` copies from `firstInstance` (of `copies`, a model of the program's
# instance struct, when it reads one)
pub fn drawIndexed(
	r Renderer,
	p Program,
	m Model,
	ib IndexBuffer,
	count i64,
	firstIndex i64 = 0,
	vertexOffset i64 = 0,
	instances i64 = 1,
	firstInstance i64 = 0,
	copies ref Model? = none
):
	if count <= 0 or instances <= 0 or m.count == 0 or ib.count == 0: return
	range = DrawRange(
		first = firstIndex,
		vertexOffset,
		firstInstance,
		indirect = -1,
		indirectOffset = 0,
		drawCount = 1,
		countBuffer = -1
	)
	layout = p.streamsOf(m, copies)
	drawRanged(
		r,
		p,
		layout,
		streamBuffers,
		streamOffsets,
		gpu.bufferHandle(ib.buffer.id),
		count,
		instances,
		false,
		range
	)

# The commands from `first` (`count` of them, all by default) drawn by a program in one call, the
# GPU reading them; `counted`: as many of those as the counter says. Their instances come from
# `copies` when the program reads an instance struct.
pub fn drawIndirect(
	r Renderer,
	p Program,
	m Model,
	ib IndexBuffer,
	commands DrawCommands,
	first i64 = 0,
	count i64 = -1,
	counted bool = false,
	copies ref Model? = none
):
	n = commands.count - first if count < 0 else count.min(commands.count - first)
	if n <= 0 or m.count == 0 or ib.count == 0: return
	range = DrawRange(
		first = 0,
		vertexOffset = 0,
		firstInstance = 0,
		indirect = commands.buffer.id,
		indirectOffset = first * core.indexCommandBytes,
		drawCount = n,
		countBuffer = commands.counter if counted else -1)
	layout = p.streamsOf(m, copies)
	drawRanged(
		r,
		p,
		layout,
		streamBuffers,
		streamOffsets,
		gpu.bufferHandle(ib.buffer.id),
		0,
		1,
		false,
		range
	)

# the streams of a draw of the model (and its copies' instance stream): its vertex layout
fn streamsOf(p Program, m Model, copies ref Model?):
	streams(gpu.bufferHandle(m.buffer.id), 0)
	match copies:
		c:
			if c.stride != p.instanceStride:
				fail("instances of {c.stride} bytes drawn by a program whose instance struct is {p.instanceStride} bytes")
			addStream(gpu.bufferHandle(c.buffer.id), 0)
			p.vertexLayoutFor(m.stride, true)
		none: p.vertexLayoutFor(m.stride, false)

# Models: vertices on the GPU, of the struct a program's vertex stage takes (the same struct
# the CPU fills: its fields are the vertex's attributes), drawn as triangles; a list of them goes
# to the GPU as its bytes. A model made empty (`newDynamicModel`) is filled again every frame,
# its buffer kept while they fit. A model's copies are drawn in one call: each copy an instance
# of the struct the program takes after the vertex, or only its number.

import rhi
import rhi.core

# vertices on the GPU
pub type Model:
	buffer GpuBuffer   # its vertices
	count i64   # vertices
	stride i64   # a vertex's bytes

# A model of the vertices, kept as they are. With `stride`, a vertex is that many bytes of the
# list (bytes already laid out as the program reads them, the bytes of a list of its vertex
# struct): data prepared ahead of time loads without going through the struct.
pub fn newModel<V Copy>(vertices V[], stride i64 = 0) Model:
	m = newDynamicModel()
	fillModel(m, vertices)
	if stride > 0:
		m.count = vertices.byteSize / stride
		m.stride = stride
	m

# a model with no vertices yet, filled by fillModel
pub fn newDynamicModel() Model:
	Model(buffer = GpuBuffer(), count = 0, stride = 0)

# the vertices of a model replaced (a buffer of their size made when the old one is too small)
pub fn fillModel<V Copy>(mut m Model, vertices V[]):
	fillBuffer(m.buffer, vertices, core.bufVertex)
	m.count = vertices.len
	m.stride = vertices.byteSize / vertices.len if vertices.len > 0 else m.stride

# the model's triangles drawn by a program (its parameters set by the caller)
pub fn drawModel(r Renderer, p Program, m Model):
	if m.count > 0:
		streams(gpu.bufferHandle(m.buffer.id), 0)
		drawWith(
			r,
			p,
			p.vertexLayoutFor(m.stride, false),
			streamBuffers,
			streamOffsets,
			0,
			m.count,
			1,
			false
		)

# `count` of the model's vertices from vertex `first` drawn by a program: a run of the batches
# laid one after the other in it, one draw
pub fn drawModelRange(r Renderer, p Program, m Model, first i64, count i64):
	if count > 0 and first >= 0 and first + count <= m.count:
		streams(gpu.bufferHandle(m.buffer.id), first * m.stride)
		drawWith(
			r,
			p,
			p.vertexLayoutFor(m.stride, false),
			streamBuffers,
			streamOffsets,
			0,
			count,
			1,
			false
		)

# the model drawn `copies` times in one call, each copy told apart by its number (the vertex
# stage's instance, an i32)
pub fn drawCopies(r Renderer, p Program, m Model, copies i64):
	if m.count > 0 and copies > 0:
		streams(gpu.bufferHandle(m.buffer.id), 0)
		drawWith(
			r,
			p,
			p.vertexLayoutFor(m.stride, false),
			streamBuffers,
			streamOffsets,
			0,
			m.count,
			copies,
			false
		)

# the model drawn once for each of `instances` (values of the struct the program's vertex stage
# takes after the vertex)
pub fn drawInstances<I Copy>(r Renderer, p Program, m Model, instances I[]):
	if instances.len == 0 or m.count == 0: return
	stride = instances.byteSize / instances.len
	if stride != p.instanceStride:
		fail("instances of {stride} bytes drawn by a program whose instance struct is {p.instanceStride} bytes")
	handle, offset = frameData(instances)
	streams(rhi.bufferHandle(gpu, m.buffer.id), 0)
	addStream(handle, offset)
	drawWith(
		r,
		p,
		vertexLayoutFor(p, m.stride, true),
		streamBuffers,
		streamOffsets,
		0,
		m.count,
		instances.len,
		false
	)

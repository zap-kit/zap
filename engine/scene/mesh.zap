# Meshes for 3D worlds: a model drawn as quads, four vertices each made two triangles through
# one index buffer every quad mesh shares (a voxel's face is a quad), or as triangles or lines.
# Their vertices are of the struct the program's vertex stage takes (a voxel's corner fits in
# one u32 the shader unpacks). Their textures are often layers of a texture array (one image
# per layer, all of one size, mipmapped), so a world of many kinds of surface is drawn by one
# mesh in one call.

import rhi
import rhi.core
import image

# how a mesh's vertices are drawn: quads of four vertices (0 1 2, 0 2 3), triangles, or lines
pub type MeshMode:
	Quads
	Triangles
	Lines

pub type Mesh:
	model Model
	mode MeshMode

# the layers of a texture array as a shader's parameters read them: a handle, made by the
# GpuTextureArray that owns it, valid while that owner lives
pub type TextureArray:
	id i64
	size i64   # each layer's width and height
	layers i64

# a texture array on the GPU, destroyed where it is dropped
pub type GpuTextureArray:
	id i64 = -1   # the RHI's texture, -1 none
	size i64 = 0
	layers i64 = 0

	# the handle shaders read it by
	pub fn textureArray() TextureArray:
		TextureArray(id, size, layers)

	# the draws put off that may read it drawn first
	mut fn drop():
		if id >= 0:
			drawQueued()
			gpu.destroyTexture(id)

# the index buffer every quad mesh draws through, and the quads it holds indices for
mut quadIndices = -1
mut quadIndexCount = 0

# ---------- texture arrays ----------

# A texture array of the images, one layer each, in their order; all of one size. Sampled as
# `sampling` says (pixel art by default: sharp up close, mipmapped far away, repeating).
pub fn newTextureArray(images image.Image[], sampling Sampling = pixelArt) GpuTextureArray:
	if images.isEmpty:
		fail("a texture array needs an image")
	w = images[0].width
	h = images[0].height
	id = makeTexture(w, h, images.len, core.fmtRgba8, 1, true, sampling, (texture i64):
		for i, img in images:
			if img.width != w or img.height != h:
				fail("the layers of a texture array are {w}x{h}, layer {i} is {img.width}x{img.height}")
			gpu.writeTexture(texture, i, img.cells.bytes())
	)
	GpuTextureArray(id, size = w, layers = images.len)

# ---------- meshes ----------

# a mesh of the vertices, drawn as quads, triangles or lines
pub fn newMesh<V Copy>(vertices V[], mode MeshMode = .Quads) Mesh:
	m = Mesh(model = newDynamicModel(), mode = mode)
	setMeshVertices(m, vertices)
	m

# the mesh's vertices replaced (a buffer of their size made when the old one is too small)
pub fn setMeshVertices<V Copy>(mut m Mesh, vertices V[]):
	fillModel(m.model, vertices)
	if m.mode == .Quads:
		quadIndexBuffer(m.model.count / 4)

# The shared index buffer, holding indices for at least `quads` quads (made again, larger,
# when a mesh needs more).
fn quadIndexBuffer(quads i64):
	if quads <= quadIndexCount: return
	n = quads.max(quadIndexCount * 2).max(16_384)
	indices u32[] = []
	indices.reserve(n * 6)
	for q in 0..n:
		b = u32(q * 4)
		for k in [0, 1, 2, 0, 2, 3]:
			indices.push(b + u32(k))
	if quadIndices >= 0:
		drawQueued()
		gpu.destroyBuffer(quadIndices)
	quadIndices = gpu.newBuffer(indices.len * 4, core.bufIndex, false)
	gpu.writeBufferWords(quadIndices, 0, indices)
	quadIndexCount = n

# The mesh drawn by a program (its parameters, textures among them, set by the caller); the
# depth test, culling and blending are as the caller left them.
pub fn drawMesh(r Renderer, p Program, m Mesh):
	model = m.model
	if model.count == 0: return
	layout = p.vertexLayoutFor(model.stride, false)
	streams(gpu.bufferHandle(model.buffer.id), 0)
	if m.mode == .Quads:
		drawWith(
			r,
			p,
			layout,
			streamBuffers,
			streamOffsets,
			gpu.bufferHandle(quadIndices),
			model.count / 4 * 6,
			1,
			false
		)
	else:
		r.drawWith(p, layout, streamBuffers, streamOffsets, 0, model.count, 1, m.mode == .Lines)

# ---------- normals ----------

# the unit normal of the triangle a b c, its front the side it winds counter-clockwise on
pub fn faceNormal(a Vec3, b Vec3, c Vec3) Vec3:
	(b - a).cross(c - a).normalized()

# One normal per vertex, smooth across the triangles (three indices each) that share it: the sum
# of their normals weighted by their areas, made unit; a vertex no triangle with area touches
# gets +y.
pub fn vertexNormals(positions Vec3[], indices i64[]) Vec3[]:
	sums = fill(positions.len, Vec3(0.0, 0.0, 0.0))
	t = 0
	while t + 2 < indices.len:
		a, b, c = indices[t], indices[t + 1], indices[t + 2]
		# the cross product's length is twice the area: the weight comes with it
		n = (positions[b] - positions[a]).cross(positions[c] - positions[a])
		sums[a] += n
		sums[b] += n
		sums[c] += n
		t += 3
	sums.map(.normalized() if .length() > 0.000001 else Vec3(0.0, 1.0, 0.0))

# One normal per corner of each triangle (three indices each; triangle k in smoothing group
# groups[k]), smooth across the triangles of one group that share the corner's vertex and sharp
# between groups: the mean of their unit normals (each triangle counts once, whatever its size, as
# Ragnarok Online's models are lit); a corner whose mean vanishes gets its own triangle's normal.
pub fn groupNormals(positions Vec3[], indices i64[], groups i64[]) Vec3[]:
	triangles = indices.len / 3
	faces = (0..triangles).map(k:
		faceNormal(
			positions[indices[k * 3]],
			positions[indices[k * 3 + 1]],
			positions[indices[k * 3 + 2]]
		)
	)
	sums {(i64, i64): Vec3} = {}
	for k in 0..triangles:
		for corner in 0..3:
			key = groups[k], indices[k * 3 + corner]
			sums[key] = (sums.get(key) ?? Vec3(0.0, 0.0, 0.0)) + faces[k]
	out = []
	for k in 0..triangles:
		for corner in 0..3:
			n = sums.get((groups[k], indices[k * 3 + corner])) ?? faces[k]
			out.push(n.normalized() if n.length() > 0.000001 else faces[k])
	out

# One tangent per vertex for a normal map: the way the texture's u runs over the triangles (three
# indices each) that share it, summed (Lengyel's method) and made square to the vertex's normal; w
# is the sign of the way v runs against normal x tangent. A vertex whose uvs run nowhere gets a
# tangent square to its normal.
pub fn vertexTangents(positions Vec3[], normals Vec3[], uvs Vec2[], indices i64[]) Vec4[]:
	us = fill(positions.len, Vec3(0.0, 0.0, 0.0))
	vs = fill(positions.len, Vec3(0.0, 0.0, 0.0))
	t = 0
	while t + 2 < indices.len:
		a, b, c = indices[t], indices[t + 1], indices[t + 2]
		t += 3
		e1 = positions[b] - positions[a]
		e2 = positions[c] - positions[a]
		d1 = uvs[b] - uvs[a]
		d2 = uvs[c] - uvs[a]
		det = d1.x * d2.y - d2.x * d1.y
		if det.abs() < 1.0e-12: continue
		u = (e1 * d2.y - e2 * d1.y) / det
		v = (e2 * d1.x - e1 * d2.x) / det
		us[a] += u
		us[b] += u
		us[c] += u
		vs[a] += v
		vs[b] += v
		vs[c] += v
	out = []
	for i, n in normals:
		u = us[i] - n * (n @ us[i])
		if u.length() < 1.0e-6:
			u = (Vec3(1.0, 0.0, 0.0) if n.x.abs() < 0.9 else Vec3(0.0, 1.0, 0.0)).cross(n)
		w f32 = -1.0 if n.cross(u) @ vs[i] < 0.0 else 1.0
		out.push(u.normalized().withW(w))
	out

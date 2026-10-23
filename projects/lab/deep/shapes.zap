# The meshes the scenes are made of, built in code: each vertex holds its position, its normal
# and its texture place (u, v, 0) in the engine's three vector attributes.

import deep.shaders

# a sphere of radius 1 about the origin: `rings` bands from pole to pole, `segments` around
pub fn sphere(rings i64, segments i64) shaders.MeshVertex[]:
	out = []
	for i in 0..rings:
		for j in 0..segments:
			a = spherePoint(i, j, rings, segments)
			b = spherePoint(i + 1, j, rings, segments)
			c = spherePoint(i + 1, j + 1, rings, segments)
			d = spherePoint(i, j + 1, rings, segments)
			quad(out, a, d, c, b)
	out

fn spherePoint(i i64, j i64, rings i64, segments i64):
	v = f32(i) / f32(rings)
	u = f32(j) / f32(segments)
	theta = v * pi
	phi = u * 2.0 * pi
	n = Vec3(theta.sin() * phi.cos(), theta.cos(), theta.sin() * phi.sin())
	n.vertex(n, Vec3(u * 2.0, v, 0.0))

# a box of the given sizes about the origin, its faces flat
pub fn box(sx f32, sy f32, sz f32) shaders.MeshVertex[]:
	out = []
	h = Vec3(sx * 0.5, sy * 0.5, sz * 0.5)
	# each face: its normal and two directions along it
	faces = [
		(Vec3(1.0, 0.0, 0.0), Vec3(0.0, 0.0, -1.0), Vec3(0.0, 1.0, 0.0)),
		(Vec3(-1.0, 0.0, 0.0), Vec3(0.0, 0.0, 1.0), Vec3(0.0, 1.0, 0.0)),
		(Vec3(0.0, 1.0, 0.0), Vec3(1.0, 0.0, 0.0), Vec3(0.0, 0.0, -1.0)),
		(Vec3(0.0, -1.0, 0.0), Vec3(1.0, 0.0, 0.0), Vec3(0.0, 0.0, 1.0)),
		(Vec3(0.0, 0.0, 1.0), Vec3(1.0, 0.0, 0.0), Vec3(0.0, 1.0, 0.0)), (
			Vec3(0.0, 0.0, -1.0),
			Vec3(-1.0, 0.0, 0.0),
			Vec3(0.0, 1.0, 0.0)
	)]
	for (n, s, t) in faces:
		center = Vec3(n.x * h.x, n.y * h.y, n.z * h.z)
		su = Vec3(s.x * h.x, s.y * h.y, s.z * h.z)
		tv = Vec3(t.x * h.x, t.y * h.y, t.z * h.z)
		ws = (su.length() * 2.0).max(0.001)
		wt = (tv.length() * 2.0).max(0.001)
		a = vertex(center - su - tv, n, Vec3(0.0, wt, 0.0))
		b = vertex(center + su - tv, n, Vec3(ws, wt, 0.0))
		c = vertex(center + su + tv, n, Vec3(ws, 0.0, 0.0))
		d = vertex(center - su + tv, n, Vec3(0.0, 0.0, 0.0))
		quad(out, a, b, c, d)
	out

# a square floor of side `size` at y = 0, facing up, its texture repeated `tiles` times along a side
pub fn floor(size f32, tiles f32) shaders.MeshVertex[]:
	out = []
	h = size * 0.5
	n = Vec3(0.0, 1.0, 0.0)
	a = vertex(Vec3(-h, 0.0, h), n, Vec3(0.0, 0.0, 0.0))
	b = vertex(Vec3(h, 0.0, h), n, Vec3(tiles, 0.0, 0.0))
	c = vertex(Vec3(h, 0.0, -h), n, Vec3(tiles, tiles, 0.0))
	d = vertex(Vec3(-h, 0.0, -h), n, Vec3(0.0, tiles, 0.0))
	quad(out, a, b, c, d)
	out

# a ring about the y axis: radius `big` to the middle of the tube, the tube's radius `small`
pub fn torus(big f32, small f32, rings i64, segments i64) shaders.MeshVertex[]:
	out = []
	for i in 0..rings:
		for j in 0..segments:
			a = torusPoint(big, small, i, j, rings, segments)
			b = torusPoint(big, small, i + 1, j, rings, segments)
			c = torusPoint(big, small, i + 1, j + 1, rings, segments)
			d = torusPoint(big, small, i, j + 1, rings, segments)
			quad(out, a, d, c, b)
	out

fn torusPoint(big f32, small f32, i i64, j i64, rings i64, segments i64):
	u = f32(i) / f32(rings) * 2.0 * pi
	v = f32(j) / f32(segments) * 2.0 * pi
	center = Vec3(u.cos() * big, 0.0, u.sin() * big)
	n = Vec3(u.cos() * v.cos(), v.sin(), u.sin() * v.cos())
	vertex(
		center + n * small,
		n,
		Vec3(f32(i) / f32(rings) * 4.0, f32(j) / f32(segments), 0.0)
	)

# two triangles of the quad a b c d (counter-clockwise seen from its front)
fn quad(
	mut out shaders.MeshVertex[],
	a shaders.MeshVertex,
	b shaders.MeshVertex,
	c shaders.MeshVertex,
	d shaders.MeshVertex
):
	out.push(a)
	out.push(b)
	out.push(c)
	out.push(a)
	out.push(c)
	out.push(d)

# a vertex at `at` facing n, its texture place t
fn vertex(at Vec3, n Vec3, t Vec3):
	shaders.MeshVertex(position = at, normal = n, extra = t, spare = 0.0)

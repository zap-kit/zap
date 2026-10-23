# Skyrim's skin keeps its normals in model-space maps (_msn: a texel's red, blue and green are the
# normal's x, y and z in the model's space) and its shapes keep none of their own; its highlight's
# mask is a map of its own (_s). A skinned body bends those normals with its bones, so here they
# are made what a skinned vertex carries: each vertex's normal read from the map, and the map
# baked into one of the surface's bends (as a normal map of a lit part is: x along the way u runs,
# y along v, z the vertex's normal) whose alpha is the highlight's mask.

import image
import skyrim.nif

# the texel nearest to uv (wrapped)
fn texelAt(img image.Image, uv Vec2):
	x = i64((uv.x - uv.x.floor()) * f32(img.width)).clamp(0, img.width - 1)
	y = i64((uv.y - uv.y.floor()) * f32(img.height)).clamp(0, img.height - 1)
	img[x, y]

inward f32 = 0.25   # how far toward a triangle's middle a vertex's normal is read

fn crossOf(a Vec2, b Vec2):
	a.x * b.y - a.y * b.x

fn unit(b u8):
	f32(b) / 127.5 - 1.0

# the model-space normal a texel of an _msn map holds
pub fn modelNormalOf(c image.Rgba8) Vec3:
	Vec3(unit(c.r), unit(c.b), unit(c.g)).normalized()

# The part's normals read from its model-space map: at each vertex, the map's normals a little
# inside each triangle that meets there summed, so a vertex on the edge of the map's island reads
# none of the ground around it.
pub fn readNormals(mut p nif.Part, msn image.Image):
	sums = fill(p.positions.len, Vec3(0, 0, 0))
	for t in (0..p.indices.len - 2 step 3):
		k = (0..3).map(i64(p.indices[t + it]))
		middle = (p.uvs[k[0]] + p.uvs[k[1]] + p.uvs[k[2]]) / 3.0
		for v in k:
			sums[v] += msn.texelAt(p.uvs[v] + (middle - p.uvs[v]) * inward).modelNormalOf()
	p.normals = sums.map(.normalized() if .length() > 0.0 else Vec3(0, 0, 1))

# the ways the part's place runs as u and as v grow over triangle t
fn uvWays(p nif.Part, t i64) (Vec3, Vec3)?:
	a, b, c = i64(p.indices[t]), i64(p.indices[t + 1]), i64(p.indices[t + 2])
	e1 = p.positions[b] - p.positions[a]
	e2 = p.positions[c] - p.positions[a]
	d1 = p.uvs[b] - p.uvs[a]
	d2 = p.uvs[c] - p.uvs[a]
	det = d1.x * d2.y - d2.x * d1.y
	if det.abs() < 1.0e-12: return none
	((e1 * d2.y - e2 * d1.y) / det, (e2 * d1.x - e1 * d2.x) / det)

# a model-space normal n as the surface's bend about the normal `along`, encoded as a texel
fn bendTexel(n Vec3, along Vec3, u Vec3, v Vec3, mask u8):
	t = (u - along * (along @ u)).normalized()
	sign f32 = 1.0 if along.cross(t) @ v >= 0.0 else -1.0
	b = along.cross(t) * sign
	image.Rgba8(image.unitToByte(n @ t * 0.5 + 0.5), image.unitToByte(n @ b * 0.5 + 0.5),
		image.unitToByte(n @ along * 0.5 + 0.5), mask)

# triangle t of the part baked into `out` (covered marks the texels written)
fn bakeTriangle(p nif.Part, t i64, msn image.Image, mask image.Image?, mut out image.Image,
	mut covered bool[]):
	u, v = p.uvWays(t) ?? return
	k = (0..3).map(i64(p.indices[t + it]))
	w = f32(out.width)
	h = f32(out.height)
	corners = k.map(Vec2(p.uvs[it].x * w, p.uvs[it].y * h))
	lo = corners[0].min(corners[1]).min(corners[2])
	hi = corners[0].max(corners[1]).max(corners[2])
	area = crossOf(corners[1] - corners[0], corners[2] - corners[0])
	if area.abs() < 1.0e-9: return
	for y in i64(lo.y.floor()).max(0)..i64(hi.y.ceil()).min(out.height):
		for x in i64(lo.x.floor()).max(0)..i64(hi.x.ceil()).min(out.width):
			q = Vec2(f32(x) + 0.5, f32(y) + 0.5)
			b0 = crossOf(corners[1] - q, corners[2] - q) / area
			b1 = crossOf(corners[2] - q, corners[0] - q) / area
			b2 = 1.0 - b0 - b1
			if b0 < 0.0 or b1 < 0.0 or b2 < 0.0: continue
			along = (
				p.normals[k[0]] * b0 + p.normals[k[1]] * b1 + p.normals[k[2]] * b2
			).normalized()
			uv = Vec2(q.x / w, q.y / h)
			n = msn.texelAt(uv).modelNormalOf()
			shine = 255
			if mask is m: shine = m.texelAt(uv).r
			out[x, y] = n.bendTexel(along, u, v, u8(shine))
			covered[y * out.width + x] = true

# each texel no triangle covers takes a covered neighbor's, `rings` times over, so a sample at
# a seam reads no texel of the empty ground
fn spread(mut out image.Image, mut covered bool[], rings i64):
	loop rings:
		was = covered.copy()
		for y in 0..out.height:
			for x in 0..out.width:
				if was[y * out.width + x]: continue
				for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
					nx, ny = x + dx, y + dy
					if nx < 0 or ny < 0 or nx >= out.width or ny >= out.height: continue
					if was[ny * out.width + nx]:
						out[x, y] = out[nx, ny]
						covered[y * out.width + x] = true
						break

# The parts' model-space map (whose normals the parts carry: readNormals) baked into a map of
# the surface's bends of width x height, its alpha the mask's red (the highlight's), or whole
# without one.
pub fn bakeBends(
	parts nif.Part[],
	msn image.Image,
	mask image.Image?,
	width i64,
	height i64
) image.Image:
	out = image.Image(width, height, fill = image.Rgba8(128, 128, 255, 0))
	covered = fill(width * height, false)
	for p in parts:
		for t in (0..p.indices.len - 2 step 3):
			p.bakeTriangle(t, msn, mask, out, covered)
	out.spread(covered, 4)
	out

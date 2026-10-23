# FaceGen's TRI files (FRTRI003), the morphs of Skyrim's head parts: a header of ten counts, the
# base vertices, the triangles and quads, labels, texture coordinates, then the difference morphs
# (a name, a scale and a delta of three i16 per vertex, times the scale) and the stat morphs (a
# name and the vertices it moves to positions of their own). Layout after FaceGen's file format
# documentation (facegen.com, "TRI file format") as the head parts' .tri files bear it out.

import skyrim

# one named morph: each vertex's offset from the base at full strength
pub type Morph:
	name str
	deltas Vec3[]

pub type Tri:
	positions Vec3[]
	morphs Morph[]

fn vectors(mut r Reader, n i64):
	out = []
	loop n:
		out.push(Vec3(r.f32(), r.f32(), r.f32()))
	out

fn morphName(mut r Reader):
	n = i64(r.i32())
	str(r.cStringBytes(n))

# the difference morphs: each vertex's delta as three i16 times the morph's scale
fn differenceMorphs(mut r Reader, n i64, vertices i64):
	out = []
	loop n:
		name = r.morphName()
		scale = r.f32()
		deltas = []
		loop vertices:
			deltas.push(Vec3(r.i16(), r.i16(), r.i16()) * scale)
		out.push(Morph(name, deltas))
		if r.short: break
	out

# the stat morphs: the vertices each names take the next positions of the stat list
fn statMorphs(mut r Reader, n i64, base Vec3[], stat Vec3[]):
	out = []
	next = 0
	loop n:
		name = r.morphName()
		deltas = base.map(it * 0.0)
		loop i64(r.i32()):
			v = i64(r.i32())
			if v >= 0 and v < deltas.len and next < stat.len: deltas[v] = stat[next] - base[v]
			next += 1
		out.push(Morph(name, deltas))
		if r.short: break
	out

# a TRI file's base vertices and morphs, or why it cannot be read
pub fn readTri(d u8[]) Tri ? str:
	if d.len < 64 or str(d[..8]) != "FRTRI003": return "not a FaceGen TRI file (FRTRI003)"
	r = Reader(d, at = 8)
	counts = []
	loop 10:
		counts.push(i64(r.i32()))
	vertices, tris, quads, labelled, surface = counts[0], counts[1], counts[2], counts[3], counts[4]
	uvs, diffMorphs, statCount, statVertices = counts[5], counts[7], counts[8], counts[9]
	r.skip(16)
	positions = r.vectors(vertices)
	stat = r.vectors(statVertices)
	r.skip(tris * 12 + quads * 16)
	loop labelled:
		r.skip(4)
		r.skip(r.i32())
	loop surface:
		r.skip(12)
		r.skip(r.i32())
	if uvs > 0: r.skip(uvs * 8 + tris * 12 + quads * 16)
	morphs = r.differenceMorphs(diffMorphs, vertices)
	morphs.extend(r.statMorphs(statCount, positions, stat))
	if r.short: return "a TRI file is cut short"
	Tri(positions, morphs)

# the TRI file with this archive key, or why it cannot be read
pub fn readTriKey(i skyrim.Install, key str) Tri ? str:
	bytes = i.installRead(key) ?? return "{key} is in no archive"
	readTri(bytes) ?? return "{key}: {error}"

# positions moved by the morph of this name (any case) at `weight`; unchanged when the TRI has no
# such morph or another vertex count
pub fn morphed(t Tri, positions Vec3[], name str, weight f32) Vec3[]:
	want = name.lower()
	m = t.morphs.find(.name.lower() == want) ?? return positions.copy()
	if m.deltas.len != positions.len: return positions.copy()
	(0..positions.len).map(positions[it] + m.deltas[it] * weight)

# positions moved by the named morphs (any case) at their weights together, as a head's TRI
# morphs follow a lip track (skyrim.lipWeights); a name the TRI lacks moves nothing
pub fn morphedBy(t Tri, positions Vec3[], names str[], weights f32[]) Vec3[]:
	out = positions.copy()
	for k in 0..names.len.min(weights.len):
		if weights[k] == 0.0: continue
		want = names[k].lower()
		m = t.morphs.find(.name.lower() == want) ?? continue
		if m.deltas.len != out.len: continue
		for v in 0..out.len:
			out[v] += m.deltas[v] * weights[k]
	out

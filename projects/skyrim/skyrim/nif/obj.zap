# Models written as Wavefront OBJ, for a look in any viewer: positions, texture places, triangles.

# one object of Wavefront OBJ, its texture places when every vertex has one; `base` the number
# of its first vertex
fn objObject(mut out str[], name str, positions Vec3[], uvs Vec2[], indices u32[], base i64):
	out.push("o {name}")
	for v in positions:
		out.push("v {v.x} {v.y} {v.z}")
	for t in uvs:
		out.push("vt {t.x} {1.0 - t.y}")
	textured = uvs.len == positions.len
	for k in 0..indices.len / 3:
		c = (0..3).map(indices[k * 3 + it] + base)
		if textured:
			out.push("f {c[0]}/{c[0]} {c[1]}/{c[1]} {c[2]}/{c[2]}")
		else:
			out.push("f {c[0]} {c[1]} {c[2]}")

# the parts as Wavefront OBJ, one object per part, then the colliders' triangles as one more
pub fn objText(parts Part[], colliders Collider[]) str:
	out str[] = []
	base = 1
	for p in parts:
		out.objObject(p.name, p.positions, p.uvs, p.indices, base)
		base += p.positions.len
	if not colliders.isEmpty:
		positions = []
		indices = []
		for c in colliders:
			for k in c.indices:
				indices.push(k + u32(positions.len))
			positions.extend(c.positions)
		out.objObject("collision", positions, [], indices, base)
	"{out.join("\n")}\n"

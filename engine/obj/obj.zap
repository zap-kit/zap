# Wavefront OBJ models with their MTL materials, as triangles of Vertex: position, normal,
# color (linear) and a spare value, 1 for the faces of a material whose name says it is foliage
# (leaves, grass, bushes: what a wind sways); a program that draws them takes a vertex struct of
# these four fields (40 bytes). A material's color is its Kd,
# times its texture (map_Kd) where the face's texture coordinates point: the low-poly kits that
# paint their faces from a palette image come out with the palette's colors. A material cut out
# by a texture's alpha (map_d: painted leaves, grass) keeps the texture instead: its vertices
# carry the texture coordinates in the color (u, v from the top, 1) and 2 + the cutout's index
# in `cutouts` as the spare value, for the program to sample and cut. Polygons are cut into fans;
# a face without normals gets its flat one.

import fs
import image

# the color is linear
pub type Vertex:
	position Vec3
	normal Vec3
	color Vec3
	spare f32

pub type Model:
	vertices Vertex[]
	lo Vec3   # the box the model fills
	hi Vec3
	cutouts str[] = []   # the cutout textures' paths

type Material:
	name str
	color Vec3   # linear
	texture image.Image?
	foliage bool
	cutout str = ""   # the map_d texture's path ("": none)
	texturePath str = ""   # map_Kd's, read once the file is read

# the model in an .obj file, its materials read from the .mtl it names (beside it)
pub fn loadObj(path str) Model:
	text = fs.readFile(path) ?? ""
	if text == "":
		fail("cannot read the model {path}")
	materials = []
	positions = []
	normals = []
	uvs = []
	current = -1
	out = Model(
		vertices = [],
		lo = Vec3(1.0e9, 1.0e9, 1.0e9),
		hi = Vec3(-1.0e9, -1.0e9, -1.0e9)
	)
	for line in text.lines():
		parts = line.trimmed().split(" ").filter(not .isEmpty)
		if parts.isEmpty: continue
		key = parts[0]
		if key == "v" and parts.len >= 4:
			positions.push(Vec3(number(parts[1]), number(parts[2]), number(parts[3])))
		elif key == "vn" and parts.len >= 4:
			normals.push(Vec3(number(parts[1]), number(parts[2]), number(parts[3])))
		elif key == "vt" and parts.len >= 3:
			uvs.push(Vec2(number(parts[1]), number(parts[2])))
		elif key == "mtllib" and parts.len >= 2:
			readMaterials(fs.join(fs.dirOf(path), parts[1]), materials)
		elif key == "usemtl" and parts.len >= 2:
			current = materialNamed(materials, parts[1])
		elif key == "f" and parts.len >= 4:
			corners = parts[1..]
				.map(cornerOf(it, positions.len, uvs.len, normals.len))
			for i in 1..corners.len - 1:
				triangle(
					out,
					materials,
					current,
					positions,
					uvs,
					normals,
					corners[0],
					corners[i],
					corners[i + 1]
				)
	out

# a face's corner: its position, texture and normal indices (-1: none)
type Corner:
	p i64
	t i64
	n i64

# "3/1/2", "3//2", "3": indices from 1, or from the end when negative
fn cornerOf(s str, np i64, nt i64, nn i64):
	f = s.split("/")
	Corner(p = indexOf(f, 0, np), t = indexOf(f, 1, nt), n = indexOf(f, 2, nn))

fn indexOf(f str[], k i64, count i64):
	if k >= f.len or f[k] == "": return -1
	i = i64.parse(f[k]) ?? 0
	count + i if i < 0 else i - 1

fn materialNamed(materials Material[], name str):
	materials.findIndex(.name == name) ?? -1

# a texture's path as the .mtl writes it, beside the .mtl: an absolute one (C:/x.png, the
# exporter's machine) taken by its file name
fn textureBeside(mtl str, written str):
	absolute = ":" in written or written.startsWith("/")
	fs.join(fs.dirOf(mtl), fs.fileName(written) if absolute else written)

fn number(s str):
	f32(f64.parse(s) ?? 0.0)

fn triangle(
	mut out Model,
	materials Material[],
	current i64,
	positions Vec3[],
	uvs Vec2[],
	normals Vec3[],
	a Corner,
	b Corner,
	c Corner
):
	pa = positions[a.p]
	pb = positions[b.p]
	pc = positions[c.p]
	flat = (pb - pa).cross(pc - pa).normalized()
	foliage = 0.0
	if current >= 0 and materials[current].foliage:
		foliage = 1.0
	cut = -1
	if current >= 0 and materials[current].cutout != "":
		cut = match out.cutouts.indexOf(materials[current].cutout):
			i: i
			none:
				out.cutouts.push(materials[current].cutout.copy())
				out.cutouts.len - 1
	for k in [a, b, c]:
		p = positions[k.p]
		n = normals[k.n] if k.n >= 0 else flat
		color = Vec3(0.8, 0.8, 0.8)
		if cut >= 0:
			t = uvs[k.t] if k.t >= 0 else Vec2(0.0, 0.0)
			out.vertices.push(
				Vertex(
					position = p,
					normal = n,
					color = Vec3(t.x, 1.0 - t.y, 1.0),
					spare = 2.0 + f32(cut)
				)
			)
			out.lo = Vec3(out.lo.x.min(p.x), out.lo.y.min(p.y), out.lo.z.min(p.z))
			out.hi = Vec3(out.hi.x.max(p.x), out.hi.y.max(p.y), out.hi.z.max(p.z))
			continue
		if current >= 0:
			color = materials[current].color
			if materials[current].texture is img:
				if k.t >= 0:
					color *= img.texel(uvs[k.t])
		out.vertices.push(Vertex(position = p, normal = n, color, spare = foliage))
		out.lo = Vec3(out.lo.x.min(p.x), out.lo.y.min(p.y), out.lo.z.min(p.z))
		out.hi = Vec3(out.hi.x.max(p.x), out.hi.y.max(p.y), out.hi.z.max(p.z))

# the linear color of the image at texture coordinates t (v up from the bottom, wrapping)
fn texel(img image.Image, t Vec2):
	u = t.x - t.x.floor()
	v = t.y - t.y.floor()
	x = i64(u * f32(img.width)).min(img.width - 1)
	y = i64((1.0 - v) * f32(img.height)).min(img.height - 1)
	p = img[x, y]
	Vec3(linear(p.r), linear(p.g), linear(p.b))

fn linear(b u8):
	toLinear(f32(b) / 255.0)

fn readMaterials(path str, mut out Material[]):
	text = fs.readFile(path) ?? ""
	for line in text.lines():
		parts = line.trimmed().split(" ").filter(not .isEmpty)
		if parts.isEmpty: continue
		if parts[0] == "newmtl" and parts.len >= 2:
			name = parts[1].lower()
			foliage = "leaf" in name or "leaves" in name or "grass" in name or "bush" in name or
				"foliage" in name
			out.push(
				Material(name = parts[1], color = Vec3(0.8, 0.8, 0.8), texture = none, foliage)
			)
		elif parts[0] == "Kd" and parts.len >= 4 and not out.isEmpty:
			# Kd is written as the color seen (sRGB); light works in linear
			out[len - 1].color = Vec3(
				toLinear(number(parts[1])),
				toLinear(number(parts[2])),
				toLinear(number(parts[3]))
			)
		elif parts[0] == "map_d" and parts.len >= 2 and not out.isEmpty:
			out[len - 1].cutout = textureBeside(path, parts[len - 1])
		elif parts[0] == "map_Kd" and parts.len >= 2 and not out.isEmpty:
			out[len - 1].texturePath = textureBeside(path, parts[len - 1])
	# a cutout material samples its texture where it is drawn: only the others bake theirs
	for i in 0..out.len:
		if out[i].cutout == "" and out[i].texturePath != "":
			out[i].texture = image.loadPng(out[i].texturePath)

# sRGB to linear, as a power of 2.2
fn toLinear(c f32) f32:
	0.0 if c <= 0.0 else f32((f64(c).ln() * 2.2).exp())

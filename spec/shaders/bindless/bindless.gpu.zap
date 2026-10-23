# Bindless drawing, the program the tests read back: every texture in one array without a length,
# indexed by the material record of the draw (a storage buffer of structs), a second array of a
# fixed length, the index computed per pixel (NonUniform), a texture's size read through it.

import shaders.vecs

pub type Material:
	tint Vec4
	scale Vec2
	albedo i32
	layer i32

pub type Corner:
	position Vec3
	coord Vec2

pub type Scene:
	viewProjection Mat4
	material i32
	textures vecs.Texture[]
	layers vecs.TextureArray[4]
	materials Material[]

type Seen:
	uv Vec2
	material i32

pub fn vertex(v Corner, copy i32, s Scene) (Vec4, Seen):
	(s.viewProjection @ v.position.withW(1.0), Seen(uv = v.coord, material = s.material + copy))

pub fn pixel(b Seen, s Scene) Vec4:
	m = s.materials[b.material]
	size = s.textures[m.albedo].size()
	texel = Vec2(1.0 / f32(size.x), 1.0 / f32(size.y))
	base = s.textures[m.albedo].sample(b.uv * m.scale + texel * 0.5)
	detail = s.layers[m.layer & 3].sample(b.uv, f32(m.layer))
	first = s.textures[0].sample(b.uv)
	base * s.materials[b.material].tint * detail + first * 0.0

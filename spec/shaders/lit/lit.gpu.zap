# A lit surface, the program of both stages the tests read back: a vertex of three attributes
# and an instance of two, parameters of every kind the block holds (a matrix, a vector, an
# array, a nested struct, a bool, an enum, a number after them), a texture, a shadow map, a
# storage buffer, values passed on (one of them an integer: not interpolated), a loop, a
# helper given the parameters, a tuple taken apart, a discard; @ as the matrix and the dot
# product, * element by element on a matrix.

import shaders.vecs

pub type Vertex:
	position Vec3
	normal Vec3
	uv Vec2

pub type Copy:
	offset Vec3
	kind i32

pub type Fog:
	color Vec4
	density f32

pub type Wrap:
	Repeat
	Mirror
	Clamp

pub type Params:
	viewProjection Mat4
	tint Vec3
	weights f32[3]
	fog Fog
	lit bool
	wrap Wrap
	strength f32
	picture vecs.Texture
	shadow vecs.ShadowMap
	lights Vec4[]

type Between:
	normal Vec3
	uv Vec2
	kind i32

pub fn vertex(v Vertex, c Copy, p Params) (Vec4, Between):
	world = v.position + c.offset
	doubled = p.viewProjection * 2.0 - p.viewProjection * p.viewProjection / p.viewProjection
	(
		doubled @ world.withW(1.0) - p.viewProjection @ world.withW(1.0),
		Between(normal = v.normal, uv = v.uv, kind = c.kind)
	)

# the light reaching a surface facing n
fn shade(n Vec3, p Params) f32:
	sum = 0.0
	for i in 0..3:
		sum += (n @ p.lights[i].xyz).max(0.0) * p.weights[i]
	sum * p.strength

# a match over an enum and a variant named by the enum it is compared with (.Clamp)
fn wrapped(u f32, p Params) (f32, bool):
	match p.wrap:
		Clamp:
			return (u.clamp(0.0, 1.0), false)
		_: pass
	(u.fract(), p.wrap != .Clamp)

pub fn pixel(b Between, p Params) Vec4:
	u, repeated = wrapped(b.uv.x, p)
	c = p.picture.sample(Vec2(u, b.uv.y)).rgb * p.tint
	if p.lit:
		c = c * shade(b.normal.normalized(), p) * p.shadow.compare(b.uv, 0.5)
	if b.kind > 3 or not repeated and u > 2.0:
		discard()
	c.lerp(p.fog.color.rgb, p.fog.density).withW(1.0)

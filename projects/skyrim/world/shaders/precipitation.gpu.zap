# Rain and snow as Skyrim's particle shader draws them (Community Shaders' Particle.hlsl, the ENVCUBE
# permutations): a cube of particles about the eye, each at a fixed place in it that the fall
# carries along and the cube wraps (a place plus the offset, taken modulo the cube's side), drawn
# as a quad whose corners are offsets added to the clip position. A rain streak is stretched along
# its velocity (the quad's corner y, -1 to 1, blends the tail position into the head's); a snow
# flake turns in its plane by the spin and is scaled by the aspect.

import engine

# a corner of a particle (y up): its place in the cube, its corner offset in clip units and its texture
pub type PrecipVertex:
	position Vec3
	corner Vec2
	uv Vec2

pub type PrecipParams:
	viewProjection Mat4
	offset Vec3 = Vec3(0.0, 0.0, 0.0)   # how far the fall has carried the cube's particles
	box f32 = 1.0   # the cube's side
	center Vec3 = Vec3(0.0, 0.0, 0.0)   # the eye: the cube's middle
	snow f32 = 0.0   # 1 for snow
	streak Vec3 = Vec3(0.0, 0.0, 0.0)   # a rain streak's tail from its head, world units
	spin f32 = 0.0   # a snow flake's turn, radians
	scaleAdjust Vec2 = Vec2(1.0, 1.0)   # a snow flake's offsets, clip units, per axis
	alpha f32 = 1.0
	texture engine.Texture = engine.Texture(id = -1, width = 1, height = 1)

pub type PrecipPoint:
	uv Vec2

# a number held between 0 and the side: what is left of it past whole sides
fn wrapped(x f32, side f32) f32:
	(x / side).fract() * side

pub fn precipVertex(v PrecipVertex, p PrecipParams) (Vec4, PrecipPoint):
	moved = v.position + p.offset
	place = Vec3(wrapped(moved.x, p.box), wrapped(moved.y, p.box), wrapped(moved.z, p.box))
	head = place - Vec3(p.box * 0.5, p.box * 0.5, p.box * 0.5) + p.center
	clip = p.viewProjection @ head.withW(1.0)
	if p.snow < 0.5:
		tail = p.viewProjection @ (head - p.streak).withW(1.0)
		blend = 0.5 * (1.0 + v.corner.y)
		at = tail + (clip - tail) * blend
		return (Vec4(at.x + v.corner.x, at.y + v.corner.y, at.z, at.w), PrecipPoint(uv = v.uv))
	s = p.spin.sin()
	c = p.spin.cos()
	turned = Vec2(c * v.corner.x - s * v.corner.y, s * v.corner.x + c * v.corner.y)
	(Vec4(clip.x + turned.x * p.scaleAdjust.x, clip.y + turned.y * p.scaleAdjust.y, clip.z, clip.w),
		PrecipPoint(uv = v.uv))

pub fn precipPixel(b PrecipPoint, p PrecipParams) Vec4:
	t = p.texture.sample(b.uv)
	t.rgb.withW(t.a * p.alpha)

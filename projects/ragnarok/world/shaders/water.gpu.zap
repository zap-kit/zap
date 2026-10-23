# The water as the client draws it: a sheet at the water's level whose height swells in waves
# along x and z, one of its 32 texture frames at a time, half see-through, fading far away into
# the sky's haze.

import engine

# a vertex of the water's sheet as the prepared map holds it
pub type WaterVertex:
	position Vec3
	uvPlace Vec3
	unused Vec3
	spare f32

pub type WaterParams:
	projection Mat4
	view Mat4
	height f32   # the waves' height
	pitch f32
	phase f32   # degrees
	frame f32   # the texture's layer
	opacity f32
	haze Haze
	frames engine.TextureArray

pub type WaterPoint:
	uv Vec2
	distance f32

pub fn waterVertex(v WaterVertex, p WaterParams) (Vec4, WaterPoint):
	at = v.position
	x = at.x - (at.x / 2.0).floor() * 2.0
	z = -at.z - (-at.z / 2.0).floor() * 2.0
	diagonal = (1.0 if z < 1.0 else -1.0) if x < 1.0 else 0.0
	swell = (p.phase + 0.5 * p.pitch * (at.x - at.z + diagonal)).radians().sin() * p.height
	seen = p.view @ Vec4(at.x, at.y + swell, at.z, 1.0)
	(p.projection @ seen, WaterPoint(uv = v.uvPlace.xy, distance = seen.xyz.length()))

pub fn waterPixel(b WaterPoint, p WaterParams) Vec4:
	hazed(p.frames.sample(b.uv, p.frame).rgb, b.distance, p.haze).withW(p.opacity)

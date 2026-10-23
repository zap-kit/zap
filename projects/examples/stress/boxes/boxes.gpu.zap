# A box placed by its own matrix, tinted and textured: one draw each, its parameters set before it.

import engine

pub type BoxVertex:
	position Vec3
	uv Vec2

pub type BoxParams:
	viewProjection Mat4
	model Mat4
	tint Vec4
	picture engine.Texture

pub fn boxVertex(v BoxVertex, p BoxParams) (Vec4, Vec2):
	(p.viewProjection @ p.model @ v.position.withW(1.0), v.uv)

pub fn boxPixel(uv Vec2, p BoxParams) Vec4:
	p.picture.sample(uv) * p.tint

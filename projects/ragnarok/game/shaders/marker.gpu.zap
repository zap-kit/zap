# A marker lying on the ground (the cell under the mouse): its texture as it is, blended.

import engine

pub type MarkerVertex:
	position Vec3
	uv Vec2

pub type MarkerParams:
	projection Mat4
	view Mat4
	picture engine.Texture

pub fn markerVertex(v MarkerVertex, p MarkerParams) (Vec4, Vec2):
	(p.projection @ p.view @ v.position.withW(1.0), v.uv)

pub fn markerPixel(uv Vec2, p MarkerParams) Vec4:
	p.picture.sample(uv)

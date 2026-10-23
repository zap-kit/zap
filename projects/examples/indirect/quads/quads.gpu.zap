# The example's stages: a corner of a quad (its place, its color) moved by its copy's offset,
# scaled by the parameters (a vertex stage of an instance struct takes parameters after it).

pub type Corner:
	position Vec2
	color Vec4

pub type Place:
	offset Vec2

pub type View:
	scale f32

type Shade:
	color Vec4

pub fn vertex(v Corner, c Place, p View) (Vec4, Shade):
	(
		Vec4((v.position.x + c.offset.x) * p.scale, (v.position.y + c.offset.y) * p.scale, 0.0, 1.0),
		Shade(color = v.color)
	)

pub fn pixel(s Shade) Vec4:
	s.color

# A quaternion read in a pixel stage: laid out as a vec4, its fields and its arithmetic a vector's,
# and a product of turns.

pub type Turn:
	q Quat

pub fn pixel(uv Vec2, p Turn) Vec4:
	r = p.q * 2.0 + Quat(0.0, 0.0, 0.0, 1.0)
	s = r @ p.q
	Vec4(s.x, r.y, uv.x, r.w)

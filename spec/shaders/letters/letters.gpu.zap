# A vector made of its components by name, in any of the letter sets a swizzle reads.

pub type Tint:
	scale f32

pub fn pixel(uv Vec2, p Tint) Vec4:
	st = Vec2(t = uv.y, s = uv.x)
	Vec4(b = st.t, r = st.s, g = p.scale, a = 1.0)

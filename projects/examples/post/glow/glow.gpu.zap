# A scene of HDR light: a small disk of light 8 on a dim ground of 0.05.

pub type Glow:
	radius f32

pub fn pixel(uv Vec2, p Glow) Vec4:
	Vec4(8.0, 8.0, 8.0, 1.0) if (uv - 0.5).length() < p.radius else Vec4(0.05, 0.05, 0.05, 1.0)

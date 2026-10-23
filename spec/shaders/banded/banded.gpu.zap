# A pixel stage with range types: a band proven inside by a check just made and by a clamp, and
# a natural count; a shader cannot stop the program, so a range's conversion is refused there.

type Band = i32 in 0..=3

fn shade(b Band, steps n32) f32:
	f32(b + 1) / f32(steps + 1)

pub fn pixel(uv Vec2) Vec4:
	raw = i32(uv.x * 4.0)
	band Band = 0
	if raw >= 0 and raw <= 3:
		band = raw
	g = shade(band, 3) + shade(raw.clamp(0, 3), 2)
	Vec4(g, g, g, 1.0)

# Colors: a color from 0..255 channels, and white and black. The geometry (projections, views,
# moves, turns) is std/math's, over the language's types.

# a color from 0..255 channels, opaque: rgb8(255, 128, 0)
pub fn rgb8(r i64, g i64, b i64) Vec4:
	Vec4(r = f32(r) / 255.0, g = f32(g) / 255.0, b = f32(b) / 255.0, a = 1.0)

pub white = Vec4(r = 1.0, g = 1.0, b = 1.0, a = 1.0)
pub black = Vec4(r = 0.0, g = 0.0, b = 0.0, a = 1.0)

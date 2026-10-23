# A pass over a whole target: a pixel stage alone, given where it is across the target.

import shaders.vecs

pub type Exposure:
	picture vecs.TextureArray
	scale f32

pub fn pixel(uv Vec2, p Exposure) Vec4:
	(p.picture.sample(uv, 0).rgb * p.scale).withW(1.0)

# The drawn picture put on the screen.

import engine

pub type ShowParams:
	picture engine.Texture

pub fn showPixel(uv Vec2, p ShowParams) Vec4:
	p.picture.sample(uv).rgb.withW(1.0)

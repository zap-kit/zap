# A pass whose pixel stage calls a function of another module's GPU files (tonemap.aces): the
# imported functions keep their own names apart from this module's (a `curve` of its own).

import shaders.tonemap

fn curve(x f32) f32:
	x * 0.5

pub fn pixel(uv Vec2) Vec4:
	tonemap.aces(Vec3(uv.x, uv.y, curve(uv.x))).withW(1.0)

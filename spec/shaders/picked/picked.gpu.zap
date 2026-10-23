# A pass whose pixel stage calls a GPU function of a module it imports (tonemap.aces).

import shaders.tonemap

pub fn pixel(uv Vec2) Vec4:
	tonemap.aces(Vec3(uv.x, uv.y, 0.5)).withW(1.0)

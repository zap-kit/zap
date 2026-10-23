# The sky behind everything: a window of 320 x 240 units onto the sky's picture (1280 units
# across for a whole turn, 960 tall), its left edge where the camera's turn puts it and its top
# where its tilt does. The picture is 8 x 8 tiles of 32 x 32 texels, each drawn as skybox.c does
# over 160 x 120 units: texture coordinates 0 to 31 << 5 (scaled by 0xFFFF, so 991/32 texels
# across it), half a texel on for bilinear filtering, clamped to the tile.

import engine

pub type SkyParams:
	window Vec2   # the left edge, the top (sky units)
	sky engine.Texture

span = 991.0 / 32.0

# a coordinate in units along an axis of tiles `size` units long, as a texel of the picture
fn skyTexel(units f32, size f32) f32:
	tile = (units / size).floor()
	t = (units - tile * size) / size * span + 0.5
	tile % 8.0 * 32.0 + t.clamp(0.5, 31.5)

pub fn skyPixel(uv Vec2, p SkyParams) Vec4:
	x = p.window.x + uv.x * 320.0
	y = p.window.y - 240.0 + uv.y * 240.0
	p.sky.sample(Vec2(skyTexel(x, 160.0), skyTexel(960.0 - y, 120.0)) / 256.0).rgb.withW(1.0)

# The bytes of a texture's levels in each format the engine uploads: 4 a pixel, or blocks of 4x4
# pixels (BC1 8 bytes, BC3 16), a level smaller than a block taking one.

import engine

test "the bytes of a level by format":
	expect engine.levelBytes(.Rgba8, 13, 9) == 13 * 9 * 4
	expect engine.levelBytes(.Rgba8Srgb, 2, 2) == 16
	expect engine.levelBytes(.Bc1, 256, 128) == 64 * 32 * 8
	expect engine.levelBytes(.Bc1Srgb, 4, 4) == 8
	expect engine.levelBytes(.Bc3, 256, 128) == 64 * 32 * 16
	expect engine.levelBytes(.Bc3Srgb, 2, 1) == 16
	expect engine.levelBytes(.Bc1, 13, 9) == 4 * 3 * 8

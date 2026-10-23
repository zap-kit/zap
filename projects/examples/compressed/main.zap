# Textures of other formats than 8-bit RGBA on the backend the environment picks: a BC1 texture of
# red blocks, a BC3 one of green blocks half transparent, a BC7 one of blue, a BC4 one of a red of
# 128, a BC5 one of 128 and 64 in red and green, an sRGB one of a middle gray (128, read as linear
# 0.216), each with two levels written ahead, drawn by the sprite batch into a frame read back.
# Each must show the color it holds: red; green blended at half over black; blue; (128, 0, 0);
# (128, 64, 0); a gray of 55.
#   zap run projects/examples/compressed/main.zap          (from the repository's root; ZAP_RUN=gpu=d3d12 for Direct3D 12)

import engine
import image

size = 64

# a level of w x h of the same block (or pixel) repeated
fn level(format engine.TextureFormat, w i64, h i64, block u8[]):
	out = []
	n = format.levelBytes(w, h) / block.len
	loop n:
		out.extend(block)
	out

# the color read back at the center of the square drawn at x
fn colorAt(img image.Image, x i64) (i64, i64, i64):
	p = img[x + size / 2, size / 2]
	(p.r, p.g, p.b)

fn near(a (i64, i64, i64), b (i64, i64, i64)):
	ar, ag, ab = a
	br, bg, bb = b
	(ar - br).abs() <= 2 and (ag - bg).abs() <= 2 and (ab - bb).abs() <= 2

mut frames = engine.newFrames()
mut win = engine.openWindow("Texture formats", size * 6, size)
mut r = engine.newRenderer()
# BC1: color0 red (RGB565 0xF800), color1 black, every index 0
red u8[] = [0x00, 0xF8, 0x00, 0x00, 0, 0, 0, 0]
# BC3: alpha0 128, alpha1 0, every alpha index 0; then color0 green (0x07E0), color1 black, every index 0
green u8[] = [128, 0, 0, 0, 0, 0, 0, 0, 0xE0, 0x07, 0x00, 0x00, 0, 0, 0, 0]
# BC7 mode 6: every endpoint (1, 1, 255, 255) by its p-bit, every index 0
blue u8[] = [0x40, 0, 0, 0, 0xF8, 0xFF, 0xFF, 0xFF, 0x01, 0, 0, 0, 0, 0, 0, 0]
# BC4: red0 128, red1 0, every index 0
one u8[] = [128, 0, 0, 0, 0, 0, 0, 0]
# BC5: red0 128 then green0 64, every index 0
two u8[] = [128, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0]
gray u8[] = [128, 128, 128, 255]
sampling = engine.Sampling(
	smooth = false,
	mipmaps = true,
	repeat = false,
	mirror = 0,
	anisotropy = false
)
formats engine.TextureFormat[] = [.Bc1, .Bc3, .Bc7, .Bc4, .Bc5, .Rgba8Srgb]
blocks = [red, green, blue, one, two, gray]
textures = (0..6).map(i:
	engine.newTextureOfFormat(
		size,
		size,
		formats[i].level(size, size, blocks[i]),
		sampling,
		format = formats[i],
		mips = [formats[i].level(size / 2, size / 2, blocks[i])]
	)
)
if not win.nextFrame(frames):
	fail("the window closed")
r.beginFrame(win.width, win.height, Vec4(0.0, 0.0, 0.0, 1.0), engine.Camera())
for i in 0..6:
	r.draw(textures[i].texture(), f32(i * size), 0.0)
img = r.screenshot()
got = [0, 1, 2, 3, 4, 5].map(img.colorAt(it * size))
wanted = [(255, 0, 0), (0, 128, 0), (0, 0, 255), (128, 0, 0), (128, 64, 0), (55, 55, 55)]
mut right = 0
for i in 0..6:
	if near(got[i], wanted[i]):
		right += 1
print("{engine.backendName()}: BC1, BC3, BC7, BC4, BC5 and sRGB textures read right: {right} of 6 {got}")
if right != 6:
	exit(1)

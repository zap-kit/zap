# Plasma: every pixel of a 480 x 270 picture computed on the CPU each frame (a plasma of sines),
# the rows shared out among every processor, then shown stretched as one texture.

import engine
import image

pictureW = 480
pictureH = 270

pub type Plasma:
	pixels image.Image
	palette image.Rgba8[]   # 256 colors
	picture engine.GpuTexture
	time f64

pub fn newPlasma() Plasma:
	palette = []
	for i in 0..256:
		a = i / 256.0 * tau
		channel = (shift f64): u8(i64(128.0 + 127.0 * (a + shift).sin()))
		palette.push(image.Rgba8(channel(0.0), channel(2.1), channel(4.2), 255))
	pixels = image.Image(pictureW, pictureH, fill = image.Rgba8(0, 0, 0, 255))
	Plasma(
		picture = pixels.newTexture(),
		pixels,
		palette,
		time = 0.0
	)

pub fn stepPlasma(mut s Plasma, dt f32):
	s.time += f64(dt)
	t = s.time
	for y in (0..pictureH).parallel():
		fy = y / 27.0
		for x in 0..pictureW:
			fx = x / 27.0
			v = (fx + t).sin() + (fy * 1.3 - t * 0.7).sin() + ((fx + fy + t) * 0.6).sin() +
				((fx * fx + fy * fy).sqrt() * 0.9 - t * 1.6).sin()
			s.pixels[x, y] = s.palette[i64((v + 4.0) * 32.0) & 255]
	s.picture.updateTexture(s.pixels)

pub fn drawPlasma(s Plasma, mut r engine.Renderer, w i64, h i64):
	r.beginFrame(w, h, Vec4(0.0, 0.0, 0.0, 1.0), engine.Camera())
	r.drawQuad(s.picture.texture(), 0.0, 0.0, f32(w), f32(h))
	r.endFrame()

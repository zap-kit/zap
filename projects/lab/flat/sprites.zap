# Sprites: thousands of balls bouncing under gravity, all drawn by the 2D batch in a few calls;
# their texture made in code. Space adds a thousand, Backspace takes a thousand away.

import engine
import image
import physics

pub type Sprites:
	ball engine.GpuTexture
	balls Table<physics.Ball>
	rng Random   # the balls' places, speeds and sizes, the same each run

pub fn newSprites(w i64, h i64) Sprites:
	balls Table<physics.Ball> = []
	rng = Random(7)
	addBalls(balls, 5000, w, h, rng)
	Sprites(ball = ballTexture(64), balls, rng)

pub fn spriteCount(s Sprites) i64:
	s.balls.len

# a soft ball: opaque in the middle, its edge fading out, a highlight up and to the left
fn ballTexture(n i64):
	pixels = image.Image(n, n, fill = image.Rgba8(0, 0, 0, 0))
	c = f32(n) / 2.0
	for y in 0..n:
		for x in 0..n:
			dx = f32(x) + 0.5 - c
			dy = f32(y) + 0.5 - c
			d = (dx * dx + dy * dy).sqrt() / c
			alpha = ((1.0 - d) * 6.0).clamp(0.0, 1.0)
			hx = dx + c * 0.35
			hy = dy + c * 0.35
			light = (1.0 - (hx * hx + hy * hy).sqrt() / c).clamp(0.0, 1.0)
			v = image.unitToByte(0.55 + 0.45 * light)
			pixels[x, y] = image.Rgba8(v, v, v, image.unitToByte(alpha))
	pixels.newTexture()

fn addBalls(mut balls Table<physics.Ball>, n i64, w i64, h i64, mut rng Random):
	loop n:
		hue = rng.next(0.0..1.0)
		balls.push(physics.Ball(
			x = f32(rng.next(0..=w - 30)),
			y = f32(rng.next(0..=h - 30)),
			vx = f32(rng.next(0.0..1.0) * 400.0 - 200.0),
			vy = f32(rng.next(0.0..1.0) * 400.0 - 200.0), size = f32(rng.next(8..=28)),
			tint = Vec4(
				f32(0.5 + 0.5 * (hue * 6.28).cos()),
				f32(0.5 + 0.5 * (hue * 6.28 + 2.1).cos()),
				f32(0.5 + 0.5 * (hue * 6.28 + 4.2).cos()),
				1.0
		)))

pub fn stepSprites(mut s Sprites, dt f32, w i64, h i64):
	if engine.isKeyPressed(.Space):
		addBalls(s.balls, 1000, w, h, s.rng)
	if engine.isKeyPressed(.Backspace) and s.balls.len >= 1000:
		s.balls.truncate(s.balls.len - 1000)
	physics.bounce(s.balls, dt, f32(w), f32(h))

pub fn drawSprites(s Sprites, mut r engine.Renderer, w i64, h i64):
	r.beginFrame(w, h, engine.rgb8(18, 20, 28), engine.Camera())
	for b in s.balls:
		r.drawQuad(s.ball.texture(), b.x, b.y, b.size, b.size, tint = b.tint)
	r.endFrame()

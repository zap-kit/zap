# Hello: text, bars that breathe, a square that follows the mouse (bigger while a button is
# held), a background that slowly changes color.

import engine

pub type Hello:
	font engine.Font
	small engine.Font
	time f32

pub fn newHello() Hello:
	Hello(
		font = engine.loadFont("Segoe UI", 34),
		small = engine.loadFont("Consolas", 18),
		time = 0.0
	)

pub fn stepHello(mut s Hello, dt f32):
	s.time += dt

pub fn drawHello(s Hello, mut r engine.Renderer, w i64, h i64):
	t = s.time
	background = Vec4(0.08, 0.09 + 0.04 * (t * 0.7).sin(), 0.14, 1.0)
	r.beginFrame(w, h, background, engine.Camera())
	left f32 = 80.0
	floorY = f32(h) - 140.0
	for i in 0..16:
		bar = 60.0 + 50.0 * (t * 2.0 + f32(i) * 0.5).sin()
		engine.fillRect(
			r,
			left + f32(i) * 44.0,
			floorY - bar,
			32.0,
			bar,
			engine.rgb8(80 + i * 10, 140, 255 - i * 9)
		)
	r.drawLine(left, floorY + 12.0, left + 16.0 * 44.0, floorY + 12.0, 2.0, engine.white)
	mouse = engine.mousePosition()
	size = 48.0 if engine.isMouseDown(0) else 24.0
	engine.fillRect(
		r,
		f32(mouse.x) - size / 2.0,
		f32(mouse.y) - size / 2.0,
		size,
		size,
		Vec4(1.0, 0.8, 0.2, 0.85)
	)
	r.drawText(s.font, "Hello from Zap", left, 90.0, engine.white)
	engine.drawText(
		r,
		s.small,
		"Vulkan through the RHI: the 2D batch, text, lines. Move the mouse, hold the button.",
		left,
		150.0,
		Vec4(0.7, 0.75, 0.85, 1.0)
	)
	r.endFrame()

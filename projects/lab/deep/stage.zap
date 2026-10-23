# The stage every 3D scene of the lab is drawn on: a multisampled HDR target (light kept above
# 1), resolved into a plain one, its bright parts blurred at half size into a bloom, and the
# picture made of both: exposure, ACES tone mapping, darker corners, the screen's gamma.

import engine
import deep.shaders

pub type Stage:
	width i64
	height i64
	ms engine.RenderTarget   # drawn into, four samples a pixel
	scene engine.RenderTarget   # the samples averaged
	bloom engine.Bloom
	picture engine.ScreenPass
	sky engine.ScreenPass

pub fn newStage(w i64, h i64) Stage:
	Stage(
		width = w,
		height = h,
		ms = engine.newMultisampleTarget(w, h, 4),
		scene = engine.newRenderTarget(w, h, true, false),
		bloom = engine.newBloom(
			w,
			h,
			knee = 0.5,
			spread = 1.0
		), picture = engine.newScreenPass(shader(
			shaders.picturePixel
		)), sky = engine.newScreenPass(shader(shaders.skyPixel)))

# the targets made again for a window of a new size
pub fn fitStage(mut s Stage, w i64, h i64):
	if w == s.width and h == s.height or w < 8 or h < 8: return
	s.ms = engine.newMultisampleTarget(w, h, 4)
	s.scene = engine.newRenderTarget(w, h, true, false)
	s.bloom.fit(w, h)
	s.width = w
	s.height = h

# Begins a scene: the target cleared, the sky drawn behind everything as the camera sees it
# (sunDir toward the sun; `night` 0 day .. 1 a dark sky), depth on.
pub fn beginScene(mut r engine.Renderer, s Stage, cam View, sunDir Vec3, night f32):
	r.useTarget(s.ms)
	r.clearTarget(Vec4(0.0, 0.0, 0.0, 1.0))
	r.setBlending(false)
	r.setDepth(false, false, false)
	r.drawScreenPass(s.sky, shaders.Sky(
		forward = cam.forward,
		right = cam.right,
		up = cam.up,
		spread = Vec2(cam.tanHalf * cam.aspect, cam.tanHalf),
		sun = sunDir, night))
	r.setDepth(true, true, true)

# Ends a scene: the picture made on the window, w x h (exposure: the light's scale; glow: how
# much the bloom adds).
pub fn finishScene(mut r engine.Renderer, s Stage, w i64, h i64, exposure f32, glow f32):
	r.setDepth(false, true, false)
	r.setBlending(false)
	s.ms.resolveTarget(s.scene)
	bloom = r.drawBloom(s.bloom, s.scene.colorTexture())
	r.useScreen()
	engine.drawScreenPass(
		r,
		s.picture,
		shaders.Picture(scene = s.scene.colorTexture(), bloom, exposure, glow)
	)

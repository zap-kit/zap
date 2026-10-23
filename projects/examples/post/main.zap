# Post-processing (engine/post/post.zap) on the backend the environment picks: a disk of HDR light
# drawn into a scene target, its bloom, the picture tone-mapped into the post's picture and
# smoothed (FXAA) onto the screen, read back twice, with the bloom and without it. The disk must
# come out white, the ground dark, and the bloom must light the ground beside the disk (and only
# there: a far corner stays as dark as without it).
#   zap run projects/examples/post/main.zap                (from the repository's root; ZAP_RUN=gpu=d3d12 for Direct3D 12)

import engine
import glow
import image

width = 160
height = 120

# the gray of the pixel read back at x, y
fn grayAt(img image.Image, x i64, y i64) i64:
	img[x, y].r

# one frame of the disk, bloomed by `glowShare`, read back
fn frameOf(
	mut win engine.Window,
	mut r engine.Renderer,
	mut frames engine.Frames,
	scene engine.RenderTarget,
	mut post engine.Post,
	light engine.ScreenPass,
	glowShare f32) image.Image:
		if not win.nextFrame(frames):
			fail("the window closed")
		r.useTarget(scene)
		r.setBlending(false)
		r.setDepth(false, false, false)
		r.drawScreenPass(light, glow.Glow(radius = 0.06))
		bloom = r.drawBloom(post.bloom, scene.colorTexture())
		r.useTarget(post.picture)
		engine.drawTonemap(
			r,
			post,
			scene.colorTexture(),
			bloom,
			exposure = 1.0,
			glow = glowShare,
			vignette = 0.0
		)
		r.drawFxaa(post, win.width, win.height)
		r.beginOverlay(win.width, win.height, engine.Camera())
		r.screenshot()

mut frames = engine.newFrames()
mut win = engine.openWindow("Post-processing", width, height)
mut r = engine.newRenderer()
scene = engine.newRenderTarget(width, height, true, false)
mut post = engine.newPost(width, height)
light = engine.newScreenPass(shader(glow.pixel))
bloomed = win.frameOf(r, frames, scene, post, light, 0.5)
plain = win.frameOf(r, frames, scene, post, light, 0.0)
cx, cy = width / 2, height / 2
# beside the disk: 0.06 of the width is about 10 pixels from the middle, the bloom reaches past it
besideBloomed = bloomed.grayAt(cx + 14, cy)
besidePlain = plain.grayAt(cx + 14, cy)
cornerBloomed = bloomed.grayAt(2, 2)
cornerPlain = plain.grayAt(2, 2)
ok = bloomed.grayAt(cx, cy) > 240 and besideBloomed > besidePlain + 10 and
	(cornerBloomed - cornerPlain).abs() <= 3
print("{engine.backendName()}: disk {bloomed.grayAt(cx, cy)}, beside it {besideBloomed} with bloom and {besidePlain} without, a corner {cornerBloomed} and {cornerPlain}: {"right" if ok else "WRONG"}")
if not ok:
	exit(1)

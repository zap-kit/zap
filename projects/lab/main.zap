# The graphics lab: one window, a scene per key, each a test of the engine and the language.
#   1 Hello      the 2D batch, text, lines
#   2 Plasma     every pixel computed on the CPU, rows on every processor
#   3 Sprites    thousands of sprites bouncing
#   4 Isometric  a 2.5D tile world, depth-sorted props, click to walk
#   5 Materials  physically based spheres, metalness by roughness, the sky they mirror
#   6 Shadows    a 4096 shadow map read sixteen times a pixel, a sun that circles
#   7 Relief     parallax occlusion mapping with self-shadowing
#   8 Lights     hundreds of point lights from a storage block
#   9 Crowd      up to 250 000 cubes in one draw, their places worked out in parallel
#   0 Glow       HDR light far above 1, bloom, a glossy floor
# The 3D scenes are drawn multisampled in HDR and tone mapped; the left button turns their
# camera and the wheel brings it nearer. Tab goes to the next scene, F1 hides the panel, Esc
# ends.
#
#   zap run projects/lab/main.zap
#   zap run projects/lab/main.zap --scene 6 --frames 120 --step 16 --shot shadows.png
#   zap run projects/lab/main.zap --tour 200     (every scene for 200 frames without vsync: its
#                                             speed printed)
#   zap run projects/lab/main.zap --tour 3 --step 16 --shot lab.png     (the last frame of each scene saved as
#                                             lab-<scene>.png)
#   zap test --only size

import deep
import engine
import flat
import image

names = [
	"hello",
	"plasma",
	"sprites",
	"isometric",
	"materials",
	"shadows",
	"relief",
	"lights",
	"crowd",
	"glow"
]
titles = [
	"Hello",
	"Plasma",
	"Sprites",
	"Isometric",
	"Materials",
	"Shadows",
	"Relief",
	"Lights",
	"Crowd",
	"Glow"
]
keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

type Lab:
	hello flat.Hello
	plasma flat.Plasma
	sprites flat.Sprites
	iso flat.Iso
	shaders deep.Shaders
	stage deep.Stage
	materials deep.Materials
	shadows deep.Shadows
	relief deep.Relief
	lights deep.Lights
	crowd deep.Crowd
	glow deep.Glow
	scene i64
	panel bool

mut w = engine.openWindow("Zap graphics lab", 1600, 900)
mut r = engine.newRenderer()
font = engine.loadFont("Segoe UI", 18, 600)
small = engine.loadFont("Segoe UI", 15)
first = ((i64.parse(args.option("--scene") ?? "") ?? 5) + 9) % 10
mut lab = Lab(
	hello = flat.newHello(),
	plasma = flat.newPlasma(),
	sprites = flat.newSprites(w.width, w.height),
	iso = flat.newIso(),
	shaders = deep.newShaders(),
	stage = deep.newStage(w.width, w.height),
	materials = deep.newMaterials(),
	shadows = deep.newShadows(),
	relief = deep.newRelief(),
	lights = deep.newLights(),
	crowd = deep.newCrowd(), glow = deep.newGlow(), scene = first.max(0), panel = true)
tour = i64.parse(args.option("--tour") ?? "") ?? 0
if tour > 0:
	lab.runTour(w, r, font, small, tour)
else:
	lab.run(w, r, font, small)

# the lab at the keyboard's command until Esc, the window closed or a frame limit
fn run(
	mut lab Lab,
	mut w engine.Window,
	mut r engine.Renderer,
	font engine.Font,
	small engine.Font
):
	frames = engine.newFrames()
	while w.nextFrame(frames):
		lab.chooseScene()
		lab.frame(w, r, frames.dt, font, small, frames.clock.fps)
		r.showFrame(w, frames)
	print("{frames.count} frames of {names[lab.scene]}")

# the keys that pick a scene: its number, or Tab for the next; F1 shows or hides the panel
fn chooseScene(mut lab Lab):
	for i in 0..10:
		if engine.isKeyPressed(.Char(keys[i][0])):
			lab.scene = i
	if engine.isKeyPressed(.Tab):
		lab.scene = (lab.scene + 1) % 10
	if engine.isKeyPressed(.F(1)):
		lab.panel = not lab.panel

# one frame of the scene picked: its step, its picture, the panel over it
fn frame(
	mut lab Lab,
	w engine.Window,
	mut r engine.Renderer,
	dt f32,
	font engine.Font,
	small engine.Font,
	fps i64
):
	ww = w.width
	wh = w.height
	lab.stage.fitStage(ww, wh)
	match lab.scene:
		0:
			lab.hello.stepHello(dt)
			lab.hello.drawHello(r, ww, wh)
		1:
			lab.plasma.stepPlasma(dt)
			lab.plasma.drawPlasma(r, ww, wh)
		2:
			lab.sprites.stepSprites(dt, ww, wh)
			lab.sprites.drawSprites(r, ww, wh)
		3:
			lab.iso.stepIso(dt, ww, wh)
			lab.iso.drawIso(r, ww, wh)
		4:
			lab.materials.stepMaterials(dt)
			r.drawMaterials(lab.materials, lab.shaders, lab.stage, ww, wh)
		5:
			lab.shadows.stepShadows(dt)
			r.drawShadows(lab.shadows, lab.shaders, lab.stage, ww, wh)
		6:
			lab.relief.stepRelief(dt)
			r.drawRelief(lab.relief, lab.shaders, lab.stage, ww, wh)
		7:
			lab.lights.stepLights(dt)
			r.drawLights(lab.lights, lab.shaders, lab.stage, ww, wh)
		8:
			lab.crowd.stepCrowd(dt)
			deep.drawCrowd(r, lab.crowd, lab.shaders, lab.stage, ww, wh)
		_:
			lab.glow.stepGlow(dt)
			r.drawGlow(lab.glow, lab.shaders, lab.stage, ww, wh)
	if lab.panel:
		lab.drawPanel(r, ww, wh, font, small, fps)

# the strip of scenes along the top, the scene's own line, the frame rate
fn drawPanel(
	lab Lab,
	mut r engine.Renderer,
	ww i64,
	wh i64,
	font engine.Font,
	small engine.Font,
	fps i64
):
	r.beginOverlay(ww, wh, engine.Camera())
	r.setDepth(false, true, false)
	r.setBlending(true)
	r.fillRect(0.0, 0.0, f32(ww), 64.0, Vec4(0.0, 0.0, 0.0, 0.55))
	x = 14.0
	for i in 0..10:
		label = "{keys[i]} {titles[i]}"
		width = f32(font.textWidth(label))
		if i == lab.scene:
			r.fillRect(x - 6.0, 6.0, width + 12.0, 26.0, Vec4(0.95, 0.75, 0.3, 0.9))
		engine.drawText(
			r,
			font,
			label,
			x,
			9.0,
			Vec4(0.05, 0.05, 0.08, 1.0) if i == lab.scene else Vec4(0.85, 0.87, 0.92, 1.0)
		)
		x += width + 22.0
	frameMs = 1000.0 / fps if fps > 0 else 0.0
	info = "{lab.sceneLine()}    {fps} fps ({(frameMs * 10.0).round() / 10.0} ms)    Tab next, F1 panel, Esc ends"
	r.drawText(small, info, 14.0, 40.0, Vec4(0.75, 0.8, 0.88, 1.0))
	r.endFrame()

# what the scene shows and its own controls
fn sceneLine(lab Lab):
	match lab.scene:
		0: "the 2D batch, text and lines"
		1: "480 x 270 pixels computed each frame on every processor"
		2: "{lab.sprites.spriteCount()} sprites; Space +1000, Backspace -1000"
		3: "click to walk, wheel to zoom, arrows to look around"
		4: "GGX + Smith + Schlick; metalness grows to the right, roughness to the back; drag to turn"
		5: "a 4096 shadow map, 16 taps on a turned disk per pixel; drag to turn"
		6: "parallax occlusion mapping, depth {(lab.relief.reliefDepth() * 100.0).round() / 100.0}; Up and Down change it"
		7: "{lab.lights.lightCount()} point lights from a storage block; Space doubles, Backspace halves"
		8: "{lab.crowd.cubeCount()} cubes in one draw, placed on every processor; Space changes the count"
		_: "HDR emission far above 1, bloom, a glossy floor"

# Every scene in turn for `perScene` frames, without vsync: the frames per second each made
# printed, its last frame saved as `--shot x.png`'s `x-<name>.png` when there is one.
fn runTour(
	mut lab Lab,
	mut w engine.Window,
	mut r engine.Renderer,
	font engine.Font,
	small engine.Font,
	perScene i64
):
	engine.setVsync(false)
	shot = args.option("--shot") ?? ""
	for i in 0..10:
		lab.scene = i
		clock = engine.newClock()
		start = clockSeconds()
		drawn = start
		for n in 0..perScene:
			if not w.pollEvents(): return
			if not w.startFrame(): continue
			dt = clock.tick()
			lab.frame(w, r, dt, font, small, clock.fps)
			if n == perScene - 1 and shot != "":
				drawn = clockSeconds()   # the frames' time, the picture's saving apart
				path = "{shot[..shot.len - 4]}-{names[i]}.png"
				r.screenshot().savePng(path) ?? eprint("cannot write {path}")
			else:
				w.present()
		if shot == "":
			drawn = clockSeconds()
		print("{titles[i]}: {engine.framesText((perScene - 1).max(1), drawn - start)}")

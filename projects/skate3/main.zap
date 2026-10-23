# Skate 3: EA's Skate 3 (Xbox 360) rewritten in Zap on Zap's engine, everything the game shows
# read from the user's own disc image (projects/skate3/disc/*.iso, or --iso), nothing of the game in the
# repository. The first run decodes the district and the skater into projects/skate3/assets/ (prepare.zap
# does the same by hand). It opens in University with the skater standing on his board.
#
#   zap run projects/skate3/main.zap                       the orbit camera: right drag turns, wheel zooms;
#                                                 F flies free (W A S D, Q E, Shift), Esc leaves
#   needs: projects/skate3/assets (made from the disc image by prepare.zap)
#   zap run projects/skate3/main.zap --frames 120 --step 16 --shot university.png
#   zap run projects/skate3/main.zap --at 330,-710         stand somewhere else (x, z)
#   zap run projects/skate3/main.zap --eye 300,150,-650 --look 120,-20     a free camera (degrees)
#   zap run projects/skate3/main.zap --show lightmap      only the lightmaps (or color, or kind)
#   zap run projects/skate3/main.zap --frames 600 --uncapped --frametimes   (the processor's milliseconds a
#                                                 frame, from its start until it is shown)
#   ZAP_RUN=gpu=d3d12 zap run projects/skate3/main.zap    Direct3D 12 instead of Vulkan
#   zap test --only size

import engine
import game
import graphics
import skate
import math

# where the skater stands when the game opens: University's career start (x, z)
startX f32 = 330.0
startZ f32 = -710.0

district = args.option("--district") ?? skate.defaultDistrict
if not skate.isPrepared(district) or args.hasFlag("--prepare"):
	if skate.prepareAll(args.option("--iso"), district) is why:
		fail(why)
started = clockSeconds()
world = skate.loadWorld(skate.districtDir(district)) ??
	fail("{error}: run zap run projects/skate3/prepare.zap")
at = args.optionNumbers("--at").map(f32(it))
x = at[0] if at.len == 2 else startX
z = at[1] if at.len == 2 else startZ
ground = world.collision.groundBelow(x, z, 10000.0) ?? 0.0
print("{district}: {world.batches.len} batches, {world.textures.len} textures, {world.collision.surfaces.len} collision triangles; ground at {ground:.2} ({(clockSeconds() - started):.1} s)")
mut frames = engine.newFrames()
mut win = engine.openWindow("Skate 3 - University", 1280, 720)
skater = skate.loadSkater(skate.skaterFile) ??
	fail("{error}: run zap run projects/skate3/prepare.zap")
mut scene = graphics.newWorldScene(world)
figure = graphics.newSkaterFigure(skater)
heading f32 = 0.6
feet = Vec3(x, ground, z)
mut camera = game.orbitCamera(feet + Vec3(0.0, 1.0, 0.0), -heading - 0.7, 0.18, 3.5)
eye = args.optionNumbers("--eye").map(f32(it))
look = args.optionNumbers("--look").map(f32(it))
if eye.len == 3:
	camera = game.freeCamera(
		Vec3(eye),
		(look[0] if look.len == 2 else 0.0).radians(),
		(look[1] if look.len == 2 else 0.0).radians()
	)
# for checking the decoding: --show lightmap, color or kind
show = match args.option("--show") ?? "":
	"lightmap": 1
	"color": 2
	"kind": 3
	_: 0
mut r = engine.newRenderer()
font = engine.loadFont("Segoe UI", 16)
mut fpsShown = 0
while win.nextFrame(frames):
	camera.steer(frames.dt)
	aspect = f32(win.width) / f32(win.height.max(1))
	r.beginWorld(scene, win.width, win.height)
	projection = game.projectionOf(aspect)
	view = camera.viewOf()
	r.drawWorld(scene, projection, view, camera.eyeOf(), show)
	graphics.drawSkater(
		r, figure,
		scene,
		Mat4.placement(feet, heading),
		projection,
		view,
		camera.eyeOf()
	)
	r.beginOverlay(win.width, win.height, engine.Camera())
	if frames.count % 30 == 0:
		fpsShown = frames.clock.fps
	e = camera.eyeOf()
	label = "University  {e.x:.0}, {e.y:.0}, {e.z:.0}  {fpsShown} fps"
	r.drawLabel(font, label)
	r.showFrame(win, frames)
print(frames.fpsText())
# past the first ten frames (the textures' uploads)
frames.printFrames(skip = 10)

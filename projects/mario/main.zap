# Super Mario 64 rewritten on Zap's engine, its art and levels read from the user's own cartridge
# dump (projects/mario/rom/sm64.us.z64, never committed). Mario runs, jumps and falls through Castle
# Grounds as the game moves him, 30 times a second, drawn at the screen's rate between those
# moments; the camera follows him as Lakitu does.
#
#   zap run projects/mario/main.zap         WASD or arrows move, Space jumps (again on landing: higher),
#                                       Shift crouches (Shift then Space while running: long jump),
#                                       Q and E (or a click and the mouse) turn the camera as C-left
#                                       and C-right do, R zooms it out as C-down, Esc leaves
#   needs: projects/mario/rom/sm64.us.z64 (the cartridge dump, never committed)
#   zap run projects/mario/main.zap --frames 300 --walk --shot mario.png    (he walks and jumps by himself)
#   zap run projects/mario/main.zap --eye -1328,2000,9000 --look 0,-0.3    (a free camera instead)
#   zap run projects/mario/main.zap --bench 600 --eye 0,2500,9000 --focus 0,500,0
#       (the benchmark the PC port's harness runs too: a fixed camera, 600 frames after a warm-up
#       as fast as they go, time, processor cycles and memory printed; --samples 1 draws without
#       multisampling; zap test --only bench measures it against the port)
#   zap run projects/mario/main.zap --bench 2 --samples 1 --eye 0,2500,9000 --focus 0,500,0 --shot static.png
#   zap run projects/mario/main.zap --bench 2 --samples 4 --eye 0,2500,9000 --focus 0,500,0 --shot static4.png
#   zap run projects/mario/main.zap --frames 180 --walk --samples 1 --shot walk.png
#   zap test --only size
#   zap run projects/mario/main.zap --d3d12     (drawn with Direct3D 12 instead of Vulkan, as ZAP_RUN=gpu=d3d12 does)

import engine
import game
import graphics
import n64
import stage
import math

tick f64 = 1.0 / 30.0
# how far the mouse moves for a press of C-left or C-right
mouseTurnStep = 60

# What the game reads from the cartridge: the level, its stage, Mario's animations (the
# cartridge's bytes let go of once read)
fn readCartridge():
	rom, lv = n64.readCastleGrounds()
	st = rom.buildStage(lv)
	anims {i64: n64.Animation} = {}
	for id in game.usedAnimations:
		anims[id] = rom.readAnimation(id)
	(lv, st, anims)

started = clockSeconds()
lv, stageRead, anims = readCartridge()
mut st = stageRead
surfaces = st.ground
mut frames = engine.newFrames()
mut win = engine.openWindow("Super Mario 64 (Zap)", 1280, 960)
mut r = engine.newRenderer()
mut scene = st.newScene(i64.parse(args.option("--samples") ?? "") ?? 4)
hud = st.newHud()
print("Castle Grounds: {st.meshes.len} meshes, {st.instances.len} placed, {surfaces.all.len} surfaces, read in {(clockSeconds() - started):.2} s")
mut mario = game.newMario(
	surfaces,
	f32(lv.marioX),
	f32(lv.marioY),
	f32(lv.marioZ),
	lv.marioYaw * 0x1_0000 / 360
)
mut objects = mario.newGameObjects(st.actors)
# the area's camera (Castle Grounds: GEO_CAMERA(16, ...), free roaming)
mut camera = game.newCamera(game.cameraModeFreeRoam)
# the level's first frame: the objects and Mario run once with no input, and the camera starts
mut pending = game.Controls(
	stickX = 0.0,
	stickY = 0.0,
	aPressed = false,
	aDown = false,
	zPressed = false,
	zDown = false,
	cPressed = 0,
	cDown = 0
)
objects.runTick(mario, surfaces, anims, pending, camera)
mut before = mario.pos
mut cameraBefore = camera
# a free camera, when one is asked for
place = args.optionNumbers("--eye").map(f32(it))
look = args.optionNumbers("--look").map(f32(it))
fixed = args.optionNumbers("--focus").map(f32(it))
still = place.len == 3 and fixed.len == 3
flying = place.len == 3 and not still
mut fly = engine.FlyCamera(
	eye = Vec3(place) if flying else camera.pos,
	yaw = look[0] if look.len == 2 else 0.0,
	pitch = look[1] if look.len == 2
	else -0.1, speed = 1500.0, fastFactor = 4.0, lookSpeed = 0.0025, vertical = false)
walking = args.hasFlag("--walk")
tracing = args.hasFlag("--trace")
mut turn = 0
mut ticks = 0
benchmark = frames.bench >= 0
# a scripted or measured run draws the level's first frame (the port's play frame 0) first and
# takes its next tick on the second
mut clock = -tick if walking or benchmark else 0.0
while win.nextFrame(frames, escEnds = false):
	if engine.isKeyPressed(.Escape):
		if not engine.isMouseCaptured(): break
		win.captureMouse(false)
	motion = IVec2(0, 0)
	if not engine.isMouseCaptured() and engine.isMousePressed(0):
		win.captureMouse(true)
	elif engine.isMouseCaptured():
		motion = engine.mouseMotion()
	if flying:
		fly.steer(frames.dt, motion)
		draw(
			r,
			scene,
			st,
			frames.count,
			anims,
			mario,
			mario.pos,
			fly.eye,
			fly.eye + fly.forward(),
			win
		)
		r.drawHud(hud, win.width, win.height, 4, 0)
		r.showFrame(win, frames)
		continue
	# the controls as the frames between ticks leave them: a press is kept for the next tick
	turn += motion.x
	if engine.isKeyPressed(.Char('Q')) or turn <= -mouseTurnStep:
		pending.cPressed |= game.cButtonLeft
		turn = 0
	if engine.isKeyPressed(.Char('E')) or turn >= mouseTurnStep:
		pending.cPressed |= game.cButtonRight
		turn = 0
	if engine.isKeyPressed(.Char('R')):
		pending.cPressed |= game.cButtonDown
	pending.cDown = (game.cButtonLeft if engine.isKeyDown(.Char('Q')) else 0) | (
		game.cButtonRight if engine.isKeyDown(.Char('E')) else 0
	) |
		(game.cButtonDown if engine.isKeyDown(.Char('R')) else 0)
	pending.stickX = (
		engine.keyAxis(.Char('D'), .Char('A')) + engine.keyAxis(.Right, .Left)
	).clamp(-1.0, 1.0) *
		64.0
	pending.stickY = (
		engine.keyAxis(.Char('W'), .Char('S')) + engine.keyAxis(.Up, .Down)
	).clamp(-1.0, 1.0) *
		64.0
	pending.aDown = engine.isKeyDown(.Space)
	pending.aPressed = pending.aPressed or engine.isKeyPressed(.Space)
	pending.zDown = engine.isKeyDown(.Shift)
	pending.zPressed = pending.zPressed or engine.isKeyPressed(.Shift)
	if walking:
		pending.stickY = 64.0
		pending.aDown = ticks % 40 < 10
		pending.aPressed = ticks % 40 == 0
	# the game's ticks that fit in the time passed (a scripted or measured run takes one a frame)
	clock += tick if walking or benchmark else f64(frames.dt)
	while clock >= tick:
		clock -= tick
		before = mario.pos
		cameraBefore = camera
		objects.runTick(mario, surfaces, anims, pending, camera)
		pending.aPressed = false
		pending.zPressed = false
		pending.cPressed = 0
		if tracing:
			traceTick(ticks, mario, camera)
		ticks += 1
	# drawn between the last two ticks
	k = f32(clock / tick)
	at = before + (mario.pos - before) * k
	from = cameraBefore.pos + (camera.pos - cameraBefore.pos) * k
	toward = cameraBefore.focus + (camera.focus - cameraBefore.focus) * k
	if still:
		draw(
			r,
			scene,
			st,
			ticks + 1,
			anims,
			mario,
			at,
			Vec3(place),
			Vec3(fixed),
			win
		)
	else:
		draw(r, scene, st, ticks + 1, anims, mario, at, from, toward, win)
	r.drawHud(hud, win.width, win.height, 4, 0)
	r.showFrame(win, frames)
if benchmark:
	print("bench: mario at {mario.pos.x:.1} {mario.pos.y:.1} {mario.pos.z:.1} yaw {mario.faceYaw} action {mario.action} forward {mario.forwardVel:.2}")

# One of the game's frames (play_mode_normal): the objects up to Mario (their meeting, the poles'
# pushes), Mario, then the camera.
fn runTick(
	mut objects game.Objects,
	mut mario game.Mario,
	surfaces game.Surfaces,
	anims {i64: n64.Animation},
	pending game.Controls,
	mut camera game.Camera):
		objects.updateObjects(mario)
		mario.stepMario(surfaces, anims, pending, camera, objects)
		camera.updateCamera(mario, surfaces, pending)

# Mario's and the camera's state after a tick, beside the port's BENCH_TRACE
fn traceTick(ticks i64, m game.Mario, c game.Camera):
	print("tick {ticks} pos {m.pos.x:.2} {m.pos.y:.2} {m.pos.z:.2} forward {m.forwardVel:.2} yaw {m.faceYaw} action {m.action} camera {c.yaw} vel {m.vel.x:.2} {m.vel.y:.2} {m.vel.z:.2} pitch {m.facePitch} water {m.waterLevel} timer {m.actionTimer} state {m.actionState} floor {m.floorHeight:.2} goal {c.goalPos.x:.2} {c.goalPos.y:.2} {c.goalPos.z:.2} gfocus {c.goalFocus.x:.2} {c.goalFocus.y:.2} {c.goalFocus.z:.2} lpos {c.pos.x:.2} {c.pos.y:.2} {c.pos.z:.2} lfocus {c.focus.x:.2} {c.focus.y:.2} {c.focus.z:.2} mode {c.mode} nextyaw {c.nextYaw} anim {m.anim} {m.animFrame}")

# the frame: the scene seen from `eye` toward `focus`, Mario at `at` in his animation's pose
fn draw(
	mut r engine.Renderer,
	mut scene graphics.Scene,
	st stage.Stage,
	frames i64,
	anims {i64: n64.Animation},
	mario game.Mario,
	at Vec3,
	eye Vec3,
	focus Vec3,
	win engine.Window
):
	forward = (focus - eye).normalized()
	aspect = f32(win.width) / f32(win.height.max(1))
	placed = n64.rotateZxyTranslate(at + Vec3(0.0, mario.drawLift, 0.0), Vec3(
		f32(mario.drawPitch) * 360.0 / 65536.0,
		f32(mario.drawYaw) * 360.0 / 65536.0, f32(mario.drawRoll) * 360.0 / 65536.0))
	parts = []
	match anims.get(mario.anim):
		a: parts = n64.pose(st.rig, a, mario.animFrame)
		none: parts = n64.pose(
			st.rig,
			anims.get(game.animIdleHeadCenter) ?? fail("no idle animation"),
			0
		)
	graphics.drawScene(
		r,
		scene,
		st,
		frames,
		Mat4.perspective(45.0 * pi / 180.0, aspect, 50.0, 40000.0),
		Mat4.lookAlong(eye, forward),
		forward,
		win.width,
		win.height,
		placed,
		parts)

# The cell run without a window as the game runs it (its actors at their packages, its physics,
# the player standing at the door, walking ahead for a while), its sounds mixed offline by the
# engine's mixer: what a tool prints and a test checks.

import engine.audio
import game
import world
import engine.physics

pub mixRate = 48_000
frameSeconds f32 = 0.016
timeScale f32 = 20.0   # the game's default: 20 game seconds a real one

pub type SceneRun:
	sound Scene
	mix f32[]   # the stereo frames heard, at mixRate
	steps i64   # the player's footsteps heard

# the input of a frame: walking ahead while `walking`
fn inputOf(walking bool):
	game.Input(forward = 1.0 if walking else 0.0, right = 0.0, run = false, look = IVec2(0, 0))

# The cell `cellId` (prepared first when it is not) run `seconds` from the game hour, the player
# walking ahead from `walkFrom` to `walkTo` seconds, the actors greeting him when `hellos`; why
# when the install cannot give its sounds.
pub fn runScene(
	dir str,
	cellId str,
	hour f32,
	seconds f32,
	walkFrom f32,
	walkTo f32,
	hellos bool
) SceneRun ? str:
	light = game.Load(dir.copy(), textures = false)
	if game.openPrepared(cellId, light) == none: game.prepareCell(dir, cellId)
	cell = game.openPrepared(cellId, light) ?? return "the prepared {cellId} cannot be read"
	cast = cell.head.cast
	rigs = cast.skeletons.map(.skeletonRig())
	speeds = cast.skeletons.map(.speeds.copy())
	rs = cast.newResidents(rigs, speeds, hour, light)
	player = cast.start.newPlayer(cast.heading, rs.gaits[0])
	follow = game.newFollow(player.heading)
	audio.startOffline(mixRate)
	walker = rs.graph.newWalker(true)
	s = try openScene(dir, cellId, cast, rs.clipNames, cell.physics, hour, hellos)
	evaluate {i64: bool} = {}
	mix = []
	at = hour
	for f in 0..i64(seconds / frameSeconds):
		t = f32(f) * frameSeconds
		player.steerPlayer(inputOf(t >= walkFrom and t < walkTo), follow.headingOf(),
			cell.physics.world, frameSeconds)
		follow.followFeet(player.feetOf(), cell.physics.world.scene)
		rs.stepResidents(cast, at, timeScale, evaluate, player.feetOf(), cell.physics.world,
			frameSeconds)
		cell.physics.world.step(frameSeconds)
		eye = follow.eyeOf().skyrimPoint()
		walker.stepWalker(
			rs.graph,
			rs.lengths[0],
			player.feetOf(),
			player.heading,
			true,
			frameSeconds
		)
		s.stepScene(
			player,
			walker,
			rs,
			cast,
			cell.physics.world,
			eye,
			follow.headingOf(),
			frameSeconds
		)
		mix.extend(audio.renderOffline(i64(frameSeconds * f32(mixRate))))
		at += frameSeconds * timeScale / 3600.0
	steps = s.book.log.count(.why.startsWith("the player Foot"))
	SceneRun(sound = s, mix, steps)

# The loudness of the mix by windows of `seconds`: each window's root mean square over both sides.
pub fn loudness(mix f32[], seconds f32) f32[]:
	window = i64(seconds * f32(mixRate)) * 2
	out = []
	at = 0
	while at < mix.len:
		end = (at + window).min(mix.len)
		sum = 0.0
		for k in at..end:
			sum += f64(mix[k]) * f64(mix[k])
		out.push(f32((sum / (end - at).max(1)).sqrt()))
		at = end
	out

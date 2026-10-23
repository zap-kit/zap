# The player moved as Skyrim's third person moves him: the keys ask for a way relative to the
# camera, the body turns toward it (smoothly, a whole turn a second) and goes the way it faces,
# as fast as its clip's motion carries it (walking, or running while Shift is held; sneaking, the
# sneak walk's and the sneak run's, 47 and 133 units a second in the files), the
# controller's capsule keeping it on the floor and off the walls. The pose eases from standing to
# walking to running, the walk and the run kept in step through one shared cycle.

import engine
import engine.gltf
import math
import engine.physics

turnSpeed f32 = 2.0 * pi   # radians a second the body turns
gaitEase f32 = 4.0   # gaits a second the pose eases by: a quarter second from one to the next
# how far into its cycle the run's feet are where the walk's are at the start of its own: the
# blend of the two sinks a foot least (2 units) there
runPhase f32 = 0.65
# Skyrim's speeds for a clip whose motion the files do not give, units a second
walkSpeedDefault f32 = 110.0
runSpeedDefault f32 = 375.0
# the speeds of mt_sneakforward's cousins in the behavior project's motion files (SneakWalk_Forward
# and SneakRun_Forward), for a rig that lacks their clips
sneakWalkSpeedDefault f32 = 47.2
sneakRunSpeedDefault f32 = 132.9
pub sneakWalkClip = "sneakwalk_forward"
pub sneakRunClip = "sneakrun_forward"

# the clips the player is posed by, and how fast each carries him
pub type Gaits:
	idle i64
	walk i64
	run i64
	walkSpeed f32
	runSpeed f32
	walkDuration f32
	runDuration f32
	idleDuration f32
	sneakWalk i64 = -1   # the clips the gaits are while sneaking, -1 for a rig without them
	sneakRun i64 = -1
	sneakWalkSpeed f32 = sneakWalkSpeedDefault
	sneakRunSpeed f32 = sneakRunSpeedDefault
	sneakWalkDuration f32 = 1.0
	sneakRunDuration f32 = 1.0

pub type Player:
	controller physics.Character
	heading f32   # the way the body faces: radians from north (+y) toward east (+x)
	gaits Gaits
	gait f32 = 0.0   # 0 standing, 1 walking, 2 running; eased toward what the keys ask
	cycle f32 = 0.0   # how far through the walk's and the run's cycle (0..1)
	sneaking bool = false   # the sneak gaits carry it
	idleTime f32 = 0.0

fn speedOr(speeds f32[], clip i64, otherwise f32):
	speeds[clip] if clip >= 0 and clip < speeds.len and speeds[clip] > 0.0 else otherwise

fn durationOf(clips gltf.Clip[], clip i64):
	clips[clip].duration.max(0.1) if clip >= 0 else 1.0

# the gaits of a body whose clips (the rig's) carry it at `speeds` (by clip)
pub fn gaitsOf(clips gltf.Clip[], speeds f32[]) Gaits:
	i = clips.findIndex(.name == idleClip) ?? -1
	w = clips.findIndex(.name == walkClip) ?? -1
	r = clips.findIndex(.name == runClip) ?? -1
	sw = clips.findIndex(.name == sneakWalkClip) ?? -1
	sr = clips.findIndex(.name == sneakRunClip) ?? -1
	Gaits(
		idle = i,
		walk = w,
		run = r,
		walkSpeed = speeds.speedOr(w, walkSpeedDefault),
		runSpeed = speeds.speedOr(r, runSpeedDefault),
		walkDuration = clips.durationOf(w),
		runDuration = clips.durationOf(r),
		idleDuration = clips.durationOf(i),
		sneakWalk = sw,
		sneakRun = sr,
		sneakWalkSpeed = speeds.speedOr(sw, sneakWalkSpeedDefault),
		sneakRunSpeed = speeds.speedOr(sr, sneakRunSpeedDefault),
		sneakWalkDuration = clips.durationOf(sw),
		sneakRunDuration = clips.durationOf(sr)
	)

# the player standing at `feet` (Skyrim's units, Z up) facing `heading`
pub fn newPlayer(feet Vec3, heading f32, gaits Gaits) Player:
	Player(controller = feet.playerController(), heading, gaits)

# how fast the body moves now, units a second
pub fn speedOf(p Player) f32:
	p.gaitsNow().speedAt(p.gait)

# the gaits the player is moving by: the sneak walk and run in place of the walk and run while he
# sneaks (the idle stays)
pub fn gaitsNow(p Player) Gaits:
	if not p.sneaking: return p.gaits.copy()
	g = p.gaits.copy()
	if g.sneakWalk >= 0:
		g.walk = g.sneakWalk
		g.walkDuration = g.sneakWalkDuration
	if g.sneakRun >= 0:
		g.run = g.sneakRun
		g.runDuration = g.sneakRunDuration
	g.walkSpeed = g.sneakWalkSpeed
	g.runSpeed = g.sneakRunSpeed
	g

# how fast the gait carries the player, units a second
fn speedAt(g Gaits, gait f32) f32:
	if gait <= 1.0: return g.walkSpeed * gait
	g.walkSpeed.lerp(g.runSpeed, gait - 1.0)

# the cycles a second of the gait's clip, the walk's below a walk
fn cycleRate(g Gaits, gait f32) f32:
	(1.0 / g.walkDuration).lerp(1.0 / g.runDuration, (gait - 1.0).clamp(0.0, 1.0))

# the way the body faces as a direction (Z up)
pub fn facing(heading f32) Vec3:
	Vec3(heading.sin(), heading.cos(), 0)

# The frame's input applied over dt: the body turned toward the way asked (`cameraHeading` the
# way the camera looks), the gait eased, the cycle advanced, the capsule moved through the world.
pub fn steerPlayer(mut p Player, i Input, cameraHeading f32, mut w physics.World, dt f32):
	asked = Vec2(i.right, i.forward)
	moving = asked.length() > 0.0
	if moving:
		wanted = cameraHeading + asked.x.atan2(asked.y)
		p.heading = math.turnToward(p.heading, wanted, turnSpeed * dt)
	goal = 0.0
	if moving: goal = 2.0 if i.run else 1.0
	p.advanceGait(goal, dt)
	velocity = facing(p.heading) * p.gaitsNow().speedAt(p.gait)
	p.controller.walk(w, velocity, dt)

# the gait eased toward `goal` (0 standing, 1 walking, 2 running) and its cycle advanced over dt
pub fn advanceGait(mut p Player, goal f32, dt f32):
	step = gaitEase * dt
	p.gait += (goal - p.gait).clamp(-step, step)
	p.cycle = (p.cycle + p.gaitsNow().cycleRate(p.gait) * dt).fract()
	p.idleTime = (p.idleTime + dt) % p.gaits.idleDuration

# the pose the gait shows: the idle eased into the walk, or the walk into the run, in step
pub fn poseOf(p Player) engine.Pose:
	g = p.gaitsNow()
	walkTime = p.cycle * g.walkDuration
	if p.gait <= 1.0:
		return engine.Pose(clip = g.walk, time = walkTime, from = g.idle, fromTime = p.idleTime,
			blend = p.gait)
	engine.Pose(clip = g.run, time = (p.cycle + runPhase).fract() * g.runDuration, from = g.walk,
		fromTime = walkTime, blend = p.gait - 1.0)

# where the feet stand (Skyrim's units, Z up)
pub fn feetOf(p Player) Vec3:
	p.controller.feet

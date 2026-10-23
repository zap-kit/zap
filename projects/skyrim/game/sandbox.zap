# A sandbox package as the game runs it: within the radius of its place the actor picks what to
# do among what the package's inputs allow, a free marker (a seat when sitting is allowed, a bed
# when sleeping is, special furniture when that is, a lean or an idle marker when idle markers
# are) or standing where it is; walks there over the navmesh (A* and the funnel, the controller
# keeping it off the walls), stands at the marker facing its heading, plays the marker's way in,
# stays the dwell the plugin's settings give (fSandboxDurationBase game hours, times the
# furniture's or the idle marker's multiple; an idle marker no less than its own timer), plays the
# way out and picks again.

import engine
import engine.physics
import skyrim.actor
import world

reached f32 = 12.0   # how near a point of its path the actor comes before it heads for the next
stuckAfter f32 = 3.0   # seconds walking without coming nearer before the actor gives up
arrival f32 = 64.0   # how near its package's place an actor stands to be there
# the kinds of marker that are furniture (the others idle markers)
furnitureKinds = ["chair", "bed", "leantable", "counter"]

# whether the package lets the actor use the marker
fn allows(p world.PlanHead, m world.MarkerHead):
	if m.special: return p.special
	match m.kind:
		"chair": p.sitting
		"bed": p.sleeping
		_: p.idleMarkers

# The markers a sandbox package lets its actor use: allowed by its inputs, within the radius of
# its place.
pub fn usableMarkers(markers world.MarkerHead[], p world.PlanHead) i64[]:
	(0..markers.len).filter(p.allows(markers[it]) and
			(markers[it].position - p.center).length() <= p.radius)

# the markers the actor may pick: usable, free, and with the clips its skeleton plays there
fn choices(rs Residents, cast world.CastHead, k i64, p world.PlanHead):
	out = []
	for i in cast.markers.usableMarkers(p):
		m = cast.markers[i]
		if (rs.taken.get(i) ?? k) != k: continue
		set = rs.sets[rs.all[k].skeleton].find(.kind == m.kind) ?? continue
		if set.looping < 0: continue
		out.push(i)
	out

# seconds the actor stays at the marker (-1: standing)
fn dwellAt(cast world.CastHead, m i64, timeScale f32):
	a = cast.ai
	if m < 0: return realSeconds(a.dwellBase, timeScale)
	marker = cast.markers[m]
	if marker.kind in furnitureKinds: return realSeconds(a.dwellBase * a.dwellFurniture, timeScale)
	realSeconds(a.dwellBase * a.dwellIdleMarker, timeScale).max(marker.dwell)

fn standFor(mut rs Residents, k i64, seconds f32):
	rs.all[k].doing = .Standing
	rs.all[k].clock = 0.0
	rs.all[k].until = seconds

# What the actor does next: a marker it may pick, at random, walked to over the navmesh; else
# standing a while. Whether it picked a marker.
fn choose(mut rs Residents, cast world.CastHead, k i64, timeScale f32):
	rs.free(k)
	p = cast.npcs[rs.all[k].npc].plans[rs.all[k].plan]
	options = rs.choices(cast, k, p)
	pick = rs.dice.nextInt(0, options.len + 1)
	if pick >= options.len:
		rs.standFor(k, cast.dwellAt(-1, timeScale))
		return false
	m = options[pick]
	rs.all[k].marker = m
	behind = (cast.markers[m].entries & 3) == 2
	rs.all[k].using = chairBehind if behind and cast.markers[m].kind == "chair"
		else cast.markers[m].kind.copy()
	rs.all[k].graphDriven = not rs.setOf(rs.all[k]).enterEvents.isEmpty
	at, _ = rs.entryOf(cast, k)
	if not rs.walkTo(cast, k, at):
		rs.all[k].marker = -1
		rs.standFor(k, cast.dwellAt(-1, timeScale))
		return false
	rs.taken[m] = k
	true

# the actor set walking over the navmesh to `to`; whether a path joins them
fn walkTo(mut rs Residents, cast world.CastHead, k i64, to Vec3):
	path = cast.navmesh.findPath(rs.all[k].body.feetOf(), to, rs.all[k].body.controller.radius) ??
		[]
	if path.len < 2: return false
	rs.all[k].crossings = rs.crossingsOf(cast, path)
	rs.all[k].path = path
	rs.all[k].along = 1
	rs.all[k].doing = .Walking
	rs.all[k].clock = 0.0
	rs.all[k].progress = 0.0
	rs.all[k].nearest = 1.0e9
	true

# where the actor sits, sleeps or stands at its marker: the marker's place on the floor under it
fn seatOf(cast world.CastHead, m world.MarkerHead):
	_, floor = cast.navmesh.nearestPoint(m.position)
	Vec3(m.position.x, m.position.y, floor.z)

# v (x right, y forward, the actor's space) as the world's for an actor facing `heading`
fn turnedTo(v Vec3, heading f32):
	right = Vec3(heading.cos(), -heading.sin(), 0.0)
	forward = Vec3(heading.sin(), heading.cos(), 0.0)
	right * v.x + forward * v.y

# how the marker's way in carries the actor: its clip's motion (the behavior's)
fn enterMotion(rs Residents, k i64):
	r = rs.all[k]
	rs.motionOf(r.skeleton, rs.setOf(r).enter)

fn leaveMotion(rs Residents, k i64):
	r = rs.all[k]
	rs.motionOf(r.skeleton, rs.setOf(r).leave)

# Where the actor starts the marker's way in and the way it faces there: back along the motion
# the way in carries it, so that it ends at the marker facing its heading.
fn entryOf(rs Residents, cast world.CastHead, k i64):
	m = cast.markers[rs.all[k].marker]
	motion = rs.enterMotion(k)
	start = m.heading - motion.turnedBy(motion.duration)
	(cast.seatOf(m) - motion.movedBy(motion.duration).turnedTo(start), start)

# the actor `t` seconds into a motion from `origin` facing `heading`
fn carriedBy(mut rs Residents, k i64, motion actor.Motion, origin Vec3, heading f32, t f32):
	rs.all[k].body.controller.feet = origin + motion.movedBy(t).turnedTo(heading)
	rs.all[k].body.heading = heading + motion.turnedBy(t)

# What the actor does when the cell loads: what it picks, found already at it (a marker's loop,
# some way into its dwell).
fn settle(mut rs Residents, cast world.CastHead, k i64):
	if not rs.choose(cast, k, 20.0): return
	m = cast.markers[rs.all[k].marker]
	rs.all[k].body.controller.feet = cast.seatOf(m)
	rs.all[k].body.heading = m.heading
	rs.all[k].doing = .Using
	rs.all[k].until = cast.dwellAt(rs.all[k].marker, 20.0) * f32(rs.dice.nextFloat(0.2, 1.0))
	rs.all[k].clock = 0.0
	rs.runIn(k)

fn still():
	Input(forward = 0.0, right = 0.0, run = false, look = IVec2(0, 0))

# a step along the path: toward its next point, on to the one after once near, at its end the
# marker's way in; a walk that stops coming nearer gives up
fn walkAlong(mut rs Residents, cast world.CastHead, k i64, timeScale f32, mut w physics.World,
	dt f32):
	rs.watchDoors(cast, k, w)
	r = rs.all[k].copy()
	feet = r.body.feetOf()
	target = r.path[r.along]
	to = Vec3(target.x - feet.x, target.y - feet.y, 0.0)
	if to.length() < reached:
		rs.all[k].along += 1
		rs.all[k].nearest = 1.0e9
		rs.all[k].progress = 0.0
		if rs.all[k].along < r.path.len: return
		if r.marker < 0:
			rs.standFor(k, 0.0 if r.exit != 0 else cast.dwellAt(-1, timeScale))
			return
		_, heading = rs.entryOf(cast, k)
		rs.all[k].body.controller.feet = target
		rs.all[k].body.heading = heading
		rs.all[k].doing = .Entering
		rs.all[k].clock = 0.0
		rs.sendMarkerEvent(k, true)
		return
	if to.length() < r.nearest - 1.0:
		rs.all[k].nearest = to.length()
		rs.all[k].progress = 0.0
	rs.all[k].progress += dt
	if rs.all[k].progress > stuckAfter:
		rs.free(k)
		rs.standFor(k, cast.dwellAt(-1, timeScale))
		return
	ahead = Input(forward = 1.0, right = 0.0, run = false, look = IVec2(0, 0))
	rs.all[k].body.steerPlayer(ahead, to.x.atan2(to.y), w, dt)

# The actor's frame of what it does: standing until its dwell ends (a sandbox then picks again),
# walking its path, a marker's way in, loop and way out.
fn act(mut rs Residents, cast world.CastHead, k i64, timeScale f32, mut w physics.World, dt f32):
	r = rs.all[k].copy()
	if r.plan < 0: return rs.all[k].body.steerPlayer(still(), r.body.heading, w, dt)
	p = cast.npcs[r.npc].plans[r.plan]
	rs.all[k].clock += dt
	clock = rs.all[k].clock
	set = rs.setOf(r)
	if r.doing == .Standing:
		rs.all[k].body.steerPlayer(still(), r.body.heading, w, dt)
		if clock < r.until: return
		if r.exit != 0:
			rs.leaveByDoor(cast, k)
			return
		away = (r.body.feetOf() - p.center).length() > p.radius.max(arrival)
		if away and rs.walkTo(cast, k, p.center): return
		if p.isSandbox():
			rs.choose(cast, k, timeScale)
		else:
			rs.standFor(k, cast.dwellAt(-1, timeScale))
	elif r.doing == .Walking:
		rs.walkAlong(cast, k, timeScale, w, dt)
	elif r.doing == .Entering:
		at, heading = rs.entryOf(cast, k)
		motion = rs.enterMotion(k)
		rs.carriedBy(k, motion, at, heading, clock)
		if clock >= rs.clipLength(r.skeleton, set.enter):
			rs.all[k].doing = .Using
			rs.all[k].clock = 0.0
			rs.all[k].until = cast.dwellAt(r.marker, timeScale)
	elif r.doing == .Using:
		if clock >= r.until:
			rs.all[k].doing = .Leaving
			rs.all[k].clock = 0.0
			rs.sendMarkerEvent(k, false)
	else:
		m = cast.markers[r.marker]
		rs.carriedBy(k, rs.leaveMotion(k), cast.seatOf(m), m.heading, clock)
		if clock >= rs.clipLength(r.skeleton, set.leave):
			rs.free(k)
			rs.standFor(k, 0.0)

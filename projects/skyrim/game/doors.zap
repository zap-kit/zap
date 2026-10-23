# The doors on an actor's way, as SkyrimSE.exe 1.7.104 has them. The pathing system cuts every
# loaded door into the navmesh ("Add Door %08x", bCutDoors:Pathfinding), so a path through a closed
# door carries it as a point (a PathingDoor, 0x1404e1d00 names its reference), and the actor that
# reaches that point sends itself MovementMessageActivateDoor: its handler, Actor 0x1406a81d0,
# activates the door with TESObjectREFR::Activate (0x1402f11b0) unless it is the door the actor
# last went through (the high process's +0xd8, which only a teleport door's action sets); for a
# door that is no teleport (TESObjectDOOR::Activate 0x140283210) that is the toggle of
# 0x1401d9590: the Open sequence plays on a closed door, and a locked one stays shut for an actor
# without its key. Nothing in the AI plays Close: an open door cuts nothing, so no path names it,
# and an actor that opens a door leaves it open.
#
# When a door is activated by anyone but the player (0x140283f00) every actor in the process
# lists whose mover heads for that door and stands within fDistanceAutomaticallyActivateDoor
# (250) of it is taken to have been through it (0x140786780: its +0xd8 set to the door, so its
# own message ends at the first test), which is how two actors at one door do not shut it on each
# other; the GMST has no other reader. The detection of doors by a phantom box ahead of the
# actor, every fINIDetectDoorsForPathingTime (0.5 s) times a random scale (0x1407029e0), finds
# the door and discards it: the tail call takes the actor alone.
#
# Not read: the distance at which the follower sends the message (here the actor's radius, the
# leaf's half thickness and the distance it counts as having reached a point), and the lock rule
# (the plugin's lock is not in the cast's doors, so all open).

import engine
import engine.physics
import game.sim
import world

activateDoorWithin f32 = 250.0
# a closed leaf's half thickness: the door collision's y extent (the farmhouse doors' ±9)
doorTouch f32 = 9.0

# an actor (its NpcHead in the cast) that opened a door (its index in the cast's)
pub type DoorUse:
	npc i64
	door i64

# a door an actor opened and where it stands, for its sound
pub type DoorOpening:
	refId i64
	base i64
	at Vec3

# a closed door a path goes through: its index in the cast's, and the point of the path
pub type DoorCrossing:
	door i64
	at Vec3

# Where the segment a-b meets the segment c-d in the floor plane, none when they do not meet or
# run parallel.
fn meetPoint(a Vec3, b Vec3, c Vec3, d Vec3) Vec3?:
	r = b - a
	s = d - c
	denominator = r.x * s.y - r.y * s.x
	if denominator.abs() < 1.0e-6: return none
	q = c - a
	t = (q.x * s.y - q.y * s.x) / denominator
	u = (q.x * r.y - q.y * r.x) / denominator
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0: return none
	a + r * t

# a closed leaf as the segment it stands on: the door's origin and its width along its x
fn leafOf(door world.DoorHead):
	across = Vec3(door.heading.cos(), -door.heading.sin(), 0.0) * door.halfWidth
	(door.position - across, door.position + across)

# the closed doors the path goes through, in the order it does
pub fn crossingsOf(rs Residents, cast world.CastHead, path Vec3[]) DoorCrossing[]:
	out DoorCrossing[] = []
	for leg in 0..(path.len - 1).max(0):
		found = []
		for d, door in cast.doors:
			if door.teleports or rs.doorsOpen.get(door.refId) != none: continue
			if out.any(.door == d): continue
			c, e = door.leafOf()
			if path[leg].meetPoint(path[leg + 1], c, e) is at: found.push(DoorCrossing(d, at))
		while not found.isEmpty:
			first = 0
			for i in 1..found.len:
				if (found[i].at - path[leg]).length() < (found[first].at - path[leg]).length():
					first = i
			out.push(found.remove(first))
	out

# how near a crossing the actor sends its message: its radius, the leaf's thickness and the
# distance it counts as at a point of its path
fn doorReach(r Resident):
	r.body.controller.radius + doorTouch + reached

# The door the actor opens as it activates it: out of the actors' paths and the physics world's
# bodies, queued for the world to activate; the actors near it taken to have been through it.
fn openDoor(mut rs Residents, cast world.CastHead, k i64, d i64):
	door = cast.doors[d]
	if rs.doorsOpen.get(door.refId) != none: return
	rs.doorsOpen[door.refId] = true
	rs.doorsToClear.push(door.refId)
	rs.doorUses.push(DoorUse(rs.all[k].npc, d))
	for j in 0..rs.all.len:
		if (rs.all[j].body.feetOf() - door.position).length() <= activateDoorWithin:
			rs.all[j].crossings = rs.all[j].crossings.filter(.door != d)

# The actor's frame of walking its path: reaching the point of the next closed door on it, it
# activates the door (queued for the world); a door another opened by then is open, and its
# path no longer names it.
pub fn watchDoors(mut rs Residents, cast world.CastHead, k i64, mut w physics.World):
	rs.clearOpened(w)
	r = rs.all[k]
	if r.crossings.isEmpty: return
	c = r.crossings[0]
	feet = r.body.feetOf()
	if (Vec3(feet.x, feet.y, 0.0) - Vec3(c.at.x, c.at.y, 0.0)).length() > r.doorReach(): return
	rs.all[k].crossings = r.crossings[1..].copy()
	rs.openDoor(cast, k, c.door)
	rs.clearOpened(w)

# The doors an actor opened leave the physics world's bodies.
pub fn clearOpened(mut rs Residents, mut w physics.World):
	for refId in rs.doorsToClear:
		w.scene.removeGroup(refId)
	rs.doorsToClear = []

# An actor taken from one place to another by the time skip passes the doors on its way as it
# would walking: the closed ones on the navmesh path are opened.
pub fn openAlong(mut rs Residents, cast world.CastHead, k i64, from Vec3, to Vec3):
	path = cast.navmesh.findPath(from, to, rs.all[k].body.controller.radius) ?? return
	for c in rs.crossingsOf(cast, path):
		rs.openDoor(cast, k, c.door)

# The doors the actors opened handed to the world: each activated by its actor, unless it already
# stands open; those that opened now, for their sound.
pub fn applyDoorUses(mut rs Residents, cast world.CastHead, mut w sim.GameWorld) DoorOpening[]:
	out = []
	for u in rs.doorUses:
		door = cast.doors[u.door]
		if (w.forms.get(door.refId) ?? continue).open: continue
		if w.activate(door.refId, cast.npcs[u.npc].worldRefOf(w)) is DoorMoved(open, _):
			if open: out.push(DoorOpening(door.refId, door.base, door.position))
	rs.doorUses = []
	out

# The doors that stand open in the world (a save's, or the plugin's) known open to the actors, their
# collision out of the physics world.
pub fn syncDoors(mut rs Residents, cast world.CastHead, w sim.GameWorld, mut bodies physics.World):
	for door in cast.doors:
		if door.teleports or not (w.forms.get(door.refId) ?? continue).open: continue
		rs.doorsOpen[door.refId] = true
		bodies.scene.removeGroup(door.refId)

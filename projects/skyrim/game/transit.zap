# Residents going from cell to cell through load doors: an actor whose package puts it in another
# cell walks to the door that leads there and is gone through it (the cell it leads to takes it
# from `departed`); one whose package brings it here appears at the door it came through, after
# the walk the cells before this one took, then walks on to its place.

import world
import engine

# how near its door an actor goes through it
exitReach f32 = 110.0

# the load door of this cell the actor's package number `plan` sends it through, 0 for none
fn exitDoorOf(rs Residents, n world.NpcHead, plan i64):
	if rs.town is town and town.exitDoor(rs.cellId, n.formId, plan) is door: return door.refId
	0

# The actor is to come into this cell for its package number `plan` after package `was`: when it
# was in another cell it is away until its walk reaches the door it comes through.
fn awaitArrival(mut rs Residents, n world.NpcHead, was i64, plan i64, k i64):
	if rs.town is town and town.comingFrom(rs.cellId, n.formId, was, plan) is c:
		rs.all[k].arrival = c.at.copy()
		rs.all[k].arriveIn = c.seconds
		rs.all[k].present = false

# a frame of the walk before the door: at its end the actor appears there and heads for its place
fn stepArrival(mut rs Residents, k i64, dt f32):
	rs.all[k].arriveIn -= dt
	if rs.all[k].arriveIn > 0.0: return
	if rs.all[k].arrival is spot:
		rs.all[k].body.controller.feet = spot.at
		rs.all[k].body.heading = spot.heading
	rs.all[k].arrival = none
	rs.all[k].present = true
	rs.all[k].doing = .Standing
	rs.all[k].clock = 0.0
	rs.all[k].until = 0.0

# the actor gone through its door
fn depart(mut rs Residents, cast world.CastHead, k i64):
	r = rs.all[k].copy()
	rs.departed.push(Departure(npc = cast.npcs[r.npc].formId, door = r.exit))
	rs.free(k)
	rs.all[k].present = false
	rs.all[k].exit = 0

# the actor walks to its door over the navmesh, and goes through it once there
fn leaveByDoor(mut rs Residents, cast world.CastHead, k i64):
	if cast.doors.find(.refId == rs.all[k].exit) is door:
		_, floor = cast.navmesh.nearestPoint(door.position)
		to = floor - rs.all[k].body.feetOf()
		if Vec3(to.x, to.y, 0.0).length() > exitReach and rs.walkTo(cast, k, floor): return
	rs.depart(cast, k)

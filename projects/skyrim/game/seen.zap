# The cast and the player as detection reads them (game/stealth): where each present resident
# stands and how it moves, whether it sleeps in its bed or fights, and whether its eye reaches the
# player through the cell's geometry (a ray from its eye to a point of his body, 0x1406a2830).

import engine.physics
import game.sim
import game.stealth
import world

# whether a ray from the eye of a watcher standing at `watcher` reaches the chest, the head or the
# legs of a body standing at `target`
pub fn eyeReaches(
	mut scene physics.Scene,
	watcher Vec3,
	watcherSneaking bool,
	target Vec3,
	targetSneaking bool
) bool:
	eye = watcher.eyeAt(watcherSneaking)
	target.bodyPoints(stealth.bodyHeight, targetSneaking).any(scene.pointReached(eye, it))

# whether a ray from the eye reaches the point
pub fn pointReached(mut scene physics.Scene, eye Vec3, point Vec3) bool:
	scene.sweepShare(eye, point, 1.0) >= 0.999

# the player placed for detection
pub fn playerPlaced(p Player, sneaking bool, refId i64) stealth.Placed:
	gaits = p.gaitsNow()
	stealth.Placed(
		actor = refId,
		feet = p.feetOf(),
		heading = p.heading,
		speed = p.speedOf(),
		walkSpeed = gaits.walkSpeed,
		runSpeed = gaits.runSpeed,
		sneaking
	)

# The present residents that live, placed for detection against the player: each with whether its
# eye reaches him through the cell's geometry.
pub fn watchersOf(
	rs Residents,
	cast world.CastHead,
	w sim.GameWorld,
	mut scene physics.Scene,
	player stealth.Placed
) stealth.Placed[]:
	out = []
	event = w.eventOf(w.player)
	for r in rs.all:
		if not r.present: continue
		refId = cast.npcs[r.npc].worldRefOf(w)
		a = w.actors.get(refId) ?? continue
		if a.dead: continue
		gaits = r.body.gaitsNow()
		feet = r.body.feetOf()
		out.push(
			stealth.Placed(
				actor = refId,
				feet,
				heading = r.body.heading,
				speed = r.body.speedOf(),
				walkSpeed = gaits.walkSpeed,
				runSpeed = gaits.runSpeed,
				sleeping = r.doing == .Using and r.using == "bed",
				fighting = r.fighting,
				foe = w.player if r.fighting else 0,
				clear = scene.eyeReaches(feet, false, player.feet, player.sneaking),
				eventClear = scene.pointReached(feet.eyeAt(false), event?.at ?? player.feet)
			)
		)
	out

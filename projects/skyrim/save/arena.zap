# The parts of a game that live in the scene and not in the world's values: the fight in progress
# (the fighters' state, targets and timers, the fight's clock and dice, the player's draw and
# swing), the dead actors' ragdolls, the Havok clutter's poses and the physics' own warm start, and
# the animators (a resident's walker is part of its SavedResident). Each is plain values; `fightOf`
# and the like read them from the live scene, `restoreFight` and `restoreHavok` write them back.

import engine.physics
import game
import game.combat
import game.sim
import skyrim.hkx
import world

# a Havok body's motion: where it is, how it moves and whether it sleeps
pub type SavedPose:
	position Vec3
	orientation Quat
	velocity Vec3
	spin Vec3
	asleep bool
	rest physics.Resting

# a dead actor's ragdoll: how it fell (in the order the dead fell, which numbers their body
# groups), the pose it had then and where each of its bodies is now
pub type SavedFallen:
	order i64
	place hkx.Transform
	locals hkx.Transform[]
	pose f32[]
	bodies SavedPose[]

# what a joint keeps from one step to the next
pub type SavedJoint:
	impulses f32[]
	internals f32[]
	broken bool

# the physics world's loose ends: its clock, the contacts it warm-starts from and its joints'
# impulses
pub type SavedHavok:
	present bool = false
	clutter i64 = 0   # the bodies the world had before any ragdoll
	pending f32 = 0.0
	steps i64 = 0
	manifolds physics.Manifold[] = []
	joints SavedJoint[] = []

# the fight and the scene's hold on it, but for the fighters (an entry each)
pub type SavedFight:
	present bool = false
	time f32 = 0.0
	rng i64 = 0
	lines str[] = []
	assaulted {i64: bool} = {}
	actors {i64: sim.ActorState} = {}
	inventories {i64: sim.Inventory} = {}
	crimes sim.Crime[] = []
	crimeValues {i64: sim.CrimeValues} = {}
	owed f32 = 0.0
	drawn bool = false
	held f32 = 0.0
	fired bool = false
	rightCast bool = false
	leftCast bool = false
	meter i64 = -1
	meterLeft f32 = 0.0
	waiting game.PendingCast? = none
	animated bool = false
	seen game.Seen[] = []

fn poseOfBody(b physics.Body):
	SavedPose(
		position = b.position,
		orientation = b.orientation,
		velocity = b.velocity,
		spin = b.spin,
		asleep = b.asleep,
		rest = b.rest
	)

fn placePose(mut b physics.Body, p SavedPose):
	b.position = p.position
	b.orientation = p.orientation
	b.velocity = p.velocity
	b.spin = p.spin
	b.asleep = p.asleep
	b.rest = p.rest
	b.refresh()

# the poses of the bodies no ragdoll owns, by the body's place in the world
pub fn clutterOf(w physics.World) {i64: SavedPose}:
	out {i64: SavedPose} = {}
	for i, b in w.bodies:
		if b.group == 0: out[i] = b.poseOfBody()
	out

# the dead's ragdolls by the actor's reference
pub fn fallenOf(
	rs game.Residents,
	cast world.CastHead,
	menus sim.GameWorld,
	w physics.World
) {i64: SavedFallen}:
	out {i64: SavedFallen} = {}
	for order, f in rs.fallen:
		out[cast.npcs[rs.all[f.resident].npc].worldRefOf(menus)] = SavedFallen(
			order,
			place = f.place,
			locals = f.locals.copy(),
			pose = f.pose.copy(),
			bodies = f.ragdoll.bodies.map(w.bodies[it].poseOfBody())
		)
	out

pub fn havokOf(w physics.World) SavedHavok:
	if w.bodies.isEmpty: return SavedHavok()
	SavedHavok(
		present = true,
		clutter = w.bodies.count(.group == 0),
		pending = w.pending,
		steps = w.steps,
		manifolds = w.manifolds.copy(),
		joints = w.joints.map(
			SavedJoint(impulses = .impulses.copy(), internals = .internals.copy(), broken = .broken)
		)
	)

# the fighters of the scene's fight by the actor's reference
pub fn fightersOf(fight game.FightScene?) {i64: combat.Fighter}:
	out {i64: combat.Fighter} = {}
	if fight is scene:
		for x in scene.fight.fighters:
			out[x.refId] = x.copy()
	out

pub fn fightOf(fight game.FightScene?) SavedFight:
	scene = fight ?? return SavedFight()
	SavedFight(
		present = true,
		time = scene.fight.time,
		rng = scene.fight.rng.state,
		lines = scene.fight.lines.copy(),
		assaulted = scene.fight.assaulted.copy(),
		actors = scene.fight.w.actors.copy(),
		inventories = scene.fight.w.inventories.copy(),
		crimes = scene.fight.w.crimes.copy(),
		crimeValues = scene.fight.w.crimeValues.copy(),
		owed = scene.owed,
		drawn = scene.drawn,
		held = scene.held,
		fired = scene.fired,
		rightCast = scene.rightCast,
		leftCast = scene.leftCast,
		meter = scene.meter,
		meterLeft = scene.meterLeft,
		waiting = scene.waiting.copy(),
		animated = scene.animated,
		seen = scene.seen.copy()
	)

# The fight as saved, its fighters put back; the scene's links to the residents are made again by
# its next step. Nothing without a fight in the save.
pub fn restoreFight(mut scene game.FightScene, s Snapshot):
	if not s.fight.present: return
	f = s.fight
	scene.fight.time = f.time
	scene.fight.rng.state = f.rng
	scene.fight.lines = f.lines.copy()
	scene.fight.assaulted = f.assaulted.copy()
	scene.fight.w.actors = f.actors.copy()
	scene.fight.w.inventories = f.inventories.copy()
	scene.fight.w.crimes = f.crimes.copy()
	scene.fight.w.crimeValues = f.crimeValues.copy()
	for k in 0..scene.fight.fighters.len:
		if s.fighters.get(scene.fight.fighters[k].refId) is x: scene.fight.fighters[k] = x.copy()
	scene.owed = f.owed
	scene.drawn = f.drawn
	scene.held = f.held
	scene.fired = f.fired
	scene.rightCast = f.rightCast
	scene.leftCast = f.leftCast
	scene.meter = f.meter
	scene.meterLeft = f.meterLeft
	scene.waiting = f.waiting.copy()
	scene.animated = f.animated
	scene.seen = f.seen.copy()
	scene.links = []

# the residents by the actor's reference
fn residentsByRef(rs game.Residents, cast world.CastHead, menus sim.GameWorld):
	out {i64: i64} = {}
	for k, r in rs.all:
		out[cast.npcs[r.npc].worldRefOf(menus)] = k
	out

# The dead's ragdolls laid again as they fell and the world's bodies put as saved: the clutter's
# poses, the ragdolls' bodies, the joints' impulses and the contacts the next step warm-starts
# from. A world that is not the save's (another count of bodies before the ragdolls) is left as it
# is.
pub fn restoreHavok(
	mut rs game.Residents,
	cast world.CastHead,
	menus sim.GameWorld,
	mut w physics.World,
	s Snapshot
):
	h = s.havok
	first = w.bodies.findIndex(.group != 0) ?? w.bodies.len
	if not h.present or first != h.clutter: return
	w.bodies = w.bodies[..first].copy()
	w.joints = w.joints.filter(.a < first and .b < first)
	rs.fallen = []
	rigs = cast.skeletons.map(.skeletonRig())
	owners = rs.residentsByRef(cast, menus)
	dead = s.fallen.keys().sortedBy(s.fallen[it].order)
	for owner in dead:
		f = s.fallen[owner]
		k = owners.get(owner) ?? continue
		if not rs.fallAgain(cast, k, rigs, w, f.place, f.locals, f.pose): continue
		lying = rs.fallen[len - 1].ragdoll.bodies
		for j, body in lying:
			if j < f.bodies.len: w.bodies[body].placePose(f.bodies[j])
	for i, pose in s.clutter:
		if i < first: w.bodies[i].placePose(pose)
	for i, j in h.joints:
		if i >= w.joints.len: break
		w.joints[i].impulses = j.impulses.copy()
		w.joints[i].internals = j.internals.copy()
		w.joints[i].broken = j.broken
	w.manifolds = h.manifolds.copy()
	w.pending = h.pending
	w.steps = h.steps

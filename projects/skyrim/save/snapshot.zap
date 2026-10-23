# The state of a game in the inn that play changes, as plain values: the world's forms, actors and
# inventories, the quests, the globals, the clock, what the dialogue remembers, the Papyrus VM's
# objects, arrays, threads and registered updates, the residents' packages and bodies, the
# player's body. Every part is serializable (toBytes); `capture` reads it from the live game,
# `restore` writes it back, `changes.zap` cuts it into change forms against a game's start.

import engine.physics
import game
import game.combat
import game.dialogue
import game.sim
import papyrus
import world

# a body standing in the inn: where, the way it faces and how its gait stands
pub type SavedBody:
	feet Vec3
	falling f32
	onFloor bool
	heading f32
	gait f32
	cycle f32
	idleTime f32

# what a resident does: its package, its marker, its walk
pub type SavedResident:
	body SavedBody
	present bool
	plan i64
	hour i64
	doing game.Doing
	marker i64
	using str
	graphDriven bool
	path Vec3[]
	along i64
	clock f32
	until f32
	progress f32
	nearest f32
	look Quat
	was Vec3
	talking bool
	turnRate f32
	fighting bool
	walker game.Walker   # its animator: the graph's states, the clips' times

# a call in a Papyrus thread: its function by the script's name (the library's indexes differ
# from one run to the next), where it stands and what it holds
pub type SavedFrame:
	script str
	state i64
	index i64
	setter bool
	pc i64
	locals {str: papyrus.Value}
	me i64
	resultTo str

pub type SavedThread:
	frames SavedFrame[]
	wakeAt f64
	result papyrus.Value
	label str

pub type SavedVm:
	objects papyrus.Instance[]
	arrays papyrus.ArrayData[]
	threads SavedThread[]
	updates papyrus.Update[]
	sleepers i64[] = []   # the objects registered for the player's sleep
	time f64
	rng i64

# the rest of the world's own state, and the dialogue's and the residents' loose ends
pub type SavedMisc:
	cell i64
	cellOwner i64
	notifications str[]
	events str[]
	crimes sim.Crime[]
	dice i64
	diceFair bool
	nextFormId i64
	barterWith i64
	evaluate {i64: bool}
	daysPassed f64
	timeScale f64
	partner i64
	greeting bool
	taken {i64: i64}
	residentDice i64
	playSeconds f64
	stealth sim.Stealth
	progress sim.Progress

pub type Snapshot:
	forms {i64: sim.WorldForm}
	actors {i64: sim.ActorState}
	inventories {i64: sim.Inventory}
	residents {i64: SavedResident}   # by the actor's reference
	player SavedBody
	walker game.Walker   # the player's animator
	clutter {i64: SavedPose}   # the Havok bodies of no ragdoll, by their place in the world
	fallen {i64: SavedFallen}   # the dead's ragdolls, by the actor's reference
	fighters {i64: combat.Fighter}   # by the actor's reference
	fight SavedFight
	havok SavedHavok
	stages {i64: i64}
	stagesDone {i64: bool}
	running {i64: bool}
	globals {i64: f32}
	furniture {i64: i64}   # the markers in use, by the furniture's base
	said {i64: f64}
	talkedTo {i64: bool}
	relations {i64: i64}
	fills {i64: i64}
	booksRead {i64: bool}
	crimeValues {i64: sim.CrimeValues}
	crimeFactions {i64: i64}
	misc SavedMisc
	vm SavedVm

pub fn bodyOf(p game.Player) SavedBody:
	c = p.controller
	SavedBody(
		feet = c.feet,
		falling = c.falling,
		onFloor = c.onFloor,
		heading = p.heading,
		gait = p.gait,
		cycle = p.cycle,
		idleTime = p.idleTime
	)

pub fn placeBody(mut p game.Player, b SavedBody):
	p.controller.feet = b.feet
	p.controller.falling = b.falling
	p.controller.onFloor = b.onFloor
	p.heading = b.heading
	p.gait = b.gait
	p.cycle = b.cycle
	p.idleTime = b.idleTime

fn residentOf(r game.Resident, walker game.Walker):
	SavedResident(
		body = r.body.bodyOf(),
		present = r.present,
		plan = r.plan,
		hour = r.hour,
		doing = r.doing,
		marker = r.marker,
		using = r.using.copy(),
		graphDriven = r.graphDriven,
		path = r.path.copy(),
		along = r.along,
		clock = r.clock,
		until = r.until,
		progress = r.progress,
		nearest = r.nearest,
		look = r.look,
		was = r.was,
		talking = r.talking,
		turnRate = r.turnRate,
		fighting = r.fighting,
		walker = walker.copy()
	)

fn placeResident(mut r game.Resident, s SavedResident):
	r.body.placeBody(s.body)
	r.present = s.present
	r.plan = s.plan
	r.hour = s.hour
	r.doing = s.doing
	r.marker = s.marker
	r.using = s.using.copy()
	r.graphDriven = s.graphDriven
	r.path = s.path.copy()
	r.along = s.along
	r.clock = s.clock
	r.until = s.until
	r.progress = s.progress
	r.nearest = s.nearest
	r.look = s.look
	r.was = s.was
	r.talking = s.talking
	r.turnRate = s.turnRate
	r.fighting = s.fighting

fn frameOf(lib papyrus.Library, f papyrus.Frame):
	SavedFrame(
		script = lib.nameOf(f.code.script).copy(),
		state = f.code.state,
		index = f.code.index,
		setter = f.code.setter,
		pc = f.pc,
		locals = f.locals.copy(),
		me = f.me,
		resultTo = f.resultTo.copy()
	)

fn vmOf(vm papyrus.Vm):
	threads = []
	for t in vm.rt.threads:
		threads.push(SavedThread(
			frames = t.frames.map(vm.lib.frameOf(it)),
			wakeAt = t.wakeAt,
			result = t.result.copy(),
			label = t.label.copy()
		))
	SavedVm(
		objects = vm.rt.objects.copy(),
		arrays = vm.rt.arrays.copy(),
		threads,
		updates = vm.rt.updates.copy(),
		sleepers = vm.rt.sleepers.copy(),
		time = vm.rt.time,
		rng = vm.rt.rng.state
	)

fn furnitureOf(w sim.GameWorld):
	out {i64: i64} = {}
	for base, f in w.furniture:
		out[base] = f.active
	out

# The residents by the actor's reference, for the cast's residents in this order.
fn residentsOf(rs game.Residents, cast world.CastHead, w sim.GameWorld):
	out {i64: SavedResident} = {}
	for k, r in rs.all:
		out[cast.npcs[r.npc].worldRefOf(w)] = r.residentOf(rs.walkers[k])
	out

# Everything of the live game that play changes: with the scene's fight (none without one), the
# player's animator and the cell's physics world.
pub fn capture(
	t dialogue.Talk,
	rs game.Residents,
	cast world.CastHead,
	p game.Player,
	fight game.FightScene?,
	walker game.Walker,
	bodies physics.World
) Snapshot:
	w = t.vm.rt.world
	Snapshot(
		forms = w.forms.copy(),
		actors = w.actors.copy(),
		inventories = w.inventories.copy(),
		residents = rs.residentsOf(cast, w),
		player = p.bodyOf(),
		walker = walker.copy(),
		clutter = bodies.clutterOf(),
		fallen = rs.fallenOf(cast, w, bodies),
		fighters = fightersOf(fight),
		fight = fightOf(fight),
		havok = bodies.havokOf(),
		stages = w.stages.copy(),
		stagesDone = w.stagesDone.copy(),
		running = w.runningQuests.copy(),
		globals = w.globals.copy(),
		furniture = w.furnitureOf(),
		said = t.said.copy(),
		talkedTo = t.talkedTo.copy(),
		relations = t.relations.copy(),
		fills = t.fills.copy(),
		booksRead = w.booksRead.copy(),
		crimeValues = w.crimeValues.copy(),
		crimeFactions = w.crimeFactions.copy(),
		misc = SavedMisc(
			cell = w.cell,
			cellOwner = w.cellOwner,
			notifications = w.notifications.copy(),
			events = w.events.copy(),
			crimes = w.crimes.copy(),
			dice = w.dice.rng.state,
			diceFair = w.dice.fair,
			nextFormId = w.nextFormId,
			barterWith = w.barterWith,
			evaluate = w.evaluate.copy(),
			daysPassed = w.daysPassed,
			playSeconds = w.playSeconds,
			stealth = w.stealth.copy(),
			progress = w.progress.copy(),
			timeScale = w.timeScale,
			partner = t.partner,
			greeting = t.greeting,
			taken = rs.taken.copy(),
			residentDice = rs.dice.state
		),
		vm = t.vm.vmOf()
	)

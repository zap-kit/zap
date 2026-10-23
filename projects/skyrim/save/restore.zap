# A snapshot written back into the live game: the world, the quests, the dialogue's memory, the
# Papyrus VM, the residents and the player's body. A thread of the VM names its script, which is
# loaded again when the run lacks it. The animators come back as they were (a resident's graph
# states and clips' times); the fight in progress, the dead's ragdolls and the clutter's poses
# are written into the scene and the physics world they are given (arena.zap).

import engine.physics
import game
import game.dialogue
import game.sim
import papyrus
import world

fn frameBack(vm papyrus.Vm, f SavedFrame) papyrus.Frame ? str:
	k = vm.lib.scriptIndex(f.script) ?? return "the script {f.script} is not loaded"
	papyrus.Frame(
		code = papyrus.CodeRef(script = k, state = f.state, index = f.index, setter = f.setter),
		pc = f.pc,
		locals = f.locals.copy(),
		me = f.me,
		resultTo = f.resultTo.copy()
	)

fn threadBack(mut vm papyrus.Vm, t SavedThread) papyrus.Thread ? str:
	frames = []
	for f in t.frames:
		if not vm.ensureScript(f.script): return "the script {f.script} cannot be loaded"
		frames.push(try vm.frameBack(f))
	papyrus.Thread(frames, wakeAt = t.wakeAt, result = t.result.copy(), label = t.label.copy())

# the VM's objects, arrays, threads, updates and clocks as saved
fn restoreVm(mut vm papyrus.Vm, s SavedVm) ? str:
	threads = []
	for t in s.threads:
		threads.push(try vm.threadBack(t))
	vm.rt.objects = s.objects.copy()
	vm.rt.arrays = s.arrays.copy()
	vm.rt.threads = threads
	vm.rt.updates = s.updates.copy()
	vm.rt.sleepers = s.sleepers.copy()
	vm.rt.time = s.time
	vm.rt.rng.state = s.rng

fn restoreWorld(mut w sim.GameWorld, s Snapshot):
	w.forms = s.forms.copy()
	w.actors = s.actors.copy()
	w.inventories = s.inventories.copy()
	w.stages = s.stages.copy()
	w.stagesDone = s.stagesDone.copy()
	w.runningQuests = s.running.copy()
	w.globals = s.globals.copy()
	w.booksRead = s.booksRead.copy()
	w.crimeValues = s.crimeValues.copy()
	w.crimeFactions = s.crimeFactions.copy()
	for base, active in s.furniture:
		if w.furniture.getMut(base) is mut f: f.active = active
	m = s.misc
	w.cell = m.cell
	w.cellOwner = m.cellOwner
	w.notifications = m.notifications.copy()
	w.events = m.events.copy()
	w.crimes = m.crimes.copy()
	w.dice.rng.state = m.dice
	w.dice.fair = m.diceFair
	w.nextFormId = m.nextFormId
	w.barterWith = m.barterWith
	w.evaluate = m.evaluate.copy()
	w.daysPassed = m.daysPassed
	w.playSeconds = m.playSeconds
	w.stealth = m.stealth.copy()
	w.progress = m.progress.copy()
	w.timeScale = m.timeScale
	w.queueUnlearned()

fn restoreDialogue(mut t dialogue.Talk, s Snapshot):
	t.said = s.said.copy()
	t.talkedTo = s.talkedTo.copy()
	t.relations = s.relations.copy()
	t.fills = s.fills.copy()
	t.partner = s.misc.partner
	t.greeting = s.misc.greeting

# the residents put as saved, with their animators
fn restoreResidents(
	mut rs game.Residents,
	cast world.CastHead,
	w sim.GameWorld,
	s Snapshot
):
	for k in 0..rs.all.len:
		if s.residents.get(cast.npcs[rs.all[k].npc].worldRefOf(w)) is saved:
			rs.all[k].placeResident(saved)
	rs.taken = s.misc.taken.copy()
	rs.dice.state = s.misc.residentDice
	for k in 0..rs.all.len:
		rs.walkers[k] = rs.graph.newWalker(false)
		saved = s.residents.get(cast.npcs[rs.all[k].npc].worldRefOf(w)) ?? continue
		rs.walkers[k] = saved.walker.copy()

# Writes the snapshot into the live game, or says why a script of the VM cannot be had.
pub fn restore(
	mut t dialogue.Talk,
	mut rs game.Residents,
	cast world.CastHead,
	mut p game.Player,
	mut walker game.Walker,
	mut bodies physics.World,
	s Snapshot
) ? str:
	try t.vm.restoreVm(s.vm)
	t.vm.rt.world.restoreWorld(s)
	t.restoreDialogue(s)
	rs.restoreResidents(cast, t.vm.rt.world, s)
	rs.syncDoors(cast, t.vm.rt.world, bodies)
	p.placeBody(s.player)
	walker = s.walker.copy()
	rs.restoreHavok(cast, t.vm.rt.world, bodies, s)

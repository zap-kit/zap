# Going through a load door (XTEL): the door's other side is a cell the game opens (an interior by
# its editor id, an exterior as the area the loaded grid makes around it, esm/area.zap), the
# player placed at the XTEL's position facing its rotation, as the game's TeleportPlayer does.
# What goes with him: his body's state, his inventory, the quests, the globals and the clock; what
# the cell he leaves holds (its references' state, the containers) is kept for the day he comes
# back to it. Each cell's own VM and residents are made new as a new game finds them.

import game.sim
import skyrim.esm

# where the player enters the cell a load door leads to
pub type Arrival:
	place str   # the cell's id: an interior's editor id or an exterior area's
	feet Vec3   # the game's units, Z up
	heading f32
	fades bool = true   # the screen fades to black and back (a load door), not a grid loaded again

# the state of a cell the player has left: its references and what the actors and containers carry
pub type Left:
	forms {i64: sim.WorldForm}
	inventories {i64: sim.Inventory}
	actors {i64: sim.ActorState}

# the arrival the load door leads to, none when the reference is no load door
pub fn arrivalThrough(w sim.GameWorld, door i64) Arrival?:
	f = try w.forms.get(door)
	t = try f.teleport
	Arrival(place = t.placeId(), feet = t.position, heading = t.rotation.z)

# how many cells from the loaded area's centre the player may go before the grid is loaded again
# around the cell he is in
recenterBeyond = 1

# The area loaded around the player's cell when he has gone past the middle ring of the one he is
# in, standing where he stands; none while he is within it.
pub fn recentered(area esm.Area, feet Vec3, heading f32) Arrival?:
	now = esm.areaAround(area.world, feet)
	if (now.x - area.x).abs() <= recenterBeyond and (now.y - area.y).abs() <= recenterBeyond:
		return none
	Arrival(place = now.areaId(), feet, heading, fades = false)

# the cell's state, to be put back when the player returns
pub fn leaving(w sim.GameWorld) Left:
	Left(forms = w.forms.copy(), inventories = w.inventories.copy(), actors = w.actors.copy())

# the state the player left the cell in put back, but for the player's own
pub fn returning(mut w sim.GameWorld, left Left):
	for id, f in left.forms:
		if id != w.player: w.forms[id] = f.copy()
	for id, inventory in left.inventories:
		if id != w.player: w.inventories[id] = inventory.copy()
	for id, a in left.actors:
		if id != w.player: w.actors[id] = a.copy()

# What goes with the player into the next cell's new world: his actor and inventory, the quests'
# stages, the globals, the books read, the crimes, the clock and his settings.
pub fn carryOver(from sim.GameWorld, mut into sim.GameWorld):
	if from.actors.get(from.player) is a: into.actors[into.player] = a.copy()
	if from.inventories.get(from.player) is inventory:
		into.inventories[into.player] = inventory.copy()
	into.stages = from.stages.copy()
	into.stagesDone = from.stagesDone.copy()
	into.runningQuests = from.runningQuests.copy()
	into.globals = from.globals.copy()
	into.booksRead = from.booksRead.copy()
	into.crimes = from.crimes.copy()
	into.crimeValues = from.crimeValues.copy()
	into.crimeFactions = from.crimeFactions.copy()
	into.daysPassed = from.daysPassed
	into.playSeconds = from.playSeconds
	into.timeScale = from.timeScale
	into.difficulty = from.difficulty
	into.progress = from.progress.copy()
	into.stealth = from.stealth.copy()
	into.nextFormId = from.nextFormId

# a test's order to go through a load door at a frame (`--use frame:door`, the door's form id in
# hex): the frame and the door, (-1, 0) for none
pub fn useOrderOf(text str) (i64, i64):
	parts = text.split(":")
	if parts.len != 2: return (-1, 0)
	(i64.parse(parts[0]) ?? -1, i64.parse("0x{parts[1]}") ?? 0)

# Saving and loading a game in the inn. A session keeps the entries of the game as it began (the
# new game every save is the changes to); a save writes the changes, the global data and the
# header, a load reads the file over the new game's entries and writes the snapshot back into the
# live game. The game does not save while enemies fight the player, nor does this. The ...In
# functions take the scene's fight, the player's animator and the cell's physics world; the plain
# ones leave the scene out of the save.

import fs
import game
import game.dialogue
import game.sim
import engine.physics
import skyrim.esm
import world
import skyrim
import game.combat

# the name the player has until a character is made (the character creation is not modelled)
pub defaultPlayerName = "Dragonborn"

pub type Session:
	dir str
	base {i64: Entry}   # the keyed entries of the game as it began
	playerName str = defaultPlayerName

# the screenshot a save carries: RGBA pixels
pub type Screenshot:
	width i64
	height i64
	pixels u8[]

# The session of a game that has just begun (its saves go to `dir`).
pub fn startSession(
	dir str,
	t dialogue.Talk,
	rs game.Residents,
	cast world.CastHead,
	p game.Player,
	fight game.FightScene?,
	walker game.Walker,
	bodies physics.World
) Session:
	Session(dir = dir.copy(), base = t.capture(rs, cast, p, fight, walker, bodies).entriesOf())

# why the game cannot be saved now: enemies fighting the player
pub fn refusal(rs game.Residents, fight game.FightScene?) str?:
	foes = rs.all.any(.fighting)
	if fight is scene:
		me = scene.fight.fighters[scene.player].refId
		foes = scene.fight.fighters.any(not .player and .isFighting() and .target == me)
	if foes: return "You cannot save while enemies are nearby."
	none

# the days, hours and minutes played, as the header writes them
fn playTimeOf(seconds f64):
	minutes = i64(seconds / 60.0)
	"{minutes / 1440:03}.{minutes / 60 % 24:02}.{minutes % 60:02}"

fn editorIdOf(mut t dialogue.Talk, formId i64):
	r = t.plugin.recordOf(formId) ?? return ""
	esm.textOf(r.body, r.fields, "EDID")

# the name of the place the player is in: its location's, else the cell's
fn locationName(mut t dialogue.Talk):
	r = t.plugin.recordOf(t.location) ?? return t.vm.rt.world.editorIdOf(t.vm.rt.world.cell)
	name = t.names.localText(r, "FULL")
	name if not name.isEmpty else t.vm.rt.world.editorIdOf(t.vm.rt.world.cell)

fn headerFor(
	s Session,
	mut t dialogue.Talk,
	snap Snapshot,
	number i64,
	shot Screenshot?
):
	me = snap.actors.get(t.vm.rt.world.player)
	Header(
		saveNumber = number,
		name = s.playerName.copy(),
		level = me?.level ?? 1,
		location = t.locationName(),
		playTime = playTimeOf(snap.misc.playSeconds),
		race = t.editorIdOf(me?.race ?? 0),
		female = false,
		curExp = snap.misc.progress.xp,
		levelUpExp = t.vm.rt.world.levelThreshold(me?.level ?? 1),
		filetime = nowFiletime(s.dir),
		shotWidth = shot?.width ?? 0,
		shotHeight = shot?.height ?? 0
	)

# The bytes of a save of the live game numbered `number`.
pub fn saveBytes(
	s Session,
	mut t dialogue.Talk,
	rs game.Residents,
	cast world.CastHead,
	p game.Player,
	fight game.FightScene?,
	walker game.Walker,
	bodies physics.World,
	number i64,
	shot Screenshot?
) u8[]:
	snap = t.capture(rs, cast, p, fight, walker, bodies)
	e = Ess(
		header = s.headerFor(t, snap, number, shot),
		shot = shot?.pixels.copy() ?? [],
		plugins = ["Skyrim.esm", "Update.esm"],
		blocks = snap.blocksOf(),
		changes = changesOf(s.base, snap.entriesOf())
	)
	e.writeEss()

# whether a save written of this kind (over `replacing`, when given) takes the old one's place
fn isSupersededBy(old Listed, kind str, replacing Listed?):
	if replacing is r and r.file == old.file: return true
	old.kind == kindQuick and kind == kindQuick

# Writes the game to the folder as a save of this kind, over `replacing` when given; the file.
pub fn saveGameIn(
	s Session,
	mut t dialogue.Talk,
	rs game.Residents,
	cast world.CastHead,
	p game.Player,
	fight game.FightScene?,
	walker game.Walker,
	bodies physics.World,
	kind str,
	replacing Listed?,
	shot Screenshot?
) Listed ? str:
	if rs.refusal(fight) is why: return why
	fs.createDir(s.dir) ?? return "{s.dir} cannot be made"
	saves = listSaves(s.dir)
	number = nextNumber(saves)
	if replacing is old: number = old.header.saveNumber
	bytes = s.saveBytes(t, rs, cast, p, fight, walker, bodies, number, shot)
	header = headerOf(bytes) ?? return "the save cannot be read back"
	file = "{s.dir}/{fileNameOf(kind, header)}"
	fs.writeBytes(file, bytes) ?? return "{file} cannot be written"
	for old in saves:
		if old.file != file and old.isSupersededBy(kind, replacing):
			old.deleteSave() ?? return "the old save cannot be deleted"
	Listed(file, kind = kind.copy(), header)

# The save's state written back into the live game (its scene's parts into the player's animator
# and the physics world given), or why the file cannot be used; the save read, whose fight the
# caller puts back into its scene (restoreFight), since a fight is optional.
pub fn loadGameIn(
	s Session,
	mut t dialogue.Talk,
	mut rs game.Residents,
	cast world.CastHead,
	mut p game.Player,
	mut walker game.Walker,
	mut bodies physics.World,
	e Listed
) Snapshot ? str:
	bytes = fs.readBytes(e.file) ?? return "{e.file} cannot be read"
	file = try readEss(bytes)
	snap = try snapshotFrom(file.blocks, overlay(s.base, file.changes))
	try t.restore(rs, cast, p, walker, bodies, snap)
	snap

# Quicksave: the newest quicksave replaced.
pub fn quickSaveIn(
	s Session,
	mut t dialogue.Talk,
	rs game.Residents,
	cast world.CastHead,
	p game.Player,
	fight game.FightScene?,
	walker game.Walker,
	bodies physics.World,
	shot Screenshot?
) Listed ? str:
	s.saveGameIn(t, rs, cast, p, fight, walker, bodies, kindQuick, none, shot)

# the quicksave, or why there is none
fn newestQuick(s Session) Listed ? str:
	listSaves(s.dir).find(.kind == kindQuick) ?? return "There is no quicksave."

# Quickload: the quicksave read, or why there is none.
pub fn quickLoadIn(
	s Session,
	mut t dialogue.Talk,
	mut rs game.Residents,
	cast world.CastHead,
	mut p game.Player,
	mut walker game.Walker,
	mut bodies physics.World
) Snapshot ? str:
	quick = try s.newestQuick()
	try s.loadGameIn(t, rs, cast, p, walker, bodies, quick)

# The same without a scene: the save holds the world's values and the residents only (what the
# journal's requests call).
pub fn saveGame(
	s Session,
	mut t dialogue.Talk,
	rs game.Residents,
	cast world.CastHead,
	p game.Player,
	kind str,
	replacing Listed?,
	shot Screenshot?
) Listed ? str:
	s.saveGameIn(t, rs, cast, p, none, rs.graph.newWalker(true), physics.worldOf(1.0), kind,
		replacing, shot)

pub fn loadGame(
	s Session,
	mut t dialogue.Talk,
	mut rs game.Residents,
	cast world.CastHead,
	mut p game.Player,
	e Listed
) ? str:
	walker = rs.graph.newWalker(true)
	bodies = physics.worldOf(1.0)
	_ = try s.loadGameIn(t, rs, cast, p, walker, bodies, e)

pub fn quickSave(
	s Session,
	mut t dialogue.Talk,
	rs game.Residents,
	cast world.CastHead,
	p game.Player,
	shot Screenshot?
) Listed ? str:
	s.saveGame(t, rs, cast, p, kindQuick, none, shot)

pub fn quickLoad(
	s Session,
	mut t dialogue.Talk,
	mut rs game.Residents,
	cast world.CastHead,
	mut p game.Player
) ? str:
	quick = try s.newestQuick()
	try s.loadGame(t, rs, cast, p, quick)

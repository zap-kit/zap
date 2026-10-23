# The journal's saves, as the game answers the system page: the lists of saved games the Save and
# Load pages ask for (SAVE and LOAD fill the page's entry list and the game tells it the batch is
# complete), the confirmation the Load page waits for, and what the page asks of the game when
# the player chooses: SaveGame, LoadGame, DeleteSave, QuickSave and the quit calls. The page's
# calls become requests the game carries out (`run`) over the saves folder.

import engine.physics
import engine.swf.avm1
import game
import game.dialogue
import image
import save
import world

pub type Request:
	Save(replacing i64)   # a new save when -1, else the save at that place of the list
	QuickSave
	Load(index i64)
	QuickLoad
	Delete(index i64)
	Quit

fn rowOf(k i64, e save.Listed):
	avm1.Row(members = [
		avm1.Member("text", .Str(e.listText())),
		avm1.Member("name", .Str("{e.header.name}, {e.header.location}")),
		avm1.Member("level", .Num(f64(e.header.level))),
		avm1.Member("playTime", .Str(e.header.playTime.copy())),
		avm1.Member("dateString", .Str(save.filetimeText(e.header.filetime))),
		avm1.Member("id", .Num(f64(k))),
		avm1.Member("flags", .Num(0.0))
	])

# What the game writes into the entry list the Save and Load pages hand it (their first argument,
# the batch size the second). A row is the save's label, which the page cuts at 20 letters; its
# name is the player's and the place (the page writes the name, a comma and the level below the
# list), and its play time and the time it was written follow.
pub fn answerSaveLists(mut p avm1.Player, saves save.Listed[]):
	rows = []
	for k, e in saves:
		rows.push(rowOf(k, e))
	p.m.replies["LOAD"] = [.Fill(0, rows.copy())]
	p.m.replies["SAVE"] = [.Fill(0, rows)]

# What the system page's call asks of the game: the lists it asks for answered at once, the
# request a choice makes, none for any other call.
pub fn answerSaveCall(mut p avm1.Player, c avm1.ExternalCall, saves save.Listed[]) Request?:
	if c.name == "SAVE" or c.name == "LOAD":
		count = f64(saves.len)
		p.delegate("onSaveLoadBatchComplete", [.Bool(true), .Num(count), .Num(count)])
		return none
	if c.name == "IsOKtoLoad":
		p.delegate("ConfirmOKToLoad", [])
		return none
	if c.name == "SaveGame": return .Save(c.numberArg(1) - 1)
	if c.name == "LoadGame": return .Load(c.numberArg(1))
	if c.name == "DeleteSave": return .Delete(c.numberArg(1))
	if c.name == "QuickSave": return .QuickSave
	if c.name == "QuitToDesktop" or c.name == "QuitToMainMenu": return .Quit
	none

# what a request did, for the game to go on from
pub type Outcome:
	loaded save.Snapshot? = none   # the save the game was put back to (its fight left to the scene)
	quit bool = false
	said str = ""   # what to tell the player

fn savedOutcome(saved save.Listed ? str, what str):
	match saved:
		error: Outcome(said = error.copy())
		_: Outcome(said = what.copy())

# whether carrying the request out writes a save, which wants the frame's picture
pub fn writesSave(r Request) bool:
	match r:
		Save, QuickSave: true
		_: false

# the frame as the save's small picture (the game's is 256 x 192)
pub fn screenshotOf(frame image.Image) save.Screenshot:
	small = frame.resize(256, 192)
	save.Screenshot(width = 256, height = 192, pixels = small.cells.bytes().copy())

# Carries the request out over the saves of the session's folder.
pub fn carryOut(
	r Request,
	s save.Session,
	saves save.Listed[],
	mut t dialogue.Talk,
	mut rs game.Residents,
	cast world.CastHead,
	mut p game.Player,
	fight game.FightScene?,
	mut walker game.Walker,
	mut bodies physics.World,
	shot save.Screenshot?
) Outcome:
	match r:
		Save(at):
			replacing save.Listed? = none
			if at >= 0 and at < saves.len: replacing = saves[at].copy()
			savedOutcome(
				s.saveGameIn(t, rs, cast, p, fight, walker, bodies, save.kindSave, replacing, shot),
				"Saved"
			)
		QuickSave:
			savedOutcome(s.quickSaveIn(t, rs, cast, p, fight, walker, bodies, shot), "Quicksaved")
		Load(at):
			if at < 0 or at >= saves.len: return Outcome(said = "There is no such save.")
			loadedOutcome(s.loadGameIn(t, rs, cast, p, walker, bodies, saves[at]))
		QuickLoad:
			loadedOutcome(s.quickLoadIn(t, rs, cast, p, walker, bodies))
		Delete(at):
			if at < 0 or at >= saves.len: return Outcome()
			deletedOutcome(saves[at].deleteSave())
		Quit: Outcome(quit = true)

fn loadedOutcome(move done save.Snapshot ? str):
	match done:
		error: Outcome(said = error.copy())
		snap: Outcome(loaded = snap, said = "Loaded")

fn deletedOutcome(done () ? str):
	match done:
		error: Outcome(said = error.copy())
		_: Outcome()

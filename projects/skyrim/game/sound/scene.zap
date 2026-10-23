# The cell's sounds as the game runs them, stepped once a frame: the location's music, the
# acoustic space's loop and the loops of its markers and fires (started as it opens), the
# footsteps of the player and of the actors present, the clutter's knocks and the actors' hellos,
# all heard from the camera. Without the install it is silent.

import engine.audio
import game
import game.dialogue
import engine.physics
import skyrim
import skyrim.actor
import skyrim.esm
import world

pub type Scene:
	book Book
	music MusicPlayer
	standing Standing[]
	materials {i64: i64}   # the materials by their Havok hash
	player Feet
	npcs Feet[]   # by the cast's NPC
	keys StepKeys[]   # by skeleton: the locomotion clips' foot keys
	knocks Knocks
	greeters Greeter[]   # one, or none when the dialogue cannot be read
	voices Speaking   # the lines being said, the hellos' and the dialogue's
	cell esm.Cell
	started bool = false   # its standing loops started (at the first frame, the listener placed)
	shown i64 = 0   # the log's lines given by newLines

# a point of the drawing's space (y up) in Skyrim's (Z up)
pub fn skyrimPoint(p Vec3) Vec3:
	game.yUp.inverseAffine().applyPoint(p)

# the feet of the actor `formId` wearing `outfit` (its own outfit's at a new game when none)
fn actorFeet(mut b Book, formId i64, outfit i64[]?, name str, player bool) Feet:
	npc = b.plugin.npcOf(formId) ?? return b.feetOf(name, [], player)
	armors = outfit ?? b.plugin.outfitArmors(npc.outfit)
	addons = b.plugin.wornAddons(npc.race, npc.female, npc.skin, armors) ?? []
	b.feetOf(name, addons, player)

fn greetersOf(mut b Book, dir str, cellId str, hour f32):
	install = skyrim.openInstall(dir) ?? return []
	plugin = esm.openEsm(install.installPlugin("Skyrim.esm")) ?? return []
	talk = dialogue.talkInCell(install, plugin, cellId) ?? return []
	[b.newGreeter(talk, hour)]
# The sounds of the interior `cellId` of the install in `dir`, its cast stepping with the locomotion
# clips among `clipNames` (by skeleton) the graph plays, its clutter in `cw`, at the game hour, with
# the actors' hellos when `hellos` (their dialogue read, with a world and scripts of its own); why
# when the install cannot give them.
# dialogue read, with a world and scripts of its own); why when the install cannot give them.
pub fn openScene(
	dir str,
	cellId str,
	cast world.CastHead,
	clipNames str[,],
	cw game.CellWorld,
	hour f32,
	hellos bool
) Scene ? str:
	install = try skyrim.openInstall(dir)
	plugin = try esm.openEsm(install.installPlugin("Skyrim.esm"))
	cell = plugin.findCell(cellId) ?? return "no interior cell {cellId}"
	b = newBook(install, plugin)
	keys = (0..clipNames.len).map(b.install.stepKeysOf(clipNames[it], it == 1))
	player = b.actorFeet(game.playerId, game.prisonerOutfit, "the player", true)
	npcs = cast.npcs.map(b.actorFeet(.formId, none, .editorId, false))
	music = b.newMusicPlayer()
	music.setLocationMusic(cell.music)
	materials = b.plugin.materialsByHash()
	greeters = b.greetersOf(dir, cellId, hour) if hellos else []
	Scene(
		book = b,
		materials,
		greeters,
		voices = b.newSpeaking(),
		music,
		standing = [],
		cell,
		player,
		npcs,
		keys,
		knocks = cw.newKnocks()
	)

# The sounds of a frame, then dt on: heard from `eye` (Skyrim's units) looking toward `heading`.
pub fn stepScene(
	mut s Scene,
	player game.Player,
	walker game.Walker,
	rs game.Residents,
	cast world.CastHead,
	mut w physics.World,
	eye Vec3,
	heading f32,
	dt f32
):
	s.book.hearFrom(eye, heading)
	if not s.started:
		s.standing = s.book.startAmbience(s.cell)
		s.started = true
	s.music.stepMusic(s.book)
	s.player.stepFeet(s.book, walker.animator, player.feetOf(), s.keys[0], w.scene, s.materials)
	for k, r in rs.all:
		if r.present and r.skeleton < s.keys.len:
			s.npcs[r.npc].stepFeet(
				s.book,
				rs.walkers[k].animator,
				r.body.feetOf(),
				s.keys[r.skeleton],
				w.scene, s.materials)
	s.knocks.stepKnocks(s.book, w, s.materials)
	for k in 0..s.greeters.len:
		s.greeters[k].stepGreeter(s.book, s.voices, cast, rs, player.feetOf())
	s.voices.stepSpeaking(s.book.time)
	s.book.time += f64(dt)
	audio.update()

# The log's lines since the last call, those of the music only when `musicOnly`.
# The sound of the doors the actors opened this frame, each at its place.
pub fn doorsOpened(mut s Scene, openings game.DoorOpening[]):
	for o in openings:
		s.book.playActivation(o.base, .DoorMoved(true, 0), o.at)

pub fn newLines(mut s Scene, musicOnly bool) str[]:
	from = s.shown
	s.shown = s.book.log.len
	lines = s.book.logText(from)
	kept = []
	for k in 0..lines.len:
		if not musicOnly or s.book.log[from + k].why.startsWith("music"): kept.push(lines[k].copy())
	kept

# The cast's actor `npc` says the line whose FUZ has this key from `head` (Skyrim's units), its
# lip track followed (mouthOf); the hook the dialogue says its responses through.
pub fn say(mut s Scene, npc i64, key str, text str, head Vec3) bool:
	s.voices.speak(s.book, npc, key, text, head, "{text}")

# The weights of the cast's actor `npc`'s lip targets (skyrim.lipTarget's order) now, none when it
# says nothing.
pub fn mouthOf(s Scene, npc i64) f32[]?:
	s.voices.lipWeightsOf(npc, s.book.time)

# A voice line said by an actor of the cast: its FUZ played from the actor's head in the voices'
# category through the dialogue's 3D output model (the default objects' DDSC and DOP2), and its lip
# track followed while it plays. The hook the hellos and the dialogue's responses both say through.

import skyrim
import skyrim.esm

headHeight f32 = 120.0   # above the feet, where a voice comes from

# a line being said: by which of the cast, since when, its lip track
pub type Speech:
	npc i64
	started f64
	seconds f64
	lip skyrim.Lip
	text str

pub type Speaking:
	category i64
	model i64
	lines Speech[] = []

pub fn newSpeaking(mut b Book) Speaking:
	Speaking(
		category = b.plugin.defaultObject("DDSC") ?? 0,
		model = b.plugin.defaultObject("DOP2") ?? 0
	)

# the line's lip track, none when its FUZ has none
fn lipOf(b Book, key str) skyrim.Lip?:
	bytes = try b.install.installRead(key)
	fuz = skyrim.readFuz(bytes) ?? return none
	skyrim.readLip(fuz.lip) ?? none

# The cast's actor `npc` says the line whose FUZ has this key at `head` (Skyrim's units); whether
# the voice played.
pub fn speak(
	mut s Speaking,
	mut b Book,
	npc i64,
	key str,
	text str,
	head Vec3,
	why str
) bool:
	voice = b.playFile(key, s.category, s.model, head, why) ?? return false
	_ = voice
	lip = b.lipOf(key) ?? skyrim.Lip(lead = 0, frames = [])
	seconds = lip.frames.len / skyrim.lipFramesPerSecond
	s.lines.push(Speech(npc, started = b.time, seconds, lip, text = text.copy()))
	true

# the lines still playing at `now`
pub fn stepSpeaking(mut s Speaking, now f64):
	s.lines = s.lines.filter(now - .started < .seconds)

# The weights of the head's TRI morphs (skyrim.lipTarget's order) of the cast's actor `npc` now:
# its line's lip track while it speaks, none when it does not.
pub fn lipWeightsOf(s Speaking, npc i64, now f64) f32[]?:
	line = try s.lines.find(.npc == npc)
	line.lip.lipWeights(f32(now - line.started))

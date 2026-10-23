# A cell's standing sounds, started as it opens: its acoustic space's ambient loop (ASPC's SNAM,
# heard as its output model says: the inn's is stereo and not placed), each sound marker (SOUN's
# descriptor, SDSC) at its reference, and the looping sound of each object that has one (a fire's
# MSTT, an activator's or a light's SNAM) at its reference. The game plays a marker's or an
# object's loop while the player is within its output model's max distance; these play from the
# start and the curve leaves those beyond it silent.

import engine.audio
import skyrim.esm

# a loop the cell keeps playing: what it is and where
pub type Standing:
	descriptor i64
	at Vec3
	voice audio.Voice

# the kinds of record whose SNAM is a loop they play where they stand
loopingKinds = ["MSTT", "ACTI", "LIGH"]

# the descriptor a reference of this base plays where it stands, 0 for none
fn standingSound(mut b Book, base i64):
	r = b.plugin.recordOf(base) ?? return 0
	if r.kind == "SOUN": return r.formOf("SDSC") ?? 0
	if r.kind in loopingKinds: return r.formOf("SNAM") ?? 0
	0

# Starts the cell's ambient loop and the loops of its markers and objects; those started.
pub fn startAmbience(mut b Book, cell esm.Cell) Standing[]:
	out = []
	if b.plugin.recordOf(cell.acoustics) is space and space.formOf("SNAM") is ambient:
		if b.playDescriptor(ambient, b.listener, "the acoustic space's loop") is v:
			out.push(Standing(descriptor = ambient, at = b.listener, voice = v))
	for r in cell.refs:
		if r.disabled: continue
		id = b.standingSound(r.base)
		if id == 0: continue
		why = "{b.plugin.baseRecord(r.base)?.editorId ?? ""} {r.formId:08X}"
		if b.playDescriptor(id, r.position, why) is v:
			out.push(Standing(descriptor = id, at = r.position, voice = v))
	out

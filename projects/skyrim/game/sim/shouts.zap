# Shouts as the plugin defines them (SHOU: up to three words of power, each with the spell it
# casts and the seconds it takes to recover; WOOP: the dragon word and its translation) and what an
# actor shouts with: the shouts it knows, how many of each one's words it has unlocked, the one it
# has ready. A new game knows none (they come with the dragon souls and the walls of words), so a
# shout is given. Layouts after UESP's Skyrim Mod File Format and xEdit's definitions.

import skyrim
import skyrim.esm

# a word of a shout: its WOOP, the SPEL cast when it is the last said, the seconds before the next shout
pub type ShoutWord:
	word i64
	dragon str   # the word in the dragon tongue
	translation str
	spell i64
	recovery f32

pub type Shout:
	formId i64
	editorId str
	name str
	words ShoutWord[]

# the shout with this form id, none when it is no SHOU; each SNAM is a word, a spell and a recovery
pub fn shoutOf(mut plugin esm.Esm, names skyrim.Strings, formId i64) Shout?:
	r = try plugin.recordOf(formId)
	if r.kind != "SHOU": return none
	words = []
	for f in r.fields:
		if f.tag != "SNAM" or f.size < 12: continue
		word = i64(r.body.u32le(f.at))
		w = plugin.recordOf(word)
		words.push(
			ShoutWord(
				word,
				dragon = names.localText(w ?? r, "FULL") if w != none else "",
				translation = names.localText(w ?? r, "TNAM") if w != none else "",
				spell = r.body.u32le(f.at + 4),
				recovery = r.body.f32le(f.at + 8)
			)
		)
	Shout(
		formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		name = names.localText(r, "FULL"),
		words
	)

# Learns the shout and the spells of its words when the world does not know it yet; whether it is a shout.
pub fn learnShout(mut w GameWorld, mut plugin esm.Esm, names skyrim.Strings, formId i64) bool:
	if w.shouts.get(formId) != none: return true
	s = plugin.shoutOf(names, formId) ?? return false
	for word in s.words:
		w.learnSpell(plugin, names, word.spell)
	w.shouts[formId] = s
	true

# The actor knows the shout with the first `words` of its words unlocked (at most the shout's
# own); it is made ready when it had none ready. Why not when the world does not know the shout.
pub fn giveShout(mut w GameWorld, refId i64, formId i64, words i64) str?:
	s = w.shouts.get(formId) ?? return "{formId:08X} is no shout the world knows"
	if w.actors.get(refId) == none: return "{refId:08X} is no actor"
	m = w.actors[refId].magic.copy()
	unlocked = words.clamp(1, s.words.len)
	if m.shouts.indexOf(formId) is at:
		m.words[at] = m.words[at].max(unlocked)
	else:
		m.shouts.push(formId)
		m.words.push(unlocked)
	if m.shout == 0: m.shout = formId
	w.actors[refId].magic = m
	none

# how many words of the shout the actor has unlocked, 0 when it does not know it
pub fn wordsKnown(w GameWorld, refId i64, formId i64) i64:
	m = (w.actors.get(refId) ?? return 0).magic
	at = m.shouts.indexOf(formId) ?? return 0
	m.words[at]

# readies a shout the actor knows; why not when it does not
pub fn readyShout(mut w GameWorld, refId i64, formId i64) str?:
	if w.wordsKnown(refId, formId) == 0: return "{formId:08X} is no shout the actor knows"
	w.actors[refId].magic.shout = formId
	none

# the shouts the actor knows, in the order it learned them
pub fn knownShouts(w GameWorld, refId i64) i64[]:
	(w.actors.get(refId) ?? return []).magic.shouts.copy()

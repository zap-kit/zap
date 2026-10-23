# What an actor wears, as the plugin gives it: its race's skin (an ARMO whose armor addons, ARMA,
# are the naked body's parts), the armor it puts on over it (which hides the skin's addons of the
# biped slots it covers) and its head parts (HDPT: the race's defaults, those the actor names in
# their place, and the extra parts each one brings). An addon is for the races it names (its RNAM
# and its MODL list) and gives a male (MOD2) and a female (MOD3) model.

import skyrim
import skyrim.esm

# a model an actor wears and the slot it fills
pub type Worn:
	slot str   # the biped slot as the race names it ("BODY", "Hands"), or the head part's kind
	key str   # the model's archive key

# the kinds of head part, by HDPT's PNAM
headPartKinds = ["Misc", "Face", "Eyes", "Hair", "FacialHair", "Scar", "Eyebrows"]

# the record with this form id, or why there is none
pub fn needRecord(mut plugin esm.Esm, formId i64) esm.Record ? str:
	plugin.recordOf(formId) ?? return "no record {formId:08X} in {plugin.path}"

# the biped slots an armor or an addon covers: BOD2's or the older BODT's first word
fn slotMask(r esm.Record):
	for tag in ["BOD2", "BODT"]:
		if r.formOf(tag) is mask: return mask
	0

# the race's name of the lowest slot of the mask (slot 30 is bit 0)
fn slotName(names str[], mask i64):
	for bit in 0..32:
		if (mask >> bit) & 1 != 0:
			return names[bit].copy() if bit < names.len and names[bit] != "" else "slot {30 + bit}"
	"none"

# an armor addon (ARMA) worn: its record, the biped slots it fills and its model's key
pub type WornAddon:
	addon i64
	mask i64
	key str

# the addons of an armor made for the race, each with the model of the sex
fn addonsFor(mut plugin esm.Esm, armor esm.Record, race i64, female bool) WornAddon[] ? str:
	out = []
	for id in esm.formsOf(armor.body, armor.fields, "MODL"):
		addon = try plugin.needRecord(id)
		races = esm.formsOf(addon.body, addon.fields, "MODL")
		if addon.formOf("RNAM") != race and race not in races: continue
		path = esm.textOf(addon.body, addon.fields, "MOD3" if female else "MOD2")
		if path != "":
			out.push(WornAddon(addon = id, mask = addon.slotMask(), key = skyrim.modelKey(path)))
	out

# the fields of the race's head data for the sex: after NAM0, under MNAM (male) or FNAM (female)
pub fn raceHeadFields(race esm.Record, female bool) esm.Field[]:
	out = []
	headData = false
	isFemale = false
	for f in race.fields:
		if f.tag == "NAM0": headData = true
		if f.size == 0 and f.tag == "MNAM": isFemale = false
		if f.size == 0 and f.tag == "FNAM": isFemale = true
		if headData and isFemale == female: out.push(f.copy())
	out

# the head parts a race gives the sex (its head data's HEAD fields)
pub fn raceHeadParts(race esm.Record, female bool) i64[]:
	race.raceHeadFields(female).filter(.tag == "HEAD").map(i64(race.body.u32le(.at)))

# The head parts an actor wears: the race's for the sex, the actor's own (`own`, its PNAM) in
# place of those of the same kind, then the extra parts (HNAM) each brings.
pub fn chosenHeadParts(
	mut plugin esm.Esm,
	own i64[],
	race esm.Record,
	female bool
) esm.Record[] ? str:
	chosen = []
	for id in own:
		chosen.push(try plugin.needRecord(id))
	for id in race.raceHeadParts(female):
		part = try plugin.needRecord(id)
		if not chosen.any(.headKind() == part.headKind()): chosen.push(part)
	for i in 0..chosen.len:
		for id in esm.formsOf(chosen[i].body, chosen[i].fields, "HNAM"):
			chosen.push(try plugin.needRecord(id))
	chosen

# the kind of a head part (HDPT's PNAM) by name
pub fn headKind(part esm.Record) str:
	kind = part.formOf("PNAM") ?? 0
	headPartKinds[kind].copy() if kind < headPartKinds.len else "head part {kind}"

# the models of head parts, those with one
pub fn headModels(parts esm.Record[]) Worn[]:
	out = []
	for part in parts:
		path = esm.textOf(part.body, part.fields, "MODL")
		if path != "": out.push(Worn(slot = part.headKind(), key = skyrim.modelKey(path)))
	out

# The addons an actor of the race and sex wears below the head with the armors `outfit` put on:
# the outfit's, then the skin's (`skin`, else the race's) for the slots the outfit leaves
# bare; or why the plugin cannot say.
pub fn wornAddons(
	mut plugin esm.Esm,
	raceId i64,
	female bool,
	skin i64,
	outfit i64[]
) WornAddon[] ? str:
	race = try plugin.needRecord(raceId)
	out = []
	covered = 0
	for id in outfit:
		armor = try plugin.needRecord(id)
		covered |= armor.slotMask()
		out.extend(try plugin.addonsFor(armor, raceId, female))
	skinId = skin if skin != 0 else race.formOf("WNAM") ?? return "race {raceId:08X} has no skin"
	skinArmor = try plugin.needRecord(skinId)
	for a in try plugin.addonsFor(skinArmor, raceId, female):
		if a.mask & covered == 0: out.push(a)
	out

# The footstep set (FSTS) of the worn addons: the one on the feet's, else the first that names
# one; 0 for none.
pub fn footstepSetOf(mut plugin esm.Esm, addons WornAddon[]) i64:
	feet = 0x80   # biped slot 37
	first = 0
	for a in addons:
		r = plugin.recordOf(a.addon) ?? continue
		set = r.formOf("SNDD") ?? continue
		if a.mask & feet != 0: return set
		if first == 0: first = set
	first

# the models of the outfit's addons and the skin's (wornAddons), each with its slot's name
pub fn bodyModels(mut plugin esm.Esm, raceId i64, female bool, skin i64, outfit i64[]) Worn[] ? str:
	race = try plugin.needRecord(raceId)
	names = race.fields.filter(.tag == "NAME").map(race.body.cStringAt(.at))
	addons = try plugin.wornAddons(raceId, female, skin, outfit)
	addons.map(Worn(slot = names.slotName(.mask), key = .key.copy()))

# The models the actor `npc` wears with the armors `outfit` put on: its body's and its head
# parts'; or why the plugin cannot say.
pub fn actorModels(mut plugin esm.Esm, npc i64, outfit i64[]) Worn[] ? str:
	actor = try plugin.needRecord(npc)
	raceId = actor.formOf("RNAM") ?? return "actor {npc:08X} has no race"
	race = try plugin.needRecord(raceId)
	female = ((actor.formOf("ACBS") ?? 0) & 1) != 0
	out = try plugin.bodyModels(raceId, female, actor.formOf("WNAM") ?? 0, outfit)
	own = esm.formsOf(actor.body, actor.fields, "PNAM")
	out.extend(headModels(try plugin.chosenHeadParts(own, race, female)))
	out

# Spells and magic effects as the plugin defines them, and what an actor casts with: the spells it
# knows, the ones in its hands and its favorites. Layouts after UESP's Skyrim Mod File Format and
# xEdit's record definitions for the Special Edition: SPEL (SPIT: the cost the Creation Kit
# computed, flags, the type, the charge time, the cast type, the delivery, the cast duration, the
# range and the perk that halves the cost; EFID, EFIT and the conditions that follow it the effects
# the spell has, ETYP its hands), MGEF (DATA: flags, the base cost, the school, the resisted value,
# the archetype and the value it changes, the projectile, the cast type and delivery, the casting
# art, the light and the shaders, the skill usage) and PROJ (DATA: flags, type, speed, range, the
# collision radius and the relaunch interval of a flame).
#
# The cost of a spell is the record's: the Creation Kit stores each spell's cost computed from its
# effects (base cost times magnitude and duration, to the 1.1: Flames 8 for a second at 1.5 is 14,
# Healing 10 at 1 is 12, the cost of a second held). Skyrim's skill does not enter it: the GMSTs
# fMagicCasterPCSkillCostBase and its neighbours are Oblivion's and unused; only perks lower a
# cost. An effect whose conditions do not hold (a perk's) is left out of the spell, as a new game
# has no perks.

import skyrim
import skyrim.esm

# SPIT's types
pub spellKindSpell = 0
pub spellKindPower = 2
pub spellKindLesserPower = 3
pub spellKindAbility = 4

# MGEF DATA's flags
pub flagHostile = 0x1
pub flagRecover = 0x2
pub flagDetrimental = 0x4
pub flagNoDuration = 0x200
pub flagNoMagnitude = 0x400
pub flagHideInUi = 0x8000

# the condition function HasPerk: an effect that needs a perk of its caster does not hold at a new game
hasPerkFunction = 448

# MGEF archetype 0: it changes an actor value by its magnitude
pub archetypeValueModifier = 0

# how a spell is cast: held or let go, and where it goes
pub type CastType:
	Constant
	FireAndForget
	Concentration

pub type Delivery:
	Caster
	Touch
	Aimed
	TargetActor
	TargetLocation

pub type MagicEffect:
	formId i64
	editorId str
	name str
	flags i64
	baseCost f32
	skill str   # the school's actor value, "" for none
	resist str   # the actor value that lowers it, "" for none
	archetype i64
	value str   # the actor value it changes
	projectile i64   # PROJ, 0 for none
	castingArt i64   # ARTO or EFSH shown on the caster's hand
	hitShader i64   # EFSH on the one it hits
	light i64   # LIGH the casting lights the hand with
	castType CastType
	delivery Delivery
	skillUsage f32
	minSkill i64
	taperWeight f32   # DATA at 28, 52, 56: a magnitude tapers in the last taperDuration seconds
	taperCurve f32
	taperDuration f32
	holds bool   # its own conditions hold
	soundLevel i64 = 0   # DATA at 140: how loud casting it is, 0 Loud, 1 Normal, 2 Silent, 3 Very Loud
	perk i64 = 0   # DATA at 136: the perk the actor holds while the effect lasts (an ability's, Rested)

pub type Spell:
	formId i64
	editorId str
	name str
	kind i64
	cost f32   # magicka: all of it for a spell let go, a second's of it for one held
	castType CastType
	target Delivery
	chargeTime f32
	castDuration f32
	range f32
	equipSlot str   # ETYP's editor id: EitherHand, RightHand, LeftHand, BothHands
	effects Effect[]   # those that hold, in order
	school str   # the actor value of the first effect that has a school, "" for none
	level i64   # the skill its dearest effect asks: 0 novice, 25 apprentice, 50 adept...
	castingPerk i64 = 0   # SPIT at 32: the perk that lowers its cost (a school's novice perk)

# a PROJ: what a spell throws
pub type Projectile:
	formId i64
	editorId str
	model str
	kind i64   # 1 missile, 2 lobber, 4 beam, 8 flame, 16 cone, 32 barrier, 64 arrow
	speed f32
	range f32
	collisionRadius f32
	relaunch f32   # seconds between the particles of a flame

pub projectileFlame = 8

# an actor's casting: the spells it knows, in the left and the right hand, and its favorites
pub type Magic:
	known i64[] = []
	left i64 = 0
	right i64 = 0
	favorites i64[] = []
	hotkeys i64[] = [0, 0, 0, 0, 0, 0, 0, 0]   # the form on each of the eight hotkeys, 0 for none
	shouts i64[] = []   # the shouts it knows, with the words of each it has unlocked in `words`
	words i64[] = []
	shout i64 = 0   # the shout it has ready to say, 0 for none

fn castTypeOf(n i64) CastType:
	match n:
		0: .Constant
		1: .FireAndForget
		_: .Concentration

fn deliveryOf(n i64) Delivery:
	match n:
		0: .Caster
		1: .Touch
		2: .Aimed
		3: .TargetActor
		_: .TargetLocation

fn avName(index i64):
	if index < 0 or index >= actorValueNames.len: return ""
	actorValueNames[index].copy()

fn i32Of(r esm.Record, tag str, offset i64) i64:
	at = esm.dataOf(r.fields, tag) ?? return -1
	r.body.i32le(at + offset)

# the magic effect with this form id, none when it is no MGEF
pub fn magicEffectOf(mut plugin esm.Esm, names skyrim.Strings, formId i64) MagicEffect?:
	r = try plugin.recordOf(formId)
	if r.kind != "MGEF": return none
	conditions = esm.conditionsIn(r.body, r.fields)
	MagicEffect(
		formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		name = names.localText(r, "FULL"),
		flags = r.u32Of("DATA", 0),
		baseCost = r.f32Of("DATA", 4),
		skill = avName(r.i32Of("DATA", 12)),
		resist = avName(r.i32Of("DATA", 16)),
		archetype = r.u32Of("DATA", 64),
		value = avName(r.i32Of("DATA", 68)),
		projectile = r.u32Of("DATA", 72),
		castingArt = r.u32Of("DATA", 92),
		hitShader = r.u32Of("DATA", 32),
		light = r.u32Of("DATA", 24),
		castType = castTypeOf(r.u32Of("DATA", 80)),
		delivery = deliveryOf(r.u32Of("DATA", 84)),
		skillUsage = r.f32Of("DATA", 104),
		minSkill = r.u32Of("DATA", 40),
		taperWeight = r.f32Of("DATA", 28),
		taperCurve = r.f32Of("DATA", 52),
		taperDuration = r.f32Of("DATA", 56),
		soundLevel = r.u32Of("DATA", 140),
		perk = r.u32Of("DATA", 136),
		holds = conditions.all(.function != hasPerkFunction or .holds(0.0, .value))
	)

# the projectile with this form id, none when it is no PROJ
pub fn projectileOf(mut plugin esm.Esm, formId i64) Projectile?:
	r = try plugin.recordOf(formId)
	if r.kind != "PROJ": return none
	Projectile(
		formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		model = esm.textOf(r.body, r.fields, "MODL"),
		kind = r.body.u16le((esm.dataOf(r.fields, "DATA") ?? 0) + 2),
		speed = r.f32Of("DATA", 8),
		range = r.f32Of("DATA", 12),
		collisionRadius = r.f32Of("DATA", 72),
		relaunch = r.f32Of("DATA", 80)
	)

# the effects of a spell record whose own conditions hold (a perk of the caster)
fn listedEffects(mut plugin esm.Esm, r esm.Record):
	starts = []
	for k, f in r.fields:
		if f.tag == "EFID": starts.push(k)
	kept = []
	for n, k in starts:
		end = starts[n + 1] if n + 1 < starts.len else r.fields.len
		own = r.fields[k..end]
		e = Effect(effect = r.body.u32le(own[0].at), magnitude = 0.0, area = 0, duration = 0)
		if own.len > 1 and own[1].tag == "EFIT" and own[1].size >= 12:
			e.magnitude = r.body.f32le(own[1].at)
			e.area = r.body.u32le(own[1].at + 4)
			e.duration = r.body.u32le(own[1].at + 8)
		conditions = own.filter(.tag == "CTDA" and .size >= 28).map(
			esm.conditionAt(r.body, .at, .size))
		if conditions.isEmpty or (plugin.newGameHolds(conditions, 0) ?? false): kept.push(e.copy())
	kept

# the spell with this form id: its record, the effects that hold; none when it is no SPEL
pub fn spellOf(mut plugin esm.Esm, names skyrim.Strings, formId i64) Spell?:
	r = try plugin.recordOf(formId)
	if r.kind != "SPEL": return none
	slot = ""
	if r.formOf("ETYP") is e:
		if plugin.recordOf(e) is rec: slot = esm.textOf(rec.body, rec.fields, "EDID")
	Spell(
		formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		name = names.localText(r, "FULL"),
		kind = r.u32Of("SPIT", 8),
		cost = f32(r.u32Of("SPIT", 0)),
		castType = castTypeOf(r.u32Of("SPIT", 16)),
		target = deliveryOf(r.u32Of("SPIT", 20)),
		chargeTime = r.f32Of("SPIT", 12),
		castDuration = r.f32Of("SPIT", 24),
		range = r.f32Of("SPIT", 28),
		equipSlot = slot,
		effects = plugin.listedEffects(r),
		school = "",
		level = 0,
		castingPerk = r.u32Of("SPIT", 32)
	)

# The magic effect with this form id, learned from the plugin when the world does not know it yet;
# none when it is no MGEF.
pub fn learnMagicEffect(
	mut w GameWorld,
	mut plugin esm.Esm,
	names skyrim.Strings,
	formId i64
) MagicEffect?:
	if w.magicEffects.get(formId) == none:
		if plugin.magicEffectOf(names, formId) is m:
			if m.perk != 0: w.learnPerk(plugin, names, m.perk)
			w.magicEffects[formId] = m
	w.magicEffects.get(formId)?.copy()

# Learns the spell, its magic effects and their projectiles from the plugin when the world does
# not know the spell yet, its school and level filled in; whether it is a spell.
pub fn learnSpell(
	mut w GameWorld,
	mut plugin esm.Esm,
	names skyrim.Strings,
	formId i64
) bool:
	if w.spells.get(formId) != none: return true
	s = plugin.spellOf(names, formId) ?? return false
	kept = []
	for e in s.effects:
		m = w.learnMagicEffect(plugin, names, e.effect) ?? continue
		if not m.holds: continue
		kept.push(e.copy())
		if m.projectile != 0 and w.projectiles.get(m.projectile) == none:
			if plugin.projectileOf(m.projectile) is p: w.projectiles[m.projectile] = p
		if s.school.isEmpty: s.school = m.skill.copy()
		s.level = s.level.max(m.minSkill)
	s.effects = kept
	w.spells[formId] = s
	true

# The spells of the actor's record and of its race (SPLO), learned and known to the actor: the
# player's Flames and Healing, the abilities and the powers of its race.
pub fn learnMagic(
	mut w GameWorld,
	mut plugin esm.Esm,
	names skyrim.Strings,
	refId i64,
	npc i64
):
	a = w.actors.get(refId) ?? return
	forms = []
	for id in [npc, a.race]:
		if plugin.recordOf(id) is r: forms.extend(esm.formsOf(r.body, r.fields, "SPLO"))
	known i64[] = []
	for form in forms:
		if form not in known and w.learnSpell(plugin, names, form): known.push(form)
	w.actors[refId].magic.known = known

# an effect the actor lives under, the spell that gives it and the seconds left (0: for as long as
# the actor has the spell, an ability's)
pub type ActiveEffect:
	spell i64
	effect Effect
	remaining f64

# The effects the actor lives under, as the magic menu's Active Effects lists them: those of the
# abilities it knows (a race's resistance, the player's healing rate) whose magic effect is not
# hidden in the interface, then the timed ones (a potion's, consume.zap) with the seconds left.
pub fn activeEffects(w GameWorld, refId i64) ActiveEffect[]:
	out = []
	for form in (w.actors.get(refId) ?? return out).magic.known:
		s = w.spells.get(form) ?? continue
		if s.kind != spellKindAbility: continue
		for e in s.effects:
			m = w.magicEffects.get(e.effect) ?? continue
			if (m.flags & flagHideInUi) == 0:
				out.push(ActiveEffect(spell = form, effect = e.copy(), remaining = 0.0))
	for t in (w.actors.get(refId) ?? return out).effects:
		if t.shown and t.duration > 0.0:
			e = Effect(
				effect = t.effect,
				magnitude = t.magnitude.abs(),
				area = 0,
				duration = i64(t.duration)
			)
			out.push(
				ActiveEffect(spell = t.source, effect = e, remaining = f64(t.duration - t.elapsed))
			)
	out

# whether the actor casts the spell by hand: a spell, a power or a lesser power it knows
pub fn isCastable(w GameWorld, refId i64, form i64) bool:
	a = w.actors.get(refId) ?? return false
	s = w.spells.get(form) ?? return false
	form in a.magic.known and
		(s.kind in [spellKindSpell, spellKindPower, spellKindLesserPower])

# the spells the actor casts by hand, in the order it learned them
pub fn castableSpells(w GameWorld, refId i64) i64[]:
	(w.actors.get(refId) ?? return []).magic.known.filter(w.isCastable(refId, it))

# the sounds the player's spell put in a hand and taken out play (ActorEquipManager's 0x1406de200,
# 0x1406de3a0 and 0x1406de2d0, 0x1406de3e0)
pub spellSelectSound = "UIMagicSelect"
pub spellUnselectSound = "UIMagicUnselect"

# whether a spell goes in the left hand (not when its slot is the right one alone) and in the right
fn fitsHand(s Spell, left bool):
	match s.equipSlot:
		"RightHand": not left
		"LeftHand": left
		_: true

# the spell put in the actor's left or right hand, the weapon or shield that held that hand taken
# off, the spell the other hand held kept unless this one takes both; why not when it cannot be
pub fn equipSpell(mut w GameWorld, refId i64, form i64, left bool) str?:
	if not w.isCastable(refId, form): return "{form:08X} is no spell the actor casts"
	s = w.spells[form]
	if not s.fitsHand(left): return "{s.name} does not go in that hand"
	both = s.equipSlot == "BothHands"
	if w.inventories.getMut(refId) is mut inv:
		if left or both: inv.freeHand(w.items, true)
		if not left or both: inv.freeHand(w.items, false)
	m = w.actors[refId].magic.copy()
	if left or both: m.left = form
	if not left or both: m.right = form
	w.actors[refId].magic = m
	if refId == w.player: w.playUi(spellSelectSound)
	none

# the spell the actor holds in its hand, 0 for none
pub fn spellIn(w GameWorld, refId i64, left bool) i64:
	m = (w.actors.get(refId) ?? return 0).magic
	m.left if left else m.right

# takes the spell out of the hand it is in
pub fn unequipSpell(mut w GameWorld, refId i64, form i64):
	if w.actors.get(refId) == none: return
	held = false
	if w.actors[refId].magic.left == form:
		w.actors[refId].magic.left = 0
		held = true
	if w.actors[refId].magic.right == form:
		w.actors[refId].magic.right = 0
		held = true
	if held and refId == w.player: w.playUi(spellUnselectSound)

# a hand that holds a weapon, a shield or a torch holds no spell: the spells of those hands taken out
pub fn settleHands(mut w GameWorld, refId i64):
	inv = w.inventories.get(refId) ?? return
	if w.actors.get(refId) == none: return
	if inv.heldIn(w.items, false) != 0: w.actors[refId].magic.right = 0
	if inv.heldIn(w.items, true) != 0: w.actors[refId].magic.left = 0

# marks the spell as a favorite or not
pub fn setFavoriteSpell(mut w GameWorld, refId i64, form i64, favorite bool):
	if w.actors.get(refId) == none: return
	list = w.actors[refId].magic.favorites.filter(it != form)
	if favorite: list.push(form)
	w.actors[refId].magic.favorites = list

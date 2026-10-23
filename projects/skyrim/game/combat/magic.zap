# A fighter's spells cast in the fight. A spell cast by the hand costs its magicka (the record's
# cost: all of it when the spell is let go at once, a second's of it every second while a
# concentration spell is held, the actor's magicka stopping it at 0) and its effects play at
# once: an effect that changes health, magicka or stamina (the archetype 0 value modifier, the
# only one the inn's spells use) takes its magnitude a second from the target for as long as it is
# held (a held spell) or, for a spell let go, its magnitude a second for its duration, all given at
# once; the target's resistance to the effect's element (fire resist) and to magic
# lowering what a harmful one does (a spell let go gives all of it at once). A spell aimed ahead reaches the nearest living fighter in
# front of the caster within the projectile's range, as wide as the projectile's collision radius
# and the fighter's body (the capsule's 15 units); the damage goes through `hurt` as a blow does,
# so a crime, a death or an essential actor's bleedout follow as they follow a sword. A spell
# the effects of which the model does not know (a summon, an invisibility) costs its magicka and
# says so in the fight's lines. Magicka comes back as everything else does, after the delay since
# it last fell (fight.zap), so a held spell keeps it from coming back.

import game.sim
import game.stealth

# the body of a fighter a stream or a bolt meets: the capsule's radius
bodyRadius f32 = 15.0

# a spell cast and not ended
pub type Cast:
	spell i64
	left bool   # the left hand's
	elapsed f32 = 0.0
	target i64 = -1   # the fighter it is on, -1 for none
	reach f32 = 0.0   # how far ahead it goes: to its target, else its projectile's range

# why the fighter cannot cast the spell, none when it can
pub fn whyNotCast(f Fight, k i64, form i64) str?:
	x = f.fighters[k]
	if x.mode in [.Swing, .Staggered, .Bleedout, .Dead, .Fled]:
		return "{x.name} is in no state to cast"
	if x.casting != none: return "{x.name} is casting"
	s = f.w.spells.get(form) ?? return "{form:08X} is no spell"
	if not f.w.isCastable(x.refId, form): return "{x.name} does not know {s.name}"
	have = f.w.actors[x.refId].valueOf("magicka")
	cost = f.w.spellCost(x.refId, s)
	need = cost if s.castType != .Concentration else cost * f.step
	if have < need: return "{x.name} has not the magicka for {s.name}"
	none

# A spell cast is heard: each of its effects makes the caster's detection event at its place
# (0x1405cdf50), as loud as the effect's casting sound level says; the last effect's stays.
fn makeSpellNoise(mut f Fight, k i64, s sim.Spell):
	x = f.fighters[k]
	for e in s.effects:
		m = f.w.magicEffects.get(e.effect) ?? continue
		f.w.createEvent(x.refId, x.at, f.w.settings.soundValue(m.soundLevel), x.refId)
	if x.player: f.listen()

# The magicka and then effects of the spell, held in the fighter's hand; why not when it cannot be
# cast. A spell let go has its effects at once and is over; a held one is cast until stopCast.
pub fn startCast(mut f Fight, k i64, form i64, left bool) str?:
	if f.whyNotCast(k, form) is why: return why
	s = f.w.spells[form].copy()
	x = f.fighters[k]
	f.note("{x.name} casts {s.name} from the {"left" if left else "right"} hand")
	f.fighters[k].casting = Cast(spell = form, left)
	f.makeSpellNoise(k, s)
	if s.castType != .Concentration:
		f.spend(k, f.w.spellCost(f.fighters[k].refId, s))
		f.castStep(k, 1.0)
		f.practiceCast(k, s, 1.0)
		f.fighters[k].casting = none
	none

# why the fighter cannot say this many words of the shout, none when it can
pub fn whyNotShout(f Fight, k i64, form i64, words i64) str?:
	x = f.fighters[k]
	if x.mode in [.Swing, .Staggered, .Bleedout, .Dead, .Fled]:
		return "{x.name} is in no state to shout"
	s = f.w.shouts.get(form) ?? return "{form:08X} is no shout"
	known = f.w.wordsKnown(x.refId, form)
	if known == 0: return "{x.name} does not know {s.name}"
	if words < 1 or words > known: return "{x.name} has {known} words of {s.name}, not {words}"
	if f.time < x.shoutReadyAt:
		return "{x.name} cannot shout again for {x.shoutReadyAt - f.time:.1} s"
	none

# The words said of the shout: the spell of the last one cast at once (a shout costs no magicka)
# and the time before the next shout, the word's recovery lengthened by the fighter's
# shoutrecoverymult (a value of 0 is a fighter that has none, the base 1); why not when it cannot.
pub fn startShout(mut f Fight, k i64, form i64, words i64) str?:
	if f.whyNotShout(k, form, words) is why: return why
	s = f.w.shouts[form].copy()
	word = s.words[words - 1].copy()
	x = f.fighters[k].copy()
	f.note("{x.name} shouts {s.name} ({words} words, {s.words[words - 1].dragon})")
	f.fighters[k].casting = Cast(spell = word.spell, left = false)
	f.castStep(k, 1.0)
	f.fighters[k].casting = none
	mult = f.w.actors[x.refId].valueOf("shoutrecoverymult")
	f.fighters[k].shoutReadyAt = f.time + word.recovery * (mult if mult > 0.0 else 1.0)
	none

# lets go of the held spell
pub fn stopCast(mut f Fight, k i64):
	x = f.fighters[k]
	if x.casting is c: f.note("{x.name} stops casting {f.w.spells[c.spell].name}")
	f.fighters[k].casting = none

fn spend(mut f Fight, k i64, magicka f32):
	refId = f.fighters[k].refId
	f.w.actors[refId].damageValue("magicka", magicka)
	f.fighters[k].damagedAt["magicka"] = f.time

# the living fighter the cast reaches ahead of fighter k, within range and the width of its
# projectile; none when no one stands in the way
fn streamTarget(f Fight, k i64, range f32, width f32):
	x = f.fighters[k]
	best i64? = none
	nearest = range
	for j, other in f.fighters:
		if j == k or other.isOut(): continue
		d = Vec3(other.at.x - x.at.x, other.at.y - x.at.y, 0)
		along = d.x * x.facing.x + d.y * x.facing.y
		if along <= 0.0 or along > nearest: continue
		across = (d.x * x.facing.y - d.y * x.facing.x).abs()
		if across > width + bodyRadius: continue
		best = j
		nearest = along
	best

# fighter j changed by `amount` of the value, as a blow or a healing: a harmful change of health
# is a hurt (the crime, the death), the others move the value
fn changeValue(mut f Fight, j i64, k i64, value str, amount f32, harm bool):
	refId = f.fighters[j].refId
	if not harm:
		f.w.actors[refId].restoreNamed(value, amount)
		return
	if value == "health":
		f.hurt(j, k, amount)
		return
	f.w.actors[refId].damageValue(value, amount)
	f.fighters[j].damagedAt[value.copy()] = f.time

# The effects of the cast spell over dt seconds for fighter k (a spell let go: given once, the dt
# unused); the target found ahead for an aimed one, the cast's reach kept for the picture.
pub fn castStep(mut f Fight, k i64, dt f32):
	c = f.fighters[k].casting ?? return
	s = f.w.spells[c.spell].copy()
	foe i64? = none
	reach = 0.0
	for e in s.effects:
		m = f.w.magicEffects.get(e.effect) ?? continue
		if m.archetype != sim.archetypeValueModifier or m.value.isEmpty:
			f.say("{f.fighters[k].name}: {m.editorId} has an effect the model does not play")
			continue
		holder = k
		if s.target != .Caster:
			range = (f.w.projectiles.get(m.projectile)?.range ?? 0.0).max(s.range)
			width = f.w.projectiles.get(m.projectile)?.collisionRadius ?? 0.0
			foe = f.streamTarget(k, range, width)
			reach = range
			if foe is j:
				holder = j
				reach = f.fighters[k].at.distance(f.fighters[j].at)
			else:
				continue
		a = f.w.actors[f.fighters[holder].refId].copy()
		harm = m.isHarmful()
		share = a.resistedShare(m) if harm else 1.0
		span = dt if s.castType == .Concentration else f32(e.duration.max(1))
		amount = e.magnitude * share * span
		f.changeValue(holder, k, m.value, amount, harm)
	f.fighters[k].casting = Cast(spell = c.spell, left = c.left, elapsed = c.elapsed + dt,
		target = foe ?? -1, reach)

# a line in the fight's lines the first time it is said
fn say(mut f Fight, line str):
	if f.lines.any(.endsWith(line)): return
	f.note(line)

# One step of fighter k's held spell: its second's cost taken, then its effects over the step; the
# cast ends when the magicka does
pub fn stepCast(mut f Fight, k i64):
	c = f.fighters[k].casting ?? return
	s = f.w.spells[c.spell].copy()
	cost = f.w.spellCost(f.fighters[k].refId, s) * f.step
	if f.w.actors[f.fighters[k].refId].valueOf("magicka") < cost or f.fighters[k].isOut():
		f.stopCast(k)
		return
	f.spend(k, cost)
	f.castStep(k, f.step)
	f.practiceCast(k, s, f.step)

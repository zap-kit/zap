# What a fight teaches the player's skills, as SkyrimSE.exe 1.7.104 credits them where a hit lands
# (0x1406cd2f0) and a spell is cast (SpellItem's usage data 0x140155540, the effects' update
# 0x1405bd9..): his swing with a weapon gives the weapon's base damage in its skill (fists none),
# a bash fShieldBashSkillUseBase with a shield, fWeaponBashSkillUseBase without, in Block; a blow
# that hurts him gives Block the damage his block took off (times fWeaponBlockSkillUseMult plus
# fWeaponBlockSkillUseBase), or, unblocked, the damage that got through armor to Light Armor or
# Heavy Armor, chosen by a roll of six over the weights of what he wears (his body piece twice, a
# shield too; the clothing and unrated pieces none). A spell he casts gives its school the spell's
# cost times its costliest effect's skill usage, once when let go, a second's worth every second
# when held (the Sneak skill is in game/sim/skills.zap).

import game.sim

# The Block or weapon skill the player's landed swing at `damage` (after armor and block) trains.
pub fn practiceHit(mut f Fight, x Fighter, strike Strike, damage f32):
	if not x.player or damage <= 0.0: return
	s = f.w.settings
	if strike == .Bash:
		which = "shield" if x.shield != 0 else "weapon"
		bashed = damage * s.gmst("f{which}bashskillusemult") + s.gmst("f{which}bashskillusebase")
		f.w.useSkill("block", bashed)
		return
	if x.weapon != 0 and not x.skill.isEmpty: f.w.useSkill(x.skill, x.baseDamage)

# the armor skill a blow trains the wearer in: by the weights, six rolls to a piece's share
fn armorSkillTrained(mut f Fight, wearer Fighter):
	roll = i64(f.rng.nextFloat(0.0, 6.0)).min(5)
	if roll < wearer.lightWeight: return "lightarmor"
	if roll < wearer.lightWeight + wearer.heavyWeight: return "heavyarmor"
	""

# The skill the player's armor or block trains for a blow of `physical` damage (after armor, before
# block) of which the block took `blocked` (a share).
pub fn practiceDefence(mut f Fight, target Fighter, physical f32, blocked f32):
	if not target.player or physical <= 0.0: return
	s = f.w.settings
	if blocked > 0.0:
		f.w.useSkill(
			"block",
			physical * blocked * s.gmst("fweaponblockskillusemult") +
				s.gmst("fweaponblockskillusebase")
		)
		return
	trained = f.armorSkillTrained(target)
	if not trained.isEmpty: f.w.useSkill(trained, physical)

# The school and amount of experience casting the spell gives for dt seconds of it: its cost times
# the usage of its costliest effect (by base cost and magnitude); none for a spell of no school.
pub fn spellPractice(w sim.GameWorld, spell sim.Spell) (str, f32):
	best = 0.0
	usage = 0.0
	school = ""
	for e in spell.effects:
		m = w.magicEffects.get(e.effect) ?? continue
		if m.skill.isEmpty: continue
		rank = m.baseCost * e.magnitude.max(1.0) * f32(e.duration.max(1))
		if rank > best or school.isEmpty:
			best = rank
			usage = m.skillUsage
			school = m.skill.copy()
	(school, spell.cost * usage)

# fighter k's spell practised for dt seconds when it is the player casting
pub fn practiceCast(mut f Fight, k i64, spell sim.Spell, dt f32):
	if not f.fighters[k].player: return
	school, amount = f.w.spellPractice(spell)
	if not school.isEmpty: f.w.useSkill(school, amount * dt)

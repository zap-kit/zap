# A swing from its start to its landing. It starts at once, costs its stamina (a power attack's,
# a bash's), lands at the clip's HitFrame and ends at the clip's end (clips.zap), both shortened
# by the weapon's speed. It lands on its target when the target stands within the weapon's reach
# (a bash within fCombatBashReach, 141) inside fCombatHitConeAngle (35 degrees) of where the
# attacker faced as it swung: melee has no roll to hit. A target blocking toward the attacker takes
# off the block's share; armor takes its share (damage.zap). A power attack or a bash that is not
# blocked staggers the target when its weapon's stagger (WEAP DNAM; fists count 1) times the
# attack's (1, a bash 0.5, a power attack with fists 0.5; UESP's Skyrim:Damage) is above
# fStaggerMin, interrupting its swing for the stagger clip's length at that magnitude (the graph's
# blend, clamped to its places), and knocks it back
# min(fKnockbackForceMax 128, damage x fKnockbackDamageMult 5) units. Health at 0 kills, except an
# essential actor (or a protected one hit by anyone but the player), who bleeds out for
# fEssentialDeathTime (20 s) and comes back with fBleedoutRecover of its health, its fight given
# up; the dead fall as a ragdoll, which the physics takes later. The player's swing makes a noise
# (his weapon's sound level, Loud for all here, fists Normal) the watchers hear for
# fActorAlertSoundTimer seconds; when he swings sneaking and the target has not detected him (read
# before the noise), the hit is a sneak attack: its damage times the weapon type's sneak
# multiplier (fCombatSneak*Mult, damage.zap).

import game.sim
import game.stealth

fn timeOf(f Fight, x Fighter, strike Strike):
	moves = f.timings.unarmed if x.weapon == 0 else f.timings.armed
	match strike:
		Normal: moves.normal[x.combo % len].copy()
		Power: moves.power.copy()
		Bash: f.timings.bash.copy()

fn staminaCost(f Fight, x Fighter, strike Strike) f32:
	match strike:
		Normal: 0.0
		Power: f.w.settings.powerAttackStamina(x.weight)
		Bash: f.w.settings.gmst("fstaminabashbase")

fn strikeName(strike Strike):
	match strike:
		Normal: "attacks"
		Power: "power attacks"
		Bash: "bashes"

# starts the fighter's swing of this kind at its target
pub fn startSwing(mut f Fight, k i64, strike Strike):
	x = f.fighters[k]
	cost = f.staminaCost(x, strike)
	if cost > 0.0:
		f.w.actors[x.refId].damageValue("stamina", cost)
		f.fighters[k].damagedAt["stamina"] = f.time
	t = f.timeOf(x, strike)
	speed = f32(1.0) if strike == .Bash else x.speed
	sneak = x.player and f.w.stealth.sneaking
	if x.player:
		f.lookAtPlayer()
		f.w.makeNoise(
			i64(f.w.settings.gmst("isoundlevelnormal" if x.weapon == 0 else "isoundlevelloud"))
		)
	f.fighters[k].swing = Swing(
		strike,
		hitAt = f.time + t.hit / speed,
		endsAt = f.time + t.duration / speed,
		sneak
	)
	f.fighters[k].mode = .Swing
	f.fighters[k].lastSwingAt = f.time
	if strike == .Normal: f.fighters[k].combo += 1
	f.note("{x.name} {strike.strikeName()} with {x.weaponName}")

# whether `from`, facing `facing`, has the point inside the hit cone
fn inCone(f Fight, from Vec3, facing Vec3, point Vec3):
	d = Vec3(point.x - from.x, point.y - from.y, 0)
	if d.length() < 0.001: return true
	cone = f.w.settings.gmst("fcombathitconeangle").radians().cos()
	n = d.normalized()
	n.x * facing.x + n.y * facing.y >= cone

# the nearest living fighter within a reach and a half of fighter k, inside its hit cone: whom a
# swing started now is aimed at, none when no one stands there
pub fn foeAhead(f Fight, k i64) i64?:
	x = f.fighters[k]
	best i64? = none
	nearest = x.reach * 1.5
	for j, other in f.fighters:
		gap = other.at.distance(x.at)
		if j == k or other.isOut() or gap > nearest or not f.inCone(x.at, x.facing, other.at):
			continue
		best = j
		nearest = gap
	best

# the damage of the swing before armor and block
fn rawDamage(f Fight, x Fighter, strike Strike):
	a = f.w.actors[x.refId]
	if strike == .Bash:
		base = x.shieldRating if x.shield != 0 else x.baseDamage
		return f.w.settings.bashDamage(base, x.shield != 0, a.valueOf("block"), x.player)
	mult = f.w.settings.strikeMultiplier(strike, x.weapon == 0)
	if x.weapon == 0: return x.baseDamage * mult
	f.w.settings.weaponDamage(x.baseDamage, a.valueOf(x.skill), x.player) * mult

# The swing's damage after the perks' entry points, in the order the hit's data asks them
# (0x1407efxxx, 0x1407f17c0): the power attack's (0x1c), the weapon's (0), the attacker's attack
# damage (0x23) and the target's incoming damage (0x24).
fn perkedDamage(mut f Fight, x Fighter, target Fighter, strike Strike, damage f32):
	forms = [x.weapon, target.refId]
	d = damage
	if strike == .Power: d = f.w.entryPointValue(sim.epModPowerAttackDamage, x.refId, forms, d)
	d = f.w.entryPointValue(sim.epCalculateWeaponDamage, x.refId, forms, d)
	d = f.w.entryPointValue(sim.epModAttackDamage, x.refId, forms, d)
	f.w.entryPointValue(sim.epModIncomingDamage, target.refId, [x.refId, x.weapon], d)

# the share the target's block takes off the swing, 0 when it is not blocking toward the attacker
fn blockedShare(f Fight, x Fighter, target Fighter, strike Strike) f32:
	if target.mode != .Block or not f.inCone(target.at, target.facing, x.at): return 0.0
	shield f32? = target.shieldRating if target.shield != 0 else none
	block = f.w.actors[target.refId].valueOf("block")
	f.w.settings.blockShare(block, shield, x.baseDamage, strike)

# the magnitude fighter x's strike staggers its target by, before any block (damage.zap)
fn staggerOf(f Fight, x Fighter, target Fighter, strike Strike):
	place = match strike:
		Normal: 0
		Power: 1
		Bash: 2
	attack = x.attackStaggers[place]
	mass = f.w.actors[target.refId].valueOf("mass")
	if strike == .Bash:
		return f.w.settings.bashStagger(
			f.w.actors[x.refId].valueOf("block"),
			x.shield != 0,
			x.weapon != 0,
			x.animation in twoHanded,
			attack,
			BashTarget(
				mass,
				staggered = target.mode == .Staggered,
				running = target.mode in [.Approach, .Flee],
				blocking = target.mode == .Block
			)
		)
	f.w.settings.hitStagger(
		mass,
		target.player,
		f32(1.0) if x.weapon == 0 else x.staggerPower,
		attack
	)

# Lands fighter k's swing: a miss, a block, a hit with its damage, a stagger, a death.
pub fn landSwing(mut f Fight, k i64):
	x = f.fighters[k]
	swing = x.swing ?? return
	f.fighters[k].swing = Swing(
		swing.strike,
		hitAt = swing.hitAt,
		endsAt = swing.endsAt,
		landed = true,
		sneak = swing.sneak
	)
	j = f.indexOf(x.target) ?? return
	target = f.fighters[j]
	if target.mode == .Dead: return
	reach = f.w.settings.gmst("fcombatbashreach") if swing.strike == .Bash else x.reach
	gap = x.at.distance(target.at)
	if gap > reach or not f.inCone(x.at, x.facing, target.at):
		f.note("{x.name} misses {target.name} ({gap:.0} units away, reach {reach:.0})")
		return
	raw = f.perkedDamage(x, target, swing.strike, f.rawDamage(x, swing.strike))
	if swing.sneak and swing.strike != .Bash and not f.w.isDetectedBy(target.refId):
		raw *= f.w.entryPointValue(
			sim.epModSneakAttackMult,
			x.refId,
			[x.weapon, target.refId],
			f.w.settings.sneakMultiplier(x.animation)
		)
		f.note("{x.name} sneak attacks {target.name}")
	blocked = f.blockedShare(x, target, swing.strike)
	armor = f.w.settings.armorReduction(target.armorRating, target.armorPieces)
	levels = f.w.settings.difficultyMultipliers(f.w.difficulty)
	damage = damageTaken(raw, armor, blocked)
	if x.player: damage *= levels.byPlayer
	if target.player: damage *= levels.toPlayer
	if blocked > 0.0:
		f.w.actors[target.refId].damageValue("stamina", f.w.settings.blockStamina(raw * blocked))
		f.fighters[j].damagedAt["stamina"] = f.time
	f.note("{x.name} hits {target.name} for {damage:.1} ({raw:.1}, armor {armor * 100.0:.0}%, blocked {blocked * 100.0:.0}%)")
	stagger = f.staggerOf(x, target, swing.strike)
	if blocked > 0.0:
		stagger = f.w.settings.blockedStagger(
			stagger,
			f.w.actors[target.refId].valueOf("block"),
			target.shieldRating if target.shield != 0 else none,
			f.w.actors[target.refId].valueOf("mass")
		)
	f.hurt(j, k, damage)
	f.practiceHit(x, swing.strike, damage)
	f.practiceDefence(target, raw * (1.0 - armor), blocked)
	if f.fighters[j].mode == .Dead: return
	if stagger > f.w.settings.gmst("fstaggermin"):
		f.stagger(j, k, damage, f.timings.staggers.clampMagnitude(stagger))

# fighter j staggers back from fighter k, its swing cut short; the graph's blend plays the stagger
# of this magnitude for as long as its clip lasts
fn stagger(mut f Fight, j i64, k i64, damage f32, magnitude f32):
	if f.fighters[j].isOut(): return
	push = (
		damage * f.w.settings.gmst("fknockbackdamagemult")
	).min(f.w.settings.gmst("fknockbackforcemax"))
	away = Vec3(f.fighters[j].at.x - f.fighters[k].at.x, f.fighters[j].at.y - f.fighters[k].at.y, 0)
	if away.length() > 0.001:
		f.fighters[j].at = f.inside(f.fighters[j].at + away.normalized() * push)
	f.fighters[j].swing = none
	f.fighters[j].mode = .Staggered
	f.fighters[j].staggerMagnitude = magnitude
	f.fighters[j].until = f.time + f.timings.staggers.lengthAt(magnitude)
	f.note("{f.fighters[j].name} staggers, knocked back {push:.0} units")

# Fighter j takes the damage from fighter k: the crime, its death or bleedout, its reaction.
pub fn hurt(mut f Fight, j i64, k i64, damage f32):
	victim = f.fighters[j].refId
	attacker = f.fighters[k]
	crime = attacker.player and not (f.fighters[j].wasHostile.get(attacker.refId) ?? false)
	health = f.health(victim)
	t = f.fighters[j]
	mortal = not t.essential and not (t.protected and not attacker.player)
	if damage >= health and not mortal:
		f.w.actors[victim].damageValue("health", health)
		f.w.actors[victim].dead = false
		f.fighters[j].mode = .Bleedout
		f.fighters[j].swing = none
		f.fighters[j].until = f.time + f.w.settings.gmst("fessentialdeathtime")
		f.note("{t.name} is essential: bleeds out instead of dying")
	else:
		f.w.actors[victim].damageValue("health", damage)
	f.fighters[j].damagedAt["health"] = f.time
	f.fighters[j].struckBy = attacker.refId
	f.fighters[j].struckAt = f.time
	f.fighters[k].landedOn = victim
	f.fighters[k].landedAt = f.time
	if f.w.actors[victim].dead:
		f.fighters[j].mode = .Dead
		f.fighters[j].swing = none
		f.fighters[j].ragdoll = true
		f.note("{t.name} dies (a ragdoll for the physics)")
		if crime: f.reportCrime("murder", attacker.refId, victim)
		return
	if crime and f.assaulted.get(victim) == none:
		f.assaulted[victim] = true
		f.reportCrime("assault", attacker.refId, victim)
	f.provoke(j, k)

# the bleedout's end: back on its feet with fBleedoutRecover of its health, out of the fight
pub fn recover(mut f Fight, k i64):
	x = f.fighters[k]
	a = f.w.actors[x.refId]
	full = a.baseValueOf("health") + (a.values.get("health")?.modifier ?? 0.0)
	f.w.actors[x.refId].restoreNamed("health", full * f.w.settings.gmst("fbleedoutrecover"))
	f.fighters[k].mode = .Alert
	f.fighters[k].target = 0
	f.note("{x.name} gets up from bleeding out and yields")

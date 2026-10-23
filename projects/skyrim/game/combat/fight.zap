# A fight run headless in fixed steps: every fighter thinks (ai.zap), moves, swings and is hit
# (strike.zap) each step; health, magicka and stamina come back each second by the race's rate
# (healrate 0.7, magickarate 3, staminarate 5: a percent of the maximum) times, in combat,
# fCombatHealthRegenRateMult 0 (no health back while fighting), fCombatMagickaRegenRateMult 0.33
# and fCombatStaminaRegenRateMult 0.35, after fDamagedHealthRegenDelay, fDamagedMagickaRegenDelay
# and fDamagedStaminaRegenDelay (0.5 s) since the value last fell. Every roll comes from one seeded
# sequence, so a seed gives the same fight. What happens is kept as lines, each with its time. The
# fighters stay inside the cell's floor plan (the box around the references it places: a headless
# fight has no walls), so one that flees indoors is cornered before fFleeDistanceInterior.

import game.sim
import game.stealth
import skyrim.actor

pub type Fight:
	w sim.GameWorld
	timings Timings
	speeds Speeds
	ties Ties
	fighters Fighter[]
	rng Random
	step f32 = 1.0 / 60.0
	time f32 = 0.0
	lines str[] = []
	assaulted {i64: bool} = {}   # the victims of an assault already counted
	floor FloorPlan? = none   # where the fighters can go, none for anywhere
	lighting stealth.Lighting = stealth.Lighting()   # the light on the player, which detection reads

pub type FloorPlan:
	low Vec3
	high Vec3

# long: a table, one value a line
regenValues = ["health", "magicka", "stamina"]
regenRates = ["healrate", "magickarate", "staminarate"]
regenCombatMults = [
	"fcombathealthregenratemult", "fcombatmagickaregenratemult", "fcombatstaminaregenratemult"
]
regenDelays = ["fdamagedhealthregendelay", "fdamagedmagickaregendelay", "fdamagedstaminaregendelay"]

pub fn newFight(
	move w sim.GameWorld,
	move timings Timings,
	speeds Speeds,
	move ties Ties,
	seed i64
) Fight:
	Fight(w, timings, speeds, ties, fighters = [], rng = Random(seed))

# the fighter of this reference's place in the fight, none when it has none
pub fn indexOf(f Fight, refId i64) i64?:
	for k, x in f.fighters:
		if x.refId == refId: return k
	none

# the box around the cell's placed references
pub fn cellBox(w sim.GameWorld) FloorPlan?:
	placed = w.forms.values().filter(.cell == w.cell and .cell != 0)
	if placed.isEmpty: return none
	FloorPlan(
		low = Vec3(placed.map(.x).min() ?? 0.0, placed.map(.y).min() ?? 0.0, 0),
		high = Vec3(placed.map(.x).max() ?? 0.0, placed.map(.y).max() ?? 0.0, 0)
	)

# the point kept inside the floor
pub fn inside(f Fight, p Vec3) Vec3:
	b = f.floor ?? return p
	Vec3(p.x.clamp(b.low.x, b.high.x), p.y.clamp(b.low.y, b.high.y), p.z)

pub fn note(mut f Fight, line str):
	f.lines.push("{f.time:.2} s  {line}")

pub fn health(f Fight, refId i64) f32:
	(f.w.actors.get(refId) ?? return 0.0).valueOf("health")

pub fn distance(a Vec3, b Vec3) f32:
	Vec3(b.x - a.x, b.y - a.y, 0).length()

# the fighter placed for detection: where it stands and the way it faces, sneaking when it is the
# player and he sneaks
pub fn placedOf(f Fight, k i64) stealth.Placed:
	x = f.fighters[k]
	stealth.Placed(
		actor = x.refId,
		feet = x.at,
		heading = x.facing.x.atan2(x.facing.y),
		sneaking = x.player and f.w.stealth.sneaking,
		fighting = x.isFighting(),
		foe = x.target,
		friendly = f.w.isAlly(f.ties, x.refId, f.w.player) or f.w.isFriend(f.ties, x.refId, f.w.player),
		hostile = f.w.attacksOnSight(f.ties, x, f.w.player)
	)

# every living fighter reads the player again, from where they stand now
pub fn lookAtPlayer(mut f Fight):
	k = f.indexOf(f.w.player) ?? return
	others = []
	for j in 0..f.fighters.len:
		if j != k and not f.fighters[j].isOut(): others.push(f.placedOf(j))
	f.w.lookAgain(f.lighting, f.placedOf(k), others)

# The living fighters other than `except` within fSneakMaxDistance of the place who see a crime by
# `by`: when the player commits it, those that have detected him (read again now,
# game/stealth); an actor's crime is seen by whoever is near, as the game does not model what
# an actor sees of another here.
pub fn witnessesOf(mut f Fight, place Vec3, by i64, except i64[]) i64[]:
	range = f.w.settings.gmst("fsneakmaxdistance")
	near = f.fighters.filter(
		.mode != .Dead and .refId not in except and distance(.at, place) <= range
	).map(.refId)
	if by != f.w.player: return near
	f.lookAtPlayer()
	near.filter(f.w.isDetectedBy(it))

# Reports a crime of the attacker against the victim ("assault" or "murder") to the victim's crime
# faction, when someone sees it; the crime, none when it went unseen or no faction takes it.
pub fn reportCrime(mut f Fight, kind str, attacker i64, victim i64) sim.Crime?:
	v = (try f.w.actors.get(victim)).copy()
	values = (try f.w.crimeValues.get(v.crimeFaction)).copy()
	place = f.fighters[try f.indexOf(victim)].at
	seen = f.witnessesOf(place, attacker, [attacker] if kind == "assault" else [attacker, victim])
	if seen.isEmpty:
		f.note("the {kind} goes unseen")
		return none
	bounty = values.murder if kind == "murder" else values.assault
	crime = sim.Crime(
		kind = kind.copy(),
		actor = attacker,
		refId = victim,
		item = 0,
		count = 0,
		value = 0,
		owner = v.npc,
		faction = v.crimeFaction,
		bounty
	)
	f.w.crimes.push(crime.copy())
	f.note("{kind} seen by {seen.len}: bounty {bounty} (now {f.w.bountyOf(v.crimeFaction)}) to {v.crimeFaction:08X}")
	crime

fn regenerate(mut f Fight, k i64):
	x = f.fighters[k]
	if x.isOut(): return
	a = (f.w.actors.get(x.refId) ?? return).copy()
	for i, name in regenValues:
		since = f.time - (x.damagedAt.get(name) ?? -1000.0)
		if since < f.w.settings.gmst(regenDelays[i]): continue
		v = a.values.get(name) ?? continue
		combat = f.w.settings.gmst(regenCombatMults[i]) if x.isFighting() else 1.0
		amount = (v.base + v.modifier) * a.valueOf(regenRates[i]) / 100.0 * combat * f.step
		if amount > 0.0: f.w.actors[x.refId].restoreNamed(name, amount)

# whether anyone still fights
pub fn isOver(f Fight) bool:
	not f.fighters.any(.isFighting())

# One fixed step: every fighter thinks and regenerates.
pub fn stepOnce(mut f Fight):
	for k in 0..f.fighters.len:
		f.think(k)
		f.stepCast(k)
		f.regenerate(k)
	f.w.tickEffects(f.step)
	f.w.stealth.clock += f.step
	f.time += f.step

# Runs the fight for at most `seconds`, or until no one fights; how long it ran.
pub fn run(mut f Fight, seconds f32) f32:
	while f.time < seconds:
		f.stepOnce()
		if f.isOver() and f.time > f.step: break
	f.time

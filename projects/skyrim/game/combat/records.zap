# What combat reads of the plugin beyond the actors: the combat styles (CSTY: CSGD the general
# multipliers, CSME the melee ones, CSCR the close range ones, CSLR the long range one, DATA the
# flags), an NPC without one fighting with DefaultCombatstyle; the relationships (RELA DATA: the
# parent and child actor bases, the rank 0 lover, 1 ally, 2 confidant, 3 friend, 4 acquaintance, 5
# rival, 6 foe, 7 enemy, 8 archnemesis); the factions' reactions to other factions (FACT XNAM: the
# faction, a modifier, the group combat reaction 0 neutral, 1 enemy, 2 ally, 3 friend); and the
# movement types' speeds (MOVT SPED: left, right, forward and back, each walk then run). Layouts
# after xEdit's definitions for the Special Edition.

import skyrim.esm

pub defaultStyle = "DefaultCombatstyle"
# the movement types of an actor with a one-handed weapon or fists drawn, and of one sprinting
combatMovement = "NPC_1HM_MT"
sprintMovement = "NPC_Sprinting_MT"

pub type Style:
	editorId str
	offensive f32   # the will to attack
	defensive f32   # the will to block and keep its distance
	groupOffensive f32
	meleeScore f32   # how much it likes each kind of weapon
	unarmedScore f32
	avoidThreat f32
	attackStaggered f32   # how much likelier it attacks a staggered target
	powerAttackStaggered f32
	powerAttackBlocking f32   # how much likelier it power attacks a blocking target
	bash f32
	bashRecoil f32
	bashAttack f32
	bashPowerAttack f32
	specialAttack f32
	circle f32   # how much it circles its target at close range
	fallback f32   # how much it steps back
	flankDistance f32
	stalkTime f32
	strafe f32
	flags i64   # 1 dueling, 2 flanking, 4 dual wielding

pub type Relationship:
	parent i64
	child i64
	rank i64

# the ranks of a relationship that make two actors allies, and friends
pub allyRank = 1
pub friendRank = 3
pub enemyRank = 7

# the group combat reactions of XNAM
pub reactionEnemy = 1
pub reactionAlly = 2
pub reactionFriend = 3

pub type Speeds:
	walk f32
	run f32
	backRun f32
	sprint f32

fn floatsOf(r esm.Record, tag str, count i64):
	at = esm.dataOf(r.fields, tag)
	size = r.fields.find(.tag == tag)?.size ?? 0
	(0..count).map(r.body.f32le((at ?? 0) + it * 4) if at != none and it * 4 + 4 <= size else 0.0)

# the combat style with this form id, DefaultCombatstyle for 0 or one the plugin lacks
pub fn combatStyleOf(mut plugin esm.Esm, formId i64) Style:
	id = formId
	if plugin.recordOf(id) == none: id = plugin.formByEditorId("CSTY", defaultStyle) ?? 0
	r = plugin.recordOf(id) ??
		esm.Record(kind = "CSTY", formId = 0, flags = 0, body = [], fields = [])
	g = r.floatsOf("CSGD", 10)
	m = r.floatsOf("CSME", 8)
	c = r.floatsOf("CSCR", 4)
	Style(
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		offensive = g[0],
		defensive = g[1],
		groupOffensive = g[2],
		meleeScore = g[3],
		unarmedScore = g[7],
		avoidThreat = g[9],
		attackStaggered = m[0],
		powerAttackStaggered = m[1],
		powerAttackBlocking = m[2],
		bash = m[3],
		bashRecoil = m[4],
		bashAttack = m[5],
		bashPowerAttack = m[6],
		specialAttack = m[7],
		circle = c[0],
		fallback = c[1],
		flankDistance = c[2],
		stalkTime = c[3],
		strafe = r.floatsOf("CSLR", 1)[0],
		flags = r.body.u32le(esm.dataOf(r.fields, "DATA") ?? 0) if esm.dataOf(r.fields, "DATA") !=
			none
		else 0
	)

# what a race gives its fighters: the fists' reach (RACE DATA at 100) and its attacks' stagger
# (ATKD at 24, by the ATKE event that starts the attack: 0 for the Nord's plain attackStart, 1 for
# attackPowerStartForward, 0.5 for its fists' and for bashStart)
pub type RaceCombat:
	reach f32
	staggers {str: f32}

# the race's stagger of a plain, a power and a bash strike, by the events that start them
pub fn strikeStaggers(r RaceCombat, fists bool) f32[]:
	[attackEvent, powerEventOf(fists), bashEvent].map(r.staggers.get(it) ?? 0.0)

pub fn raceCombatOf(mut plugin esm.Esm, race i64) RaceCombat:
	r = plugin.recordOf(race) ?? return RaceCombat(reach = 0.0, staggers = {})
	staggers {str: f32} = {}
	stagger = f32(0.0)
	for f in r.fields:
		if f.tag == "ATKD" and f.size >= 28: stagger = r.body.f32le(f.at + 24)
		if f.tag == "ATKE": staggers[r.body.cStringAt(f.at)] = stagger
	at = esm.dataOf(r.fields, "DATA") ?? return RaceCombat(reach = 0.0, staggers)
	RaceCombat(reach = r.body.f32le(at + 100), staggers)

# every relationship of the plugin
pub fn relationshipsOf(mut plugin esm.Esm) Relationship[]:
	out = []
	for id in plugin.formsOfKind("RELA"):
		r = plugin.recordOf(id) ?? continue
		at = esm.dataOf(r.fields, "DATA") ?? continue
		out.push(
			Relationship(
				parent = r.body.u32le(at),
				child = r.body.u32le(at + 4),
				rank = r.body.u16le(at + 8)
			)
		)
	out

# a faction's reactions to other factions, by faction
pub fn reactionsOf(mut plugin esm.Esm, faction i64) {i64: i64}:
	out {i64: i64} = {}
	r = plugin.recordOf(faction) ?? return out
	for f in r.fields.filter(.tag == "XNAM" and .size >= 12):
		out[i64(r.body.u32le(f.at))] = r.body.u32le(f.at + 8)
	out

# the speeds of an actor fighting on foot (units a second)
pub fn combatSpeedsOf(mut plugin esm.Esm) Speeds ? str:
	s = try plugin.speedsOf(combatMovement)
	sprint = try plugin.speedsOf(sprintMovement)
	Speeds(walk = s[4], run = s[5], backRun = s[7], sprint = sprint[5])

fn speedsOf(mut plugin esm.Esm, editorId str) f32[] ? str:
	r = plugin.recordOf(plugin.formByEditorId("MOVT", editorId) ?? 0) ??
		return "no movement type {editorId}"
	r.floatsOf("SPED", 8)

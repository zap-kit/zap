# An actor's values as the game keeps them: a base, a modifier (what ModActorValue and level-ups
# add) and the damage taken (DamageActorValue, RestoreActorValue); the current value is base plus
# modifier less damage. The base values of a new game: health, magicka and stamina are the race's
# starting values (RACE DATA at 36, 40, 44) plus the actor's offsets (ACBS at 20, 4, 6), which give
# the player 50 + 50 = 100 each at level 1; an actor whose stats are auto-calculated (ACBS flag
# 0x10) adds per level above the first fNPCHealthLevelBonus health (5) and iAVDhmsLevelUp points
# (10) shared by its class's weights (CLAS DATA at 32, 33, 34: the heaviest takes its share
# rounded down, ties going health, magicka, stamina, the next its share of the rest, the last what
# is left; UESP's Skyrim:Classes), which gives Orgnar (level 4, weights 1 1 1) 75, 60, 60 as his
# DNAM stores them. The carry weight is the race's base (RACE DATA at 48, 300); the game adds
# fLevelUpCarryWeightMod at each level-up into stamina, and the GMSTs fAVDCarryWeightsBase and
# fAVDCarryWeightMult, which Oblivion's formula of carry weight from an attribute used, are not set
# by Skyrim.esm and play no part. The regeneration rates (healrate, magickarate, staminarate: a
# percent of the maximum a second) and the unarmed damage are the race's (DATA at 84, 88, 92, 96).
# The skills: an NPC's are the stats record's DNAM (one byte each, in actor value order, as the
# Creation Kit computed them); the player's are 15 and its race's boosts (RACE DATA's seven pairs
# of skill and bonus). The AI's character (AIDT) is actor values 0 to 5. Layouts after UESP's NPC_,
# RACE and CLAS pages.

import skyrim.esm
import skyrim.actor

# the actor values by their index (a condition's parameter, CTDA), lower case as the values are
# kept, after the Creation Kit's actor value list: the first 96, then those valueNamesAfter adds
pub actorValueNames = valueNamesAfter(firstValueNames)

# the first 96 actor values
firstValueNames = [
	"aggression", "confidence", "energy", "morality", "mood", "assistance", "onehanded",
	"twohanded", "marksman", "block", "smithing", "heavyarmor", "lightarmor", "pickpocket",
	"lockpicking", "sneak", "alchemy", "speechcraft", "alteration", "conjuration", "destruction",
	"illusion", "restoration", "enchanting", "health", "magicka", "stamina", "healrate",
	"magickarate", "staminarate", "speedmult", "inventoryweight", "carryweight", "critchance",
	"meleedamage", "unarmeddamage", "mass", "voicepoints", "voicerate", "damageresist",
	"poisonresist", "fireresist", "electricresist", "frostresist", "magicresist", "diseaseresist",
	"perceptioncondition", "endurancecondition", "leftattackcondition", "rightattackcondition",
	"leftmobilitycondition", "rightmobilitycondition", "braincondition", "paralysis",
	"invisibility", "nighteye", "detectliferange", "waterbreathing", "waterwalking",
	"ignorecrippledlimbs", "fame", "infamy", "jumpingbonus", "wardpower", "rightitemcharge",
	"armorperks", "shieldperks", "warddeflection", "variable01", "variable02", "variable03",
	"variable04", "variable05", "variable06", "variable07", "variable08", "variable09",
	"variable10", "bowspeedbonus", "favoractive", "favorsperday", "favorsperdaytimer",
	"leftitemcharge", "absorbchance", "blindness", "weaponspeedmult", "shoutrecoverymult",
	"bowstaggerbonus", "telekinesis", "favorpointsbonus", "lastbribedintimidated",
	"lastflattered", "movementnoisemult", "bypassvendorstolencheck", "bypassvendorkeywordcheck",
	"waitingforplayer"
]

# the skills the modifier values at 96 and on are named for, as the game's list spells them
modifiedSkills = [
	"onehanded", "twohanded", "marksman", "block", "smithing", "heavyarmor", "lightarmor",
	"pickpocket", "lockpicking", "sneaking", "alchemy", "speechcraft", "alteration", "conjuration",
	"destruction", "illusion", "restoration", "enchanting"
]

# the actor values from 96 (CommonLibSSE-NG's ActorValue): a modifier, a skill advance and a power
# modifier for each skill, and the rate multipliers and the rest (a Fortify potion changes these)
fn valueNamesAfter(first str[]):
	out = first.copy()
	for suffix in ["modifier", "skilladvance"]:
		for skill in modifiedSkills:
			out.push("{skill}{suffix}")
	out.extend(["leftweaponspeedmultiply", "dragonsouls", "combathealthregenmultiply"])
	for skill in modifiedSkills:
		out.push("{skill}powermodifier")
	out.extend([
		"dragonrend", "attackdamagemult", "healratemult", "magickaratemult", "staminaratemult",
		"werewolfperks", "vampireperks", "grabactoroffset", "grabbed", "deprecated05",
		"reflectdamage"
	])
	out

# the actor value of the first skill, one-handed
pub firstSkill = 6

# the skills in actor value order (6 to 23), as DNAM lists them
pub skillNames = actorValueNames[firstSkill..firstSkill + 18].copy()

# ACBS's flag of a level that is a multiple of the player's
flagLevelMult = 0x80
# RACE DATA's flags (at 32): the race can be pickpocketed (TESRace::kAllowPickpocket)
flagAllowPickpocket = 0x80_0000

pub attributeNames = ["health", "magicka", "stamina"]
# the values a race's DATA gives every actor of it, and where
raceValueNames = ["carryweight", "mass", "healrate", "magickarate", "staminarate", "unarmeddamage"]
raceValueOffsets = [48, 52, 84, 88, 92, 96]

# a skill's value before the race's boost, for the player and the level 1 of an NPC
pub skillStart f32 = 15.0

pub type ActorValue:
	base f32
	modifier f32 = 0.0
	damage f32 = 0.0

# a perk an actor holds and its rank (1 for the first)
pub type PerkRank:
	perk i64
	rank i64

pub type ActorState:
	npc i64   # the actor base (NPC_)
	race i64
	level i64
	values {str: ActorValue}   # by lower-case name
	dead bool = false
	factions actor.Membership[] = []
	crimeFaction i64 = 0
	flags i64 = 0   # ACBS's: essential, protected...
	class i64 = 0
	combatStyle i64 = 0   # ZNAM, 0 for the game's default
	vendor Vendor? = none   # the merchant's stock and rules, none for an actor who sells nothing
	magic Magic = Magic()   # the spells it knows and holds
	effects TimedEffect[] = []   # the magic effects it lives under that tick and expire (consume.zap)
	pickpocketable bool = true   # its race allows pickpocketing
	perks PerkRank[] = []   # the perks it was given, in the order it got them (perks.zap)

fn raceAllowsPickpocket(race esm.Record):
	at = esm.dataOf(race.fields, "DATA") ?? return true
	(race.body.u32le(at + 32) & flagAllowPickpocket) != 0

fn raceFloat(race esm.Record, offset i64) f32:
	at = esm.dataOf(race.fields, "DATA") ?? return 0.0
	race.body.f32le(at + offset)

# ACBS's level: its own, or the player's level times its multiple (in thousandths) within the
# calculated bounds
fn levelOf(acbs u8[], at i64, playerLevel i64):
	level = i64(acbs.u16le(at + 8))
	if (acbs.u32le(at) & flagLevelMult) == 0: return level
	scaled = (level * playerLevel / 1000).max(i64(acbs.u16le(at + 10)))
	high = i64(acbs.u16le(at + 12))
	scaled.min(high) if high > 0 else scaled

# the shares of `points` a class's health, magicka and stamina weights give
pub fn levelShares(points i64, weights i64[]) i64[]:
	order = [0, 1, 2].sortedBy(-weights[it])
	out = [0, 0, 0]
	left = points
	total = weights.sum()
	for k, at in order:
		if total <= 0: break
		share = left if k == 2 else left * weights[at] / total
		out[at] = share
		left -= share
		total -= weights[at]
	out

# what auto-calculated stats add to health, magicka and stamina above level 1
fn levelBonus(mut plugin esm.Esm, settings {str: f64}, class i64, level i64):
	if level <= 1: return [0, 0, 0]
	r = plugin.recordOf(class) ?? return [0, 0, 0]
	at = esm.dataOf(r.fields, "DATA") ?? return [0, 0, 0]
	points = i64(settings.get("iavdhmslevelup") ?? 10.0) * (level - 1)
	shares = levelShares(points, (0..3).map(i64(r.body[at + 32 + it])))
	shares[0] += i64(settings.get("fnpchealthlevelbonus") ?? 5.0) * (level - 1)
	shares

# the skills: the player's 15 and its race's boosts, an NPC's its DNAM
fn skillsOf(npcId i64, stats esm.Record, race esm.Record):
	if npcId == playerBase:
		at = esm.dataOf(race.fields, "DATA") ?? 0
		out = skillNames.map(_: skillStart)
		for k in 0..7:
			skill = i64(race.body[at + k * 2]) - firstSkill
			if skill >= 0 and skill < out.len: out[skill] += race.body[at + k * 2 + 1]
		return out
	at = esm.dataOf(stats.fields, "DNAM") ?? return []
	(0..skillNames.len).map(f32(stats.body[at + it]))

fn aiValues(mut values {str: ActorValue}, ai actor.AiData):
	levels = [ai.aggression, ai.confidence, ai.energy, ai.morality, ai.mood, ai.assistance]
	for k, v in levels:
		values[actorValueNames[k].copy()] = ActorValue(base = f32(v))

# The values of the actor base `npc` in a new game (its templates followed), the game settings
# giving the level terms, or why the plugin cannot say.
pub fn actorStateOf(mut plugin esm.Esm, settings {str: f64}, npcId i64) ActorState ? str:
	npc = try plugin.npcOf(npcId)
	r = try plugin.needRecord(npcId)
	stats = try plugin.sourceFor(r, actor.useStats)
	race = try plugin.needRecord(npc.race)
	acbs = esm.dataOf(stats.fields, "ACBS") ?? return "actor {npcId:08X} has no ACBS"
	flags = stats.body.u32le(acbs)
	level = levelOf(stats.body, acbs, actor.newGameLevel)
	bonus = [0, 0, 0]
	if flags & actor.flagAutoCalcStats != 0:
		bonus = plugin.levelBonus(settings, npc.class, level)
	values {str: ActorValue} = {}
	for k, at in [(36, 20), (40, 4), (44, 6)]:
		raceAt, own = at
		base = race.raceFloat(raceAt) + stats.body.i16le(acbs + own) + f32(bonus[k])
		values[attributeNames[k].copy()] = ActorValue(base)
	for k, name in raceValueNames:
		values[name.copy()] = ActorValue(base = race.raceFloat(raceValueOffsets[k]))
	values["speedmult"] = ActorValue(base = stats.body.u16le(acbs + 14))
	values["movementnoisemult"] = ActorValue(base = 1.0)   # the base every actor has
	for k, value in skillsOf(npcId, stats, race):
		values[skillNames[k].copy()] = ActorValue(base = value)
	values.aiValues(npc.ai)
	ActorState(
		npc = npcId,
		race = npc.race,
		level,
		values,
		factions = npc.factions.copy(),
		crimeFaction = npc.crimeFaction,
		flags = r.body.u32le(esm.dataOf(r.fields, "ACBS") ?? acbs),
		class = npc.class,
		combatStyle = npc.combatStyle,
		pickpocketable = race.raceAllowsPickpocket()
	)

# the actor value's current value (base plus modifier less damage), 0 for one never set
pub fn valueOf(a ActorState, name str) f32:
	v = a.values.get(name.lower()) ?? return 0.0
	v.base + v.modifier - v.damage

pub fn baseValueOf(a ActorState, name str) f32:
	(a.values.get(name.lower()) ?? return 0.0).base

fn ensureValue(mut a ActorState, key str):
	if a.values.get(key) == none: a.values[key.copy()] = ActorValue(base = 0.0)

pub fn setBaseValue(mut a ActorState, name str, value f32):
	key = name.lower()
	a.ensureValue(key)
	a.values[key].base = value

pub fn modValue(mut a ActorState, name str, delta f32):
	key = name.lower()
	a.ensureValue(key)
	a.values[key].modifier += delta

# takes amount off the current value, down to 0; an actor whose health reaches 0 dies
pub fn damageValue(mut a ActorState, name str, amount f32):
	key = name.lower()
	a.ensureValue(key)
	v = a.values[key]
	a.values[key].damage = (v.damage + amount).min(v.base + v.modifier).max(0.0)
	if key == "health" and a.valueOf(key) <= 0.0: a.dead = true

# gives back up to amount of the damage taken
pub fn restoreValue(mut a ActorValue, amount f32):
	a.damage = (a.damage - amount).max(0.0)

pub fn restoreNamed(mut a ActorState, name str, amount f32):
	key = name.lower()
	a.ensureValue(key)
	a.values[key].restoreValue(amount)

# the current value as a share of base plus modifier (1 for a value with none)
pub fn percentOf(a ActorState, name str) f32:
	v = a.values.get(name.lower()) ?? return 1.0
	full = v.base + v.modifier
	(full - v.damage) / full if full > 0.0 else 1.0

# Kill: the actor is dead, its health gone
pub fn kill(mut a ActorState):
	a.damageValue("health", a.valueOf("health"))
	a.dead = true

pub fn isInFaction(a ActorState, faction i64) bool:
	a.factions.any(.faction == faction and .rank >= 0)

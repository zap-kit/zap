# An actor's base record (NPC_) as the game builds the actor from it: each group of its fields
# taken from its template (TPLT) when ACBS's template flags say so, a template that is a leveled
# list (LVLN) picked at the player's level, and so on down the chain. Field layouts after UESP's
# Skyrim Mod File Format pages (NPC_, ACBS) and xEdit's record definitions.

import skyrim.esm

# the player's level at a new game, at which leveled templates and items are picked
pub newGameLevel = 1

# ACBS's flags
pub flagFemale = 0x1
pub flagEssential = 0x2
pub flagAutoCalcStats = 0x10
pub flagUnique = 0x20
pub flagProtected = 0x800

# ACBS's template flags: which groups of fields the template gives
pub useTraits = 0x1   # race, sex, height, weight, skin, voice, head parts, face
pub useStats = 0x2   # level, class, skills
pub useFactions = 0x4
pub useAiData = 0x10   # AIDT and the combat style
pub useAiPackages = 0x20
pub useBaseData = 0x80   # the name
pub useInventory = 0x100   # items and outfits
pub useDefaultPackages = 0x400

# a face tint layer the actor sets (TINI, TINC, TINV, TIAS): the race's layer of this index, its
# color and how strongly it shows (0 to 1)
pub type NpcTint:
	index i64
	color esm.Color
	alpha i64
	value f32
	preset i64

# a faction the actor is in, at this rank (a signed byte: -1 keeps it out of the faction)
pub type Membership:
	faction i64
	rank i64

# AIDT: the AI's character, kept as the actor values 0 to 5
pub type AiData:
	aggression i64   # 0 unaggressive, 1 aggressive, 2 very aggressive, 3 frenzied
	confidence i64   # 0 cowardly, 1 cautious, 2 average, 3 brave, 4 foolhardy
	energy i64
	morality i64   # 0 any crime, 1 violence against enemies, 2 property crime only, 3 no crime
	mood i64
	assistance i64   # 0 helps nobody, 1 helps allies, 2 helps friends and allies

pub type Npc:
	formId i64
	editorId str
	templates i64[]   # the records the traits come through, the record itself first
	nameId i64   # FULL: the id of the name in the plugin's strings
	flags i64   # ACBS's
	female bool
	race i64
	skin i64   # WNAM, 0 for the race's
	height f32
	weight f32   # 0 thin to 100 heavy
	voice i64
	class i64
	headParts i64[]   # PNAM, in place of the race's defaults of the same kinds
	hairColor i64   # HCLF: a CLFM, 0 for none
	faceTexture i64   # FTST: a TXST, 0 for the race's
	skinTone Vec3?   # QNAM: the skin's light, red green blue 0 to 1
	faceMorphs f32[]   # NAM9: the chargen sliders, -1 to 1
	faceParts i64[]   # NAMA: nose, unused, eyes, mouth presets, -1 for none
	tints NpcTint[]
	faceNpc i64   # the record the traits come from, whose FaceGen files the game loads
	outfit i64   # DOFT, 0 for none
	sleepOutfit i64   # SOFT
	packages i64[]   # PKID, in the order the game tries them
	defaultPackages i64   # DPLT: a form list of packages tried after them
	factions Membership[]   # SNAM
	crimeFaction i64
	ai AiData
	combatStyle i64   # ZNAM, 0 for the game's default

fn templateFlags(r esm.Record):
	at = esm.dataOf(r.fields, "ACBS") ?? return 0
	i64(r.body.u16le(at + 18))

# The records followed for the fields of `flag`, r first: its template while its template flags
# take them from it, a leveled list's pick at a new game's level standing for the list. The last
# gives the fields.
fn chainFor(mut plugin esm.Esm, r esm.Record, flag i64) esm.Record[] ? str:
	chain = [r.copy()]
	loop 16:
		at = chain[len - 1].copy()
		if at.templateFlags() & flag == 0: return chain
		template = at.formOf("TPLT") ?? return chain
		picks = plugin.pickLeveled(template, newGameLevel)
		if picks.isEmpty: return "the leveled list {template:08X} gives no actor"
		next = try plugin.needRecord(picks[0])
		if next.kind != "NPC_": return "template {picks[0]:08X} is a {next.kind}, not an actor"
		chain.push(next)
	"the templates of {r.formId:08X} go round"

# the record that gives the fields of `flag` (useStats, useInventory...): the last of chainFor
pub fn sourceFor(mut plugin esm.Esm, r esm.Record, flag i64) esm.Record ? str:
	chain = try plugin.chainFor(r, flag)
	chain[len - 1].copy()

fn floatOf(r esm.Record, tag str, otherwise f32):
	at = esm.dataOf(r.fields, tag) ?? return otherwise
	r.body.f32le(at)

fn skinToneOf(r esm.Record) Vec3?:
	at = try esm.dataOf(r.fields, "QNAM")
	Vec3(r.body.f32le(at), r.body.f32le(at + 4), r.body.f32le(at + 8))

fn fieldFloats(r esm.Record, tag str):
	for f in r.fields:
		if f.tag == tag: return (0..f.size / 4).map(r.body.f32le(f.at + it * 4))
	[]

fn facePartsOf(r esm.Record):
	for f in r.fields:
		if f.tag == "NAMA": return (0..f.size / 4).map(i64(r.body.i32le(f.at + it * 4)))
	[]

# the tint layers in field order: each TINI starts one, the fields after it fill it
fn tintsOf(r esm.Record):
	out = []
	for f in r.fields:
		if f.tag == "TINI":
			out.push(
				NpcTint(
					index = r.body.u16le(f.at),
					color = esm.Color(r = 0, g = 0, b = 0),
					alpha = 0,
					value = 0.0,
					preset = -1
				)
			)
		if out.isEmpty: continue
		last = out.len - 1
		if f.tag == "TINC":
			out[last].color = esm.colorAt(r.body, f.at)
			out[last].alpha = r.body[f.at + 3]
		if f.tag == "TINV": out[last].value = f32(r.body.i32le(f.at)) / 100.0
		if f.tag == "TIAS": out[last].preset = r.body.i16le(f.at)
	out

fn factionsOf(r esm.Record):
	r.fields.filter(.tag == "SNAM" and .size >= 5).map(
		Membership(faction = r.body.u32le(.at), rank = i8.wrap(r.body[.at + 4]))
	)

fn aiDataOf(r esm.Record):
	at = esm.dataOf(r.fields, "AIDT")
	b = (0..6).map(r.body[(at ?? 0) + it] if at != none else 0)
	AiData(
		aggression = b[0],
		confidence = b[1],
		energy = b[2],
		morality = b[3],
		mood = b[4],
		assistance = b[5]
	)

# The actor record with this form id with each group of fields from where its templates send it,
# or why the plugin cannot say.
pub fn npcOf(mut plugin esm.Esm, formId i64) Npc ? str:
	r = try plugin.needRecord(formId)
	if r.kind != "NPC_": return "{formId:08X} is a {r.kind}, not an actor"
	chain = try plugin.chainFor(r, useTraits)
	traits = chain[len - 1].copy()
	stats = try plugin.sourceFor(r, useStats)
	base = try plugin.sourceFor(r, useBaseData)
	ai = try plugin.sourceFor(r, useAiPackages)
	defaults = try plugin.sourceFor(r, useDefaultPackages)
	inventory = try plugin.sourceFor(r, useInventory)
	factions = try plugin.sourceFor(r, useFactions)
	aiData = try plugin.sourceFor(r, useAiData)
	acbs = esm.dataOf(r.fields, "ACBS") ?? return "actor {formId:08X} has no ACBS"
	traitFlags = traits.formOf("ACBS") ?? 0
	Npc(
		formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		templates = chain.map(.formId),
		nameId = base.formOf("FULL") ?? 0,
		flags = r.body.u32le(acbs),
		female = (traitFlags & flagFemale) != 0,
		race = traits.formOf("RNAM") ?? 0,
		skin = traits.formOf("WNAM") ?? 0,
		height = traits.floatOf("NAM6", 1.0),
		weight = traits.floatOf("NAM7", 50.0),
		voice = traits.formOf("VTCK") ?? 0,
		class = stats.formOf("CNAM") ?? 0,
		headParts = esm.formsOf(traits.body, traits.fields, "PNAM"),
		hairColor = traits.formOf("HCLF") ?? 0,
		faceTexture = traits.formOf("FTST") ?? 0,
		skinTone = traits.skinToneOf(),
		faceMorphs = traits.fieldFloats("NAM9"),
		faceParts = traits.facePartsOf(),
		tints = traits.tintsOf(),
		faceNpc = traits.formId,
		outfit = inventory.formOf("DOFT") ?? 0,
		sleepOutfit = inventory.formOf("SOFT") ?? 0,
		packages = esm.formsOf(ai.body, ai.fields, "PKID"),
		defaultPackages = defaults.formOf("DPLT") ?? 0,
		factions = factions.factionsOf(),
		crimeFaction = factions.formOf("CRIF") ?? 0,
		ai = aiData.aiDataOf(),
		combatStyle = aiData.formOf("ZNAM") ?? 0
	)

# the armors an outfit (OTFT) puts on at a new game, its leveled items picked; INAM is one list
pub fn outfitArmors(mut plugin esm.Esm, outfit i64) i64[]:
	if outfit == 0: return []
	r = plugin.recordOf(outfit) ?? return []
	out = []
	for f in r.fields.filter(.tag == "INAM"):
		for k in 0..f.size / 4:
			out.extend(plugin.pickLeveled(r.body.u32le(f.at + k * 4), newGameLevel))
	out

# the actor a placed actor (ACHR) is of: its NAME
pub fn achrBase(achr esm.Record) i64:
	achr.formOf("NAME") ?? 0

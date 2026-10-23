# An actor's face. The game loads an NPC's head from its FaceGen files, made by the Creation Kit
# for every NPC of the base game: the head parts baked with the actor's morphs into one skinned
# model (facegeom/<plugin>/<form id>.nif) and the face's tint layers baked into one texture
# (facetint/<plugin>/<form id>.dds). Without them the head is built as character creation builds
# it: each head part's model moved by its TRI files' morphs (HDPT's NAM0 and NAM1): the race's
# morph (type 0), the weight's SkinnyMorph (type 1, the expressions' file, at 1 - weight) and the
# sliders (NAM9) and presets (NAMA) of the chargen file (type 2). How the sliders map to the
# morphs was found by fitting the morphs to the baked heads of Orgnar, Embry and Sven (a least
# squares fit leaves under 0.002 units); the tests check it against Orgnar's baked head.

import skyrim
import skyrim.esm
import skyrim.nif

# the archive key of the actor's baked head in the plugin ("Skyrim.esm")
pub fn faceGeomKey(plugin str, formId i64) str:
	"meshes/actors/character/facegendata/facegeom/{plugin.lower()}/{formId & 0xFF_FFFF:08x}.nif"

# the archive key of the actor's baked face tint
pub fn faceTintKey(plugin str, formId i64) str:
	"textures/actors/character/facegendata/facetint/{plugin.lower()}/{formId & 0xFF_FFFF:08x}.dds"

# NAM9's sliders in order: the morph a negative value weighs, the one a positive value weighs (the
# 19th slider is unused)
sliderMorphs = [
	("NoseShort", "NoseLong"), ("NoseDown", "NoseUp"), ("JawUp", "JawDown"),
	("JawNarrow", "JawWide"), ("JawBack", "JawForward"), ("CheeksDown", "CheeksUp"),
	("CheeksIn", "CheeksOut"), ("EyesMoveDown", "EyesMoveUp"), ("EyesMoveIn", "EyesMoveOut"),
	("BrowDown", "BrowUp"), ("BrowIn", "BrowOut"), ("BrowBack", "BrowForward"),
	("LipMoveDown", "LipMoveUp"), ("LipMoveIn", "LipMoveOut"), ("ChinThin", "ChinWide"),
	("ChinMoveUp", "ChinMoveDown"), ("Overbite", "Underbite"), ("EyesBack", "EyesForward")
]

# NAMA's presets: the morph each of its four numbers names, by its prefix ("" unused)
presetMorphs = ["NoseType", "", "EyesType", "LipType"]

# a morph of the head and how strongly it applies
pub type MorphWeight:
	name str
	weight f32

# the morphs the actor's head parts take: its race's, its weight's, its sliders' and its presets'
pub fn faceMorphWeights(npc Npc, raceEditorId str) MorphWeight[]:
	out = [
		MorphWeight(name = raceEditorId.copy(), weight = 1.0),
		MorphWeight(name = "SkinnyMorph", weight = 1.0 - npc.weight / 100.0)
	]
	for k, (negative, positive) in sliderMorphs:
		if k >= npc.faceMorphs.len: break
		v = npc.faceMorphs[k]
		if v == 0.0 or v.abs() > 1.0e3: continue
		out.push(MorphWeight(name = (negative if v < 0.0 else positive).copy(), weight = v.abs()))
	for k, prefix in presetMorphs:
		if prefix == "" or k >= npc.faceParts.len or npc.faceParts[k] < 0: continue
		out.push(MorphWeight(name = "{prefix}{npc.faceParts[k]}", weight = 1.0))
	out

# the archive keys of a head part's TRI files
pub fn headPartTris(part esm.Record) str[]:
	part.fields.filter(.tag == "NAM1").map(skyrim.modelKey(part.body.cStringAt(.at)))

# the part's positions moved by each morph a TRI of the same vertex count has, the morphs' deltas
# turned into the model's space by the part's transform
fn applyMorphs(mut part nif.Part, tris Tri[], weights MorphWeight[]):
	for t in tris:
		if t.positions.len != part.positions.len: continue
		for w in weights:
			want = w.name.lower()
			m = t.morphs.find(.name.lower() == want) ?? continue
			for v in 0..part.positions.len:
				part.positions[v] += part.transform.applyDirection(m.deltas[v]) * w.weight

# The head parts' models as character creation builds them for the actor, each moved by its TRI
# files' morphs; or why one cannot be read.
pub fn morphedHead(i skyrim.Install, parts esm.Record[], weights MorphWeight[]) BodyPart[] ? str:
	out = []
	for part in parts:
		path = esm.textOf(part.body, part.fields, "MODL")
		if path == "": continue
		tris = []
		for key in part.headPartTris():
			tris.push(try i.readTriKey(key))
		worn = try i.readBodyPart(part.headKind(), skyrim.modelKey(path), 1.0)
		for k in 0..worn.parts.len:
			worn.parts[k].applyMorphs(tris, weights)
		out.push(worn)
	out

# one of the race's face tint layers: its index (what an actor's TINI names), its mask's archive
# key and its kind (TINP: 1 lips, 2 cheeks, 3 eyeliner, 4 and 5 eye sockets, 6 skin tone, 7 war
# paint, 8 frown lines, 9 lower cheeks, 10 nose, 11 chin, 12 neck, 13 forehead, 14 dirt)
pub type TintLayer:
	index i64
	mask str
	kind i64

# the race's tint layers for the sex, in its head data's order
pub fn raceTintLayers(race esm.Record, female bool) TintLayer[]:
	out = []
	for f in race.raceHeadFields(female):
		if f.tag == "TINI": out.push(TintLayer(index = race.body.u16le(f.at), mask = "", kind = 0))
		if out.isEmpty: continue
		last = out.len - 1
		if f.tag == "TINT": out[last].mask = nif.textureKey(race.body.cStringAt(f.at))
		if f.tag == "TINP": out[last].kind = race.body.u16le(f.at)
	out

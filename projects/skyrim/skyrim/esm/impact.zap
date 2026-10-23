# What a thing sounds like when it meets another (xEdit's wbDefinitionsTES5, CommonLibSSE's
# BGSMaterialType and BGSFootstepSet): a material (MATT) names its parent and its impact data set
# (HNAM); an impact data set (IPDS) pairs materials met with impacts (IPCT), whose sounds are a
# descriptor for an NPC (SNAM) and one for the player (NAM1); a footstep (FSTP) is a text key of
# the clips (ANAM: "FootLeft") and the impact data set it plays on the floor's material; a
# footstep set (FSTS) lists them by gait. The collision of a model names a material by the CRC-32
# (begun at 0, not inverted) of its MNAM in lower case, as Skyrim's BSCRC32 hashes it: "stone" is
# NifSkope's SKY_HAV_MAT_STONE, 3741512247. The default objects (DOBJ) give the sounds an item
# without its own plays when taken (PUSG, PUSW...).

import digest

pub type Material:
	editorId str
	parent i64   # PNAM, 0 for none
	impacts i64   # HNAM: what it sounds like when it hits something, 0 for none

# A footstep set: the footsteps of each gait.
pub type FootstepSet:
	walk i64[]
	run i64[]
	sprint i64[]
	sneak i64[]
	swim i64[]

# A footstep: the clips' text key it answers and the impact data set it plays.
pub type Footstep:
	tag str
	impacts i64

# The Havok material hash of a material's name (MNAM).
pub fn materialHash(name str) i64:
	digest.crcOver(0, name.lower().bytes())

# every material by the hash of its name, as a model's collision names it
pub fn materialsByHash(mut e Esm) {i64: i64}:
	out {i64: i64} = {}
	for id in e.formsOfKind("MATT"):
		r = e.recordOf(id) ?? continue
		name = textOf(r.body, r.fields, "MNAM")
		if name != "": out[materialHash(name)] = id
	out

pub fn material(mut e Esm, formId i64) Material?:
	r = try e.recordOf(formId)
	if r.kind != "MATT": return none
	Material(
		editorId = textOf(r.body, r.fields, "EDID"),
		parent = r.formOf("PNAM") ?? 0,
		impacts = r.formOf("HNAM") ?? 0
	)

# The impact data set a material sounds with when it hits something: its own, else its parent's,
# up the chain; 0 for none.
pub fn impactSetOf(mut e Esm, material i64) i64:
	at = material
	loop 8:
		m = e.material(at) ?? return 0
		if m.impacts != 0: return m.impacts
		at = m.parent
	0

# The impact the set has for a material met: the material's own, else its parent's, up the
# chain; none when the set has none for any of them.
pub fn impactFor(mut e Esm, set i64, material i64) i64?:
	r = try e.recordOf(set)
	if r.kind != "IPDS": return none
	pairs {i64: i64} = {}
	for f in r.fields:
		if f.tag == "PNAM" and f.size >= 8:
			pairs[i64(r.body.u32le(f.at))] = r.body.u32le(f.at + 4)
	at = material
	loop 8:
		if pairs.get(at) is impact: return impact
		at = (try e.material(at)).parent
		if at == 0: return none
	none

# The sound descriptor an impact plays: the player's (NAM1) when `player` and it has one, else
# the NPCs' (SNAM); 0 for none.
pub fn impactSound(mut e Esm, impact i64, player bool) i64:
	r = e.recordOf(impact) ?? return 0
	if r.kind != "IPCT": return 0
	npc = r.formOf("SNAM") ?? 0
	if player: return r.formOf("NAM1") ?? npc
	npc

# A footstep set by form id: DATA lists the footsteps swimming, sneaking, sprinting, running then
# walking, XCNT counting them walking, running, sprinting, sneaking then swimming.
pub fn footstepSet(mut e Esm, formId i64) FootstepSet?:
	r = try e.recordOf(formId)
	if r.kind != "FSTS": return none
	counts = try dataOf(r.fields, "XCNT")
	steps = formsOf(r.body, r.fields, "DATA")
	n = (0..5).map(i64(r.body.u32le(counts + 4 * it)))
	ends = [n[4], n[4] + n[3], n[4] + n[3] + n[2], n[4] + n[3] + n[2] + n[1], steps.len]
	if ends[3] + n[0] != steps.len: return none
	FootstepSet(
		swim = steps[..ends[0]].copy(),
		sneak = steps[ends[0]..ends[1]].copy(),
		sprint = steps[ends[1]..ends[2]].copy(),
		run = steps[ends[2]..ends[3]].copy(),
		walk = steps[ends[3]..].copy()
	)

pub fn footstep(mut e Esm, formId i64) Footstep?:
	r = try e.recordOf(formId)
	if r.kind != "FSTP": return none
	Footstep(tag = textOf(r.body, r.fields, "ANAM"), impacts = r.formOf("DATA") ?? 0)

# The form the default objects (DOBJ) name by this code ("PUSG"), none when they name none. The
# last plugin that names it wins: an overlay's DOBJ leaves what it does not change empty.
pub fn defaultObject(mut e Esm, code str) i64?:
	n = e.overlays.len
	for k in 0..n:
		if e.overlays[n - 1 - k].ownDefaultObject(code) is form: return form
	e.ownDefaultObject(code)

fn ownDefaultObject(mut e Esm, code str) i64?:
	for id in e.formsOfKind("DOBJ"):
		r = e.ownRecord(id) ?? continue
		d = bytesOf(r.body, r.fields, "DNAM")
		for k in 0..d.len / 8:
			if str(d[8 * k..8 * k + 4]) == code:
				form = i64(d.u32le(8 * k + 4))
				if form != 0: return form
	none

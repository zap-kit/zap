# Quests (QUST) as the dialogue reads them: the flags (DNAM: 1 start game enabled, 2 completed),
# the priority that orders their dialogue, the conditions on all their dialogue (those before
# NEXT), the stages (INDX: the stage, flags 2 the start-up stage, 4 the shut-down stage) and the
# aliases (ALST for a reference, ALLS for a location, up to ALED), each filled one way: a
# specific reference (ALFR), a unique actor (ALUA), another quest's alias (ALEQ, ALEA), or one the
# game finds or makes as the quest starts (left unfilled here). Layout after UESP's QUST page and
# xEdit's wbDefinitionsTES5.

import skyrim.esm

# DNAM's flag of a quest done (the start one is esm.questStartGameEnabled)
pub questCompleted = 0x2

pub type Alias:
	id i64
	name str
	location bool   # a location alias (ALLS)
	flags i64
	refId i64   # ALFR, 0 for none
	uniqueActor i64   # ALUA, 0 for none
	externalQuest i64   # ALEQ, 0 for none
	externalAlias i64   # ALEA

pub type Quest:
	formId i64
	editorId str
	flags i64
	priority i64
	conditions esm.Condition[]   # on every topic of the quest
	stages i64[]
	startStage i64   # its start-up stage (INDX flag 2), -1 for none
	aliases Alias[]
	vmad u8[]

fn newAlias(id i64, location bool):
	Alias(
		id,
		name = "",
		location,
		flags = 0,
		refId = 0,
		uniqueActor = 0,
		externalQuest = 0,
		externalAlias = 0
	)

# long: one arm per alias field
# the aliases among the fields, in order
fn aliasesOf(r esm.Record):
	out = []
	for f in r.fields:
		match f.tag:
			"ALST": out.push(newAlias(r.body.u32le(f.at), false))
			"ALLS": out.push(newAlias(r.body.u32le(f.at), true))
			_:
				if out.isEmpty: continue
				k = out.len - 1
				match f.tag:
					"ALID": out[k].name = r.body.cStringAt(f.at)
					"FNAM": out[k].flags = r.body.u32le(f.at)
					"ALFR": out[k].refId = r.body.u32le(f.at)
					"ALUA": out[k].uniqueActor = r.body.u32le(f.at)
					"ALEQ": out[k].externalQuest = r.body.u32le(f.at)
					"ALEA": out[k].externalAlias = r.body.i32le(f.at)
					_: pass
	out

# where NEXT ends the conditions on the dialogue, 0 when there is none
fn nextMarker(r esm.Record):
	for k, f in r.fields:
		if f.tag == "NEXT": return k
	0

pub fn questOf(r esm.Record) Quest:
	dnam = esm.dataOf(r.fields, "DNAM") ?? 0
	stages, start = r.questStages()
	Quest(
		formId = r.formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		flags = r.body.u16le(dnam),
		priority = r.body[dnam + 2],
		conditions = esm.conditionsIn(r.body, r.fields[..r.nextMarker()]),
		stages,
		startStage = start,
		aliases = r.aliasesOf(),
		vmad = esm.bytesOf(r.body, r.fields, "VMAD")
	)

# the alias with this id of the quest, none when it has none
pub fn aliasOf(q Quest, id i64) Alias?:
	q.aliases.find(.id == id)

# The scripts a cell binds: each placed reference's own VMAD and its base record's, whose scripts
# the game runs on every reference to that base.

import skyrim.esm

pub type Binding:
	placed i64   # the placed reference the scripts run on
	record i64   # the record the VMAD is on: the reference itself or its base
	kind str   # that record's type
	editorId str
	vmad Vmad

# the record's VMAD and its bytes, none when it has none; the program stops on a damaged one
pub fn vmadOf(r esm.Record) (Vmad, u8[])?:
	bytes = esm.bytesOf(r.body, r.fields, "VMAD")
	if bytes.isEmpty: return none
	vmad = readVmad(bytes) ?? fail("{r.kind} {r.formId:08X}: {error}")
	(vmad, bytes)

fn bindingOf(r esm.Record, placed i64) Binding?:
	vmad, _ = try r.vmadOf()
	Binding(
		placed,
		record = r.formId,
		kind = r.kind.copy(),
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		vmad
	)

# every binding of the interior cell with this editor id, a reference's own before its base's;
# none when the plugin has no such cell
pub fn cellBindings(mut e esm.Esm, cell str) Binding[]?:
	placed = try e.cellRecords(cell)
	out = []
	for r in placed:
		if r.bindingOf(r.formId) is own: out.push(own)
		name = esm.dataOf(r.fields, "NAME") ?? continue
		base = e.recordOf(r.body.u32le(name)) ?? continue
		if base.bindingOf(r.formId) is b: out.push(b)
	out

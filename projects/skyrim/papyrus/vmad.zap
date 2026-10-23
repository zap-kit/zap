# VMAD, the field that binds Papyrus scripts to a record, little-endian: a version (2 to 5), the
# object format (1: form id then alias; 2: alias then form id), the scripts, each a name (u16
# length then bytes), a status byte from version 4, and its properties: a name, a type, a status
# byte from version 4, the value. Types 1 object (8 bytes), 2 string, 3 int, 4 float, 5 bool, and
# 11 to 15 arrays of them (a u32 count first). Quests, dialogue, packages, perks and scenes add
# their fragments after the scripts: a dialogue response's (TIF__<form id>) the functions run
# when its line begins and ends, a quest's (QF_<editor id>_<form id>) one function per stage and
# log entry, then its aliases' scripts. Source: UESP's "Mod File Format/VMAD Field".

pub type VmadValue:
	Object(formId i64, alias i64)   # alias -1 when the form is not a quest's alias
	Text(text str)
	Int(n i64)
	Float(x f32)
	Bool(b bool)

pub type VmadProperty:
	name str
	kind i64   # 1 to 5, or 11 to 15 for an array
	status i64
	values VmadValue[]   # one for a single value

pub fn isArray(p VmadProperty) bool:
	p.kind >= 11

pub type BoundScript:
	name str
	status i64
	properties VmadProperty[]

pub type Vmad:
	version i64
	objectFormat i64
	scripts BoundScript[]
	fragmentsAt i64 = 0   # where the fragments start in the field's bytes

# a dialogue response's fragments: the script and the functions run when its line begins and ends
pub type InfoFragments:
	script str
	begin str   # "" for none
	end str

# a quest's fragment run when the stage is set with this log entry
pub type StageFragment:
	stage i64
	logEntry i64
	function str

# a quest alias's scripts
pub type AliasScripts:
	alias i64
	scripts BoundScript[]

pub type QuestFragments:
	script str
	stages StageFragment[]
	aliases AliasScripts[]

fn wideText(mut r Reader):
	n = i64(r.u16())
	if not r.has(n): return ""
	str(r.bytes(n))

fn vmadValue(mut r Reader, kind i64, objectFormat i64) VmadValue:
	match kind:
		1:
			if objectFormat == 1:
				formId = i64(r.u32())
				alias = i64(r.i16())
				r.skip(2)
				return .Object(formId, alias)
			r.skip(2)
			alias = i64(r.i16())
			.Object(r.u32(), alias)
		2: .Text(r.wideText())
		3: .Int(r.i32())
		4: .Float(r.f32())
		5: .Bool(r.u8() != 0)
		_:
			r.short = true
			.Int(0)

fn vmadProperty(mut r Reader, v Vmad):
	name = r.wideText()
	kind = i64(r.u8())
	status = i64(r.u8()) if v.version >= 4 else 1
	values = []
	if kind >= 11:
		loop i64(r.u32()):
			values.push(r.vmadValue(kind - 10, v.objectFormat))
			if r.short: break
	else:
		values.push(r.vmadValue(kind, v.objectFormat))
	VmadProperty(name, kind, status, values)

# a count then that many scripts with their properties
fn boundScripts(mut r Reader, v Vmad):
	out = []
	loop i64(r.u16()):
		name = r.wideText()
		status = i64(r.u8()) if v.version >= 4 else 0
		properties = []
		loop i64(r.u16()):
			properties.push(r.vmadProperty(v))
			if r.short: break
		out.push(BoundScript(name, status, properties))
		if r.short: break
	out

# the scripts of a VMAD field's bytes d, or why they cannot be read
pub fn readVmad(d u8[]) Vmad ? str:
	r = Reader(d)
	v = Vmad(version = r.i16(), objectFormat = r.i16(), scripts = [])
	if v.version < 2 or v.version > 5: return "VMAD version {v.version} is unknown"
	v.scripts = r.boundScripts(v)
	if r.short: return "a VMAD field is cut short"
	v.fragmentsAt = r.at
	v

# a fragment's entry after its first byte: the script then the function
fn fragmentFunction(mut r Reader) str:
	r.skip(1)
	r.wideText()
	r.wideText()

# The fragments of a dialogue response's VMAD (bytes d, read as v), none when it has none.
pub fn infoFragments(d u8[], v Vmad) InfoFragments?:
	if v.fragmentsAt + 2 > d.len: return none
	r = Reader(d, at = v.fragmentsAt + 1)
	flags = i64(r.u8())
	f = InfoFragments(script = r.wideText(), begin = "", end = "")
	if (flags & 1) != 0: f.begin = r.fragmentFunction()
	if (flags & 2) != 0: f.end = r.fragmentFunction()
	if r.short: return none
	f

# the alias scripts that close a quest's fragments
fn aliasScripts(mut r Reader, v Vmad):
	out = []
	loop i64(r.u16()):
		r.skip(2 if v.objectFormat == 2 else 4)
		alias = i64(r.i16())
		r.skip(4 if v.objectFormat == 2 else 2)
		inner = Vmad(version = r.i16(), objectFormat = r.i16(), scripts = [])
		out.push(AliasScripts(alias, scripts = r.boundScripts(inner)))
		if r.short: break
	out

# The fragments of a quest's VMAD (bytes d, read as v), none when it has none.
pub fn questFragments(d u8[], v Vmad) QuestFragments?:
	if v.fragmentsAt + 3 > d.len: return none
	r = Reader(d, at = v.fragmentsAt + 1)
	count = i64(r.u16())
	q = QuestFragments(script = r.wideText(), stages = [], aliases = [])
	loop count:
		stage = i64(r.u16())
		r.skip(2)
		logEntry = i64(r.i32())
		q.stages.push(StageFragment(stage, logEntry, function = r.fragmentFunction()))
		if r.short: return none
	q.aliases = r.aliasScripts(v)
	if r.short: return none
	q

pub fn vmadValueText(x VmadValue) str:
	match x:
		Object(formId, alias): "{formId:08X}" if alias < 0 else "{formId:08X} alias {alias}"
		Text(text): "\"{text}\""
		Int(n): "{n}"
		Float(f): "{f}"
		Bool(b): "true" if b else "false"

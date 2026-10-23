# Papyrus's compiled scripts (PEX), read whole. Big-endian in Skyrim: the magic 0xFA57C0DE, the
# version (3.2), the game id (1), the compile time, the source, user and machine names (u16 length
# then bytes), the string table (every later name is a u16 index into it), the optional debug
# info (each function's source line per instruction), the user flags, then the objects (one per
# script): variables, properties and states, each state a list of functions whose code is
# instructions of an opcode and its operands. Sources: UESP's "Papyrus Script File Format" and
# Champollion's reader (github.com/Orvid/Champollion, Pex/FileReader.cpp, Pex/Instruction.cpp).

pub magic = 0xFA57_C0DE

# an operand of an instruction, or a variable's initial value, as the file holds it: type 0 none,
# 1 an identifier (a variable, a function, a script), 2 a string, 3 an integer, 4 a float, 5 a bool
pub type Operand:
	Null
	Ident(name str)
	Text(text str)
	Int(n i64)
	Float(x f32)
	Bool(b bool)

pub type OpInfo:
	name str
	args i64
	varargs bool   # a count (an integer operand) and that many operands follow the fixed ones

# long: the 36 opcodes of Skyrim's Papyrus in their numbers' order, one line each
# What each opcode is called (as Champollion prints it) and the operands it takes, by its number.
pub opcodes = [
	OpInfo(name = "nop", args = 0, varargs = false),
	OpInfo(name = "iadd", args = 3, varargs = false),
	OpInfo(name = "fadd", args = 3, varargs = false),
	OpInfo(name = "isub", args = 3, varargs = false),
	OpInfo(name = "fsub", args = 3, varargs = false),
	OpInfo(name = "imul", args = 3, varargs = false),
	OpInfo(name = "fmul", args = 3, varargs = false),
	OpInfo(name = "idiv", args = 3, varargs = false),
	OpInfo(name = "fdiv", args = 3, varargs = false),
	OpInfo(name = "imod", args = 3, varargs = false),
	OpInfo(name = "not", args = 2, varargs = false),
	OpInfo(name = "ineg", args = 2, varargs = false),
	OpInfo(name = "fneg", args = 2, varargs = false),
	OpInfo(name = "assign", args = 2, varargs = false),
	OpInfo(name = "cast", args = 2, varargs = false),
	OpInfo(name = "cmp_eq", args = 3, varargs = false),
	OpInfo(name = "cmp_lt", args = 3, varargs = false),
	OpInfo(name = "cmp_le", args = 3, varargs = false),
	OpInfo(name = "cmp_gt", args = 3, varargs = false),
	OpInfo(name = "cmp_ge", args = 3, varargs = false),
	OpInfo(name = "jmp", args = 1, varargs = false),
	OpInfo(name = "jmpt", args = 2, varargs = false),
	OpInfo(name = "jmpf", args = 2, varargs = false),
	OpInfo(name = "callmethod", args = 3, varargs = true),
	OpInfo(name = "callparent", args = 2, varargs = true),
	OpInfo(name = "callstatic", args = 3, varargs = true),
	OpInfo(name = "return", args = 1, varargs = false),
	OpInfo(name = "strcat", args = 3, varargs = false),
	OpInfo(name = "propget", args = 3, varargs = false),
	OpInfo(name = "propset", args = 3, varargs = false),
	OpInfo(name = "array_create", args = 2, varargs = false),
	OpInfo(name = "array_length", args = 2, varargs = false),
	OpInfo(name = "array_getelement", args = 3, varargs = false),
	OpInfo(name = "array_setelement", args = 3, varargs = false),
	OpInfo(name = "array_findelement", args = 4, varargs = false),
	OpInfo(name = "array_rfindelement", args = 4, varargs = false)
]

# the number of the opcode with this name, none for no opcode
pub fn opcodeOf(name str) i64?:
	for k, o in opcodes:
		if o.name == name: return k
	none

pub type Instruction:
	op i64   # an index of opcodes
	args Operand[]
	varargs Operand[]

pub type TypedName:
	name str
	typeName str

pub type Function:
	name str   # "" for a property's getter or setter
	returnType str
	doc str
	userFlags i64
	flags i64   # 1 global (static), 2 native
	params TypedName[]
	locals TypedName[]
	code Instruction[]

pub fn isGlobal(f Function) bool:
	(f.flags & 1) != 0

pub fn isNative(f Function) bool:
	(f.flags & 2) != 0

pub type State:
	name str   # "" for the empty state, where functions outside any state live
	functions Function[]

pub type Variable:
	name str
	typeName str
	userFlags i64
	initial Operand

# a property: an auto property keeps its value in the variable autoVar; another has a getter, a
# setter or both
pub type Property:
	name str
	typeName str
	doc str
	userFlags i64
	flags i64   # 1 readable, 2 writable, 4 auto
	autoVar str
	getter Function?
	setter Function?

pub type ScriptObject:
	name str
	parent str   # "" for none
	doc str
	userFlags i64
	autoState str
	variables Variable[]
	properties Property[]
	states State[]

# a function's source lines, one per instruction; kind 0 a function, 1 a getter, 2 a setter
pub type DebugFunction:
	object str
	state str
	function str
	kind i64
	lines i64[]

pub type UserFlag:
	name str
	bit i64

pub type Script:
	major i64
	minor i64
	gameId i64
	compiled i64   # the compile time, seconds since 1970
	source str
	user str
	machine str
	modified i64   # the debug info's time, 0 without it
	debug DebugFunction[]
	userFlags UserFlag[]
	objects ScriptObject[]

# a u16-sized text
fn longText(mut r Reader):
	n = i64(r.u16())
	if not r.has(n): return ""
	str(r.bytes(n))

# a name: a u16 index into the string table; one out of the table marks the reader short
fn name(mut r Reader, strings str[]):
	i = i64(r.u16())
	if i >= strings.len:
		r.short = true
		return ""
	strings[i].copy()

fn operand(mut r Reader, strings str[]) Operand:
	kind = r.u8()
	match kind:
		0: .Null
		1: .Ident(r.name(strings))
		2: .Text(r.name(strings))
		3: .Int(r.i32())
		4: .Float(r.f32())
		5: .Bool(r.u8() != 0)
		_:
			r.short = true
			.Null

fn typedNames(mut r Reader, strings str[]):
	out = []
	loop i64(r.u16()):
		out.push(TypedName(name = r.name(strings), typeName = r.name(strings)))
		if r.short: break
	out

fn instruction(mut r Reader, strings str[]):
	op = i64(r.u8())
	if op >= opcodes.len:
		r.short = true
		return Instruction(op = 0, args = [], varargs = [])
	info = opcodes[op]
	args = []
	loop info.args:
		args.push(r.operand(strings))
	varargs = []
	if info.varargs:
		match r.operand(strings):
			Int(n):
				loop n:
					varargs.push(r.operand(strings))
					if r.short: break
			_: r.short = true
	Instruction(op, args, varargs)

fn function(mut r Reader, strings str[], name str):
	returnType = r.name(strings)
	doc = r.name(strings)
	userFlags = i64(r.u32())
	flags = i64(r.u8())
	params = r.typedNames(strings)
	locals = r.typedNames(strings)
	code = []
	loop i64(r.u16()):
		code.push(r.instruction(strings))
		if r.short: break
	Function(name = name.copy(), returnType, doc, userFlags, flags, params, locals, code)

fn variable(mut r Reader, strings str[]):
	Variable(
		name = r.name(strings),
		typeName = r.name(strings),
		userFlags = r.u32(),
		initial = r.operand(strings)
	)

fn property(mut r Reader, strings str[]):
	name = r.name(strings)
	typeName = r.name(strings)
	doc = r.name(strings)
	userFlags = i64(r.u32())
	flags = i64(r.u8())
	autoVar = ""
	getter Function? = none
	setter Function? = none
	if (flags & 4) != 0:
		autoVar = r.name(strings)
	else:
		if (flags & 1) != 0: getter = r.function(strings, "")
		if (flags & 2) != 0: setter = r.function(strings, "")
	Property(name, typeName, doc, userFlags, flags, autoVar, getter, setter)

fn state(mut r Reader, strings str[]):
	name = r.name(strings)
	functions = []
	loop i64(r.u16()):
		fname = r.name(strings)
		functions.push(r.function(strings, fname))
		if r.short: break
	State(name, functions)

fn object(mut r Reader, strings str[]):
	name = r.name(strings)
	r.skip(4)   # the object's size in bytes
	parent = r.name(strings)
	doc = r.name(strings)
	userFlags = i64(r.u32())
	autoState = r.name(strings)
	variables = []
	loop i64(r.u16()):
		variables.push(r.variable(strings))
		if r.short: break
	properties = []
	loop i64(r.u16()):
		properties.push(r.property(strings))
		if r.short: break
	states = []
	loop i64(r.u16()):
		states.push(r.state(strings))
		if r.short: break
	ScriptObject(name, parent, doc, userFlags, autoState, variables, properties, states)

fn debugFunctions(mut r Reader, strings str[]):
	out = []
	loop i64(r.u16()):
		object = r.name(strings)
		state = r.name(strings)
		function = r.name(strings)
		kind = i64(r.u8())
		lines = []
		loop i64(r.u16()):
			lines.push(i64(r.u16()))
		out.push(DebugFunction(object, state, function, kind, lines))
		if r.short: break
	out

# the script in the PEX bytes d, or why they are not one
pub fn readPex(d u8[]) Script ? str:
	if d.len < 4 or d.u32be(0) != magic: return "not a PEX file (no magic 0xFA57C0DE)"
	r = Reader(d, at = 4, big = true)
	major = i64(r.u8())
	minor = i64(r.u8())
	gameId = i64(r.u16())
	compiled = i64(r.u64())
	source = r.longText()
	user = r.longText()
	machine = r.longText()
	strings = []
	loop i64(r.u16()):
		strings.push(r.longText())
		if r.short: break
	modified = 0
	debug = []
	if r.u8() != 0:
		modified = i64(r.u64())
		debug = r.debugFunctions(strings)
	userFlags = []
	loop i64(r.u16()):
		userFlags.push(UserFlag(name = r.name(strings), bit = r.u8()))
	objects = []
	loop i64(r.u16()):
		objects.push(r.object(strings))
		if r.short: break
	if r.short: return "{source}: the file is cut short or names a string out of its table"
	if r.at != d.len: return "{source}: {d.len - r.at} bytes after the objects"
	if objects.isEmpty: return "{source}: no object"
	Script(
		major,
		minor,
		gameId,
		compiled,
		source,
		user,
		machine,
		modified,
		debug,
		userFlags,
		objects
	)

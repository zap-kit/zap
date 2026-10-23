# A script as text, laid out as Champollion's assembly listing (`.object`, `.variableTable`,
# `.state`, `.function`, `.code`), each instruction with its source line when the debug info has it.

pub fn operandText(o Operand) str:
	match o:
		Null: "none"
		Ident(name): name.copy()
		Text(text): "\"{text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")}\""
		Int(n): "{n}"
		Float(x): "{x}"
		Bool(b): "true" if b else "false"

pub fn instructionText(ins Instruction) str:
	parts = [opcodes[ins.op].name.copy()]
	for a in ins.args:
		parts.push(a.operandText())
	if opcodes[ins.op].varargs:
		parts.push("{ins.varargs.len}")
		for a in ins.varargs:
			parts.push(a.operandText())
	parts.join(" ")

# the source lines of the function `name` (kind 0 a function, 1 a getter, 2 a setter) of a state
fn linesOf(s Script, object str, state str, name str, kind i64) i64[]?:
	for d in s.debug:
		if d.kind == kind and d.function == name and d.state == state and d.object == object:
			return d.lines.copy()
	none

fn typedTable(mut out str[], title str, names TypedName[], pad str):
	out.push("{pad}.{title}Table")
	for n in names:
		out.push("{pad}  .{title} {n.name} {n.typeName}")
	out.push("{pad}.end{title.upper()[..1]}{title[1..]}Table")

fn functionText(mut out str[], f Function, lines i64[]?, pad str):
	out.push("{pad}.function {f.name}{" static" if f.isGlobal() else ""}{" native" if f.isNative() else ""}")
	out.push("{pad}  .userFlags {f.userFlags}")
	out.push("{pad}  .docString \"{f.doc}\"")
	out.push("{pad}  .return {f.returnType}")
	typedTable(out, "param", f.params, "{pad}  ")
	typedTable(out, "local", f.locals, "{pad}  ")
	out.push("{pad}  .code")
	for k in 0..f.code.len:
		line = ""
		if lines is ls and k < ls.len: line = " ;@line {ls[k]}"
		out.push("{pad}    {k:>4} {f.code[k].instructionText()}{line}")
	out.push("{pad}  .endCode")
	out.push("{pad}.endFunction")

fn propertyText(mut out str[], s Script, o ScriptObject, p Property):
	auto = " auto" if (p.flags & 4) != 0 else ""
	out.push("  .property {p.name} {p.typeName}{auto}")
	out.push("    .userFlags {p.userFlags}")
	out.push("    .docString \"{p.doc}\"")
	if not p.autoVar.isEmpty: out.push("    .autoVar {p.autoVar}")
	if p.getter is g: functionText(out, g, s.linesOf(o.name, "", p.name, 1), "    ")
	if p.setter is st: functionText(out, st, s.linesOf(o.name, "", p.name, 2), "    ")
	out.push("  .endProperty")

fn objectText(mut out str[], s Script, o ScriptObject):
	out.push(".object {o.name} {o.parent}")
	out.push("  .userFlags {o.userFlags}")
	out.push("  .docString \"{o.doc}\"")
	out.push("  .autoState {o.autoState}")
	out.push("  .variableTable")
	for v in o.variables:
		out.push("    .variable {v.name} {v.typeName}")
		out.push("      .userFlags {v.userFlags}")
		out.push("      .initialValue {v.initial.operandText()}")
	out.push("  .endVariableTable")
	out.push("  .propertyTable")
	for p in o.properties:
		propertyText(out, s, o, p)
	out.push("  .endPropertyTable")
	out.push("  .stateTable")
	for st in o.states:
		out.push("    .state {st.name}")
		for f in st.functions:
			functionText(out, f, s.linesOf(o.name, st.name, f.name, 0), "      ")
		out.push("    .endState")
	out.push("  .endStateTable")
	out.push(".endObject")

# the whole script as text
pub fn listing(s Script) str:
	out = [
		".info",
		"  .source \"{s.source}\"",
		"  .version {s.major}.{s.minor} game {s.gameId}",
		"  .modifyTime {s.modified}",
		"  .compileTime {s.compiled}",
		"  .user \"{s.user}\"",
		"  .computer \"{s.machine}\"",
		".endInfo",
		".userFlagsRef"
	]
	for f in s.userFlags:
		out.push("  .flag {f.name} {f.bit}")
	out.push(".endUserFlagsRef")
	for o in s.objects:
		objectText(out, s, o)
	out.join("\n")

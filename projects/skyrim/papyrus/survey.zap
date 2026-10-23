# What a script needs of the game: the natives its code can call, found by reading each call's
# receiver type (self, a parameter, a local or a variable as declared) and looking the function up
# in that type's chain, the scripts loaded as they are named.

fn receiverType(lib Library, script str, f Function, name str):
	key = name.lower()
	if key == "self": return script.copy()
	for p in f.params:
		if p.name.lower() == key: return p.typeName.copy()
	for l in f.locals:
		if l.name.lower() == key: return l.typeName.copy()
	for k in lib.chainOf(script):
		for v in lib.scripts[k].objects[0].variables:
			if v.name.lower() == key: return v.typeName.copy()
	""

# a call as the code names it: the receiver's type (or the script) and the function
type Call:
	typeName str
	name str

fn callsIn(lib Library, script str, f Function):
	out = []
	for ins in f.code:
		match ins.op:
			23: out.push(
				Call(
					typeName = lib.receiverType(script, f, ins.args[1].identOf()),
					name = ins.args[0].identOf()
				)
			)
			24: out.push(Call(typeName = lib.parentName(script), name = ins.args[0].identOf()))
			25: out.push(Call(typeName = ins.args[0].identOf(), name = ins.args[1].identOf()))
			_: pass
	out

fn functionsOf(o ScriptObject):
	out = []
	for st in o.states:
		for f in st.functions:
			out.push(f.copy())
	for p in o.properties:
		if p.getter is g: out.push(g.copy())
		if p.setter is s: out.push(s.copy())
	out

# the natives ("script.function", lower case) the script's own code calls, sorted, each once
pub fn nativesOf(mut vm Vm, script str) str[]:
	found {str: bool} = {}
	if not vm.ensureScript(script): return []
	k = vm.lib.scriptIndex(script) ?? return []
	functions = vm.lib.scripts[k].objects[0].functionsOf()
	for f in functions:
		for call in vm.lib.callsIn(script, f):
			if call.typeName.isEmpty or not vm.ensureScript(call.typeName): continue
			c = vm.lib.findFunction(call.typeName, "", call.name) ?? continue
			if vm.lib.codeOf(c).isNative():
				found["{vm.lib.nameOf(c.script).lower()}.{call.name.lower()}"] = true
	found.keys().sorted()

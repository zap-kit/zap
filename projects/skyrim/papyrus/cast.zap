# `cast`, which converts to the declared type of the variable it writes: numbers, bools and strings
# as Papyrus converts them, an object to the script type it is seen as (none when it is not one).

# the type a variable of thread t's current frame was declared with: a parameter, a local, or a
# variable of its object's scripts; "" when none declares it
pub fn declaredType(rt Runtime, lib Library, t i64, name str) str:
	key = name.lower()
	if key == "::state": return "string"
	frame = rt.threads[t].frames[rt.top(t)]
	f = lib.codeOf(frame.code)
	for p in f.params:
		if p.name.lower() == key: return p.typeName.lower()
	for l in f.locals:
		if l.name.lower() == key: return l.typeName.lower()
	if frame.me == 0: return ""
	for k in lib.chainOf(rt.objects[frame.me].script):
		for v in lib.scripts[k].objects[0].variables:
			if v.name.lower() == key: return v.typeName.lower()
	""

# whether a script only names a form's native type (Form, ObjectReference, Actor...): it declares no
# variable, so no form carries an instance of it of its own
fn isNativeType(lib Library, script str):
	k = lib.scriptIndex(script) ?? return false
	lib.scripts[k].objects[0].variables.isEmpty

# the object id seen as the script typeName: itself when its script extends it, another object of
# its form whose script does, a new handle for a native type, else 0 (none)
fn castObject(mut rt Runtime, lib Library, id i64, typeName str):
	if id == 0: return 0
	if lib.extendsScript(rt.objects[id].script, typeName): return id
	form = rt.objects[id].form
	for k, o in rt.objects:
		if k > 0 and o.form == form and lib.extendsScript(o.script, typeName): return k
	if lib.isNativeType(typeName) and lib.extendsScript(typeName, rt.objects[id].script):
		return lib.newObject(rt, form, typeName)
	0

pub fn cast(mut rt Runtime, lib Library, t i64, dest Operand, src Operand) Step:
	v = rt.read(t, src)
	typeName = rt.declaredType(lib, t, dest.identOf())
	match typeName:
		"int": rt.setDest(t, dest, .Int(v.asInt()))
		"float": rt.setDest(t, dest, .Float(v.asFloat()))
		"bool": rt.setDest(t, dest, .Bool(rt.isTrueValue(v)))
		"string": rt.setDest(t, dest, .Str(rt.valueText(v)))
		_:
			id = 0
			if v is Object(o): id = o
			if id == 0 or typeName.endsWith("[]") or typeName.isEmpty:
				rt.setDest(t, dest, v)
				return .Ran
			if rt.needed(lib, typeName) is missing: return .Needs(missing)
			if rt.needed(lib, rt.objects[id].script) is missing: return .Needs(missing)
			rt.setDest(t, dest, .Object(rt.castObject(lib, id, typeName)))
	.Ran

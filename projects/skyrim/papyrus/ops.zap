# The instructions: one step of a thread runs one, after Champollion's reading of each opcode's
# operands (Pex/Instruction.cpp) and the Creation Kit wiki's semantics. A jump's offset counts
# from the jump itself; a call names its function, its object (or script) and the variable that
# takes the result, then its arguments.

# runs thread t's next instruction
pub fn step(lib Library, mut rt Runtime, t i64) Step:
	if rt.threads[t].frames.isEmpty: return .Finished
	if rt.threads[t].wakeAt > rt.time: return .Waiting
	k = rt.top(t)
	c = rt.threads[t].frames[k].code
	pc = rt.threads[t].frames[k].pc
	f = lib.codeOf(c)
	if pc >= f.code.len:
		rt.returnFrom(t, .None)
		return .Ran
	rt.threads[t].frames[k].pc = pc + 1
	result = rt.execute(lib, t, f.code[pc], pc)
	if result is Needs: rt.threads[t].frames[k].pc = pc
	result

fn int(rt Runtime, t i64, o Operand):
	rt.read(t, o).asInt()

fn float(rt Runtime, t i64, o Operand):
	rt.read(t, o).asFloat()

fn text(rt Runtime, t i64, o Operand):
	rt.valueText(rt.read(t, o))

pub fn isTrueValue(rt Runtime, v Value) bool:
	match v:
		Array(id): id >= 0 and not rt.arrays[id].items.isEmpty
		_: v.isTrue(0)

fn truth(rt Runtime, t i64, o Operand):
	rt.isTrueValue(rt.read(t, o))

# Papyrus's ==: objects by the form they are bound to
fn equal(rt Runtime, t i64, a Operand, b Operand):
	x = rt.read(t, a)
	y = rt.read(t, b)
	if x is Object(i) and y is Object(j):
		return i == j or i != 0 and j != 0 and rt.objects[i].form == rt.objects[j].form
	x.valuesEqual(y)

fn order(rt Runtime, t i64, a Operand, b Operand):
	rt.read(t, a).compareValues(rt.read(t, b))

fn jump(mut rt Runtime, t i64, to i64):
	rt.threads[t].frames[rt.top(t)].pc = to

fn divide(mut rt Runtime, t i64, a Operand[], floats bool, remainder bool):
	if floats:
		d = rt.float(t, a[2])
		if d == 0.0: rt.note("error: division by zero")
		rt.setDest(t, a[0], .Float(0.0 if d == 0.0 else rt.float(t, a[1]) / d))
		return
	d = rt.int(t, a[2])
	if d == 0:
		rt.note("error: division by zero")
		rt.setDest(t, a[0], .Int(0))
		return
	n = rt.int(t, a[1])
	rt.setDest(t, a[0], .Int(wrap32(n % d if remainder else n / d)))

# long: the dispatch of the 36 opcodes, one arm each
fn execute(mut rt Runtime, lib Library, t i64, ins Instruction, pc i64):
	a = ins.args
	match ins.op:
		0: pass   # nop
		1: rt.setDest(t, a[0], .Int(wrap32(rt.int(t, a[1]) + rt.int(t, a[2]))))   # iadd
		2: rt.setDest(t, a[0], .Float(rt.float(t, a[1]) + rt.float(t, a[2])))   # fadd
		3: rt.setDest(t, a[0], .Int(wrap32(rt.int(t, a[1]) - rt.int(t, a[2]))))   # isub
		4: rt.setDest(t, a[0], .Float(rt.float(t, a[1]) - rt.float(t, a[2])))   # fsub
		5: rt.setDest(t, a[0], .Int(wrap32(rt.int(t, a[1]) * rt.int(t, a[2]))))   # imul
		6: rt.setDest(t, a[0], .Float(rt.float(t, a[1]) * rt.float(t, a[2])))   # fmul
		7: rt.divide(t, a, false, false)   # idiv
		8: rt.divide(t, a, true, false)   # fdiv
		9: rt.divide(t, a, false, true)   # imod
		10: rt.setDest(t, a[0], .Bool(not rt.truth(t, a[1])))   # not
		11: rt.setDest(t, a[0], .Int(wrap32(-rt.int(t, a[1]))))   # ineg
		12: rt.setDest(t, a[0], .Float(-rt.float(t, a[1])))   # fneg
		13: rt.setDest(t, a[0], rt.read(t, a[1]))   # assign
		14: return rt.cast(lib, t, a[0], a[1])
		15: rt.setDest(t, a[0], .Bool(rt.equal(t, a[1], a[2])))   # cmp_eq
		16: rt.setDest(t, a[0], .Bool(rt.order(t, a[1], a[2]) < 0))   # cmp_lt
		17: rt.setDest(t, a[0], .Bool(rt.order(t, a[1], a[2]) <= 0))   # cmp_le
		18: rt.setDest(t, a[0], .Bool(rt.order(t, a[1], a[2]) > 0))   # cmp_gt
		19: rt.setDest(t, a[0], .Bool(rt.order(t, a[1], a[2]) >= 0))   # cmp_ge
		20: rt.jump(t, pc + rt.int(t, a[0]))   # jmp
		21: if rt.truth(t, a[0]): rt.jump(t, pc + rt.int(t, a[1]))   # jmpt
		22: if not rt.truth(t, a[0]): rt.jump(t, pc + rt.int(t, a[1]))   # jmpf
		23: return rt.callMethod(lib, t, ins)
		24: return rt.callParent(lib, t, ins)
		25: return rt.invoke(lib, t, a[0].identOf(), "", a[1].identOf(), 0, ins.varargs, a[2])   # callstatic
		26: rt.returnFrom(t, rt.read(t, a[0]))   # return
		27: rt.setDest(t, a[0], .Str("{rt.text(t, a[1])}{rt.text(t, a[2])}"))   # strcat
		28: return rt.accessProperty(lib, t, a[0].identOf(), a[1], a[2], false)   # propget
		29: return rt.accessProperty(lib, t, a[0].identOf(), a[1], a[2], true)   # propset
		30: rt.arrayCreate(lib, t, a)
		31: rt.setDest(t, a[0], .Int(rt.arrayItems(t, a[1]).len))   # array_length
		32: rt.arrayGet(t, a)
		33: rt.arraySet(t, a)
		34: rt.arrayFind(t, a, false)
		35: rt.arrayFind(t, a, true)
		_: rt.note("error: opcode {ins.op}")
	.Ran

# the first script of the chain from this one that must still be loaded
fn needed(rt Runtime, lib Library, script str) str?:
	missing = try lib.missingScript(script)
	if rt.unavailable.get(missing) != none: return none
	missing

fn objectOf(rt Runtime, t i64, o Operand):
	match rt.read(t, o):
		Object(id): id
		_: 0

fn callMethod(mut rt Runtime, lib Library, t i64, ins Instruction) Step:
	name = ins.args[0].identOf()
	id = rt.objectOf(t, ins.args[1])
	if id == 0:
		rt.note("error: cannot call {name}() on a None object")
		rt.setDest(t, ins.args[2], .None)
		return .Ran
	script = rt.objects[id].script.copy()
	state = rt.objects[id].state.copy()
	rt.invoke(lib, t, script, state, name, id, ins.varargs, ins.args[2])

fn callParent(mut rt Runtime, lib Library, t i64, ins Instruction) Step:
	f = rt.threads[t].frames[rt.top(t)]
	me = f.me
	parent = lib.scripts[f.code.script].objects[0].parent.copy()
	state = rt.objects[me].state.copy()
	rt.invoke(lib, t, parent, state, ins.args[0].identOf(), me, ins.varargs, ins.args[1])

# calls the function `name` of script (in state) on the object me: a native at once, a script's
# function in a new frame whose result goes to dest
fn invoke(
	mut rt Runtime,
	lib Library,
	t i64,
	script str,
	state str,
	name str,
	me i64,
	operands Operand[],
	dest Operand
) Step:
	if rt.needed(lib, script) is missing: return .Needs(missing)
	args = operands.map(rt.read(t, it))
	match lib.findFunction(script, state, name):
		c:
			f = lib.codeOf(c)
			if not f.isNative():
				rt.startCall(lib, t, c, me, args, dest.identOf())
				return .Ran
			key = "{lib.nameOf(c.script).lower()}.{name.lower()}"
			call = NativeCall(key, me, args, thread = t, returnType = f.returnType.copy())
			result = lib.callNative(rt, call)
			rt.setDest(t, dest, result)
		none:
			rt.note("error: no function {name} in {script}")
			rt.setDest(t, dest, .None)
	.Ran

# propget (dest is the variable taking the value) or propset (dest is the value given)
fn accessProperty(
	mut rt Runtime,
	lib Library,
	t i64,
	name str,
	object Operand,
	dest Operand,
	set bool
) Step:
	id = rt.objectOf(t, object)
	if id == 0:
		rt.note("error: cannot reach property {name} of a None object")
		if not set: rt.setDest(t, dest, .None)
		return .Ran
	script = rt.objects[id].script.copy()
	if rt.needed(lib, script) is missing: return .Needs(missing)
	c = lib.findProperty(script, name) ?? return rt.missingProperty(t, script, name, dest, set)
	p = lib.propertyAt(c)
	if not p.autoVar.isEmpty:
		key = p.autoVar.lower()
		if set:
			rt.objects[id].vars[key] = rt.read(t, dest)
			return .Ran
		v = (rt.objects[id].vars.get(key) ?? .None).copy()
		rt.setDest(t, dest, v)
		return .Ran
	accessor = CodeRef(..c, state = -1, setter = set)
	if set:
		rt.startCall(lib, t, accessor, id, [rt.read(t, dest)], "")
	else:
		rt.startCall(lib, t, accessor, id, [], dest.identOf())
	.Ran

fn missingProperty(mut rt Runtime, t i64, script str, name str, dest Operand, set bool) Step:
	rt.note("error: no property {name} in {script}")
	if not set: rt.setDest(t, dest, .None)
	.Ran

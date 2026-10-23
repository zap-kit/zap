# Variables by name (Ruffle's core/src/avm1/scope.rs and activation.rs): looked up along the scope
# chain (with blocks, the function's locals, the target clip, _global), set where found or else on
# the target clip; a name with dots, slashes or a colon is a path ("_root.a.b", "/a/b:x", "../c")
# walked from the target.

import engine.swf

pub fn isPath(name str) bool:
	"." in name or "/" in name or ":" in name

# the value of a variable
pub fn getVariable(prog Program, mut m Machine, a Activation, name str) Value ? Thrown:
	match name:
		"this": return a.me.copy()
		"_global": return Value.Obj(m.globals)
		"arguments": if a.arguments >= 0: return Value.Obj(a.arguments)
		"super": return m.superOf(a)
		_: pass
	if isPath(name): return try prog.getPath(m, a, name)
	s = a.scope
	while s >= 0:
		o = m.scopes[s].object
		if prog.hasProperty(m, o, name): return try prog.getMember(m, .Obj(o), name)
		s = m.scopes[s].parent
	Value.Undefined

# the function a CallFunction names and the `this` it runs with
fn resolveCallable(prog Program, mut m Machine, a Activation, name str) (Value, Value) ? Thrown:
	fallback = Value.Obj(m.objectOfNode(prog, a.target)) if a.target >= 0 else Value.Undefined
	if isPath(name): return (try prog.getPath(m, a, name), fallback)
	s = a.scope
	while s >= 0:
		o = m.scopes[s].object
		if prog.hasProperty(m, o, name):
			f = try prog.getMember(m, .Obj(o), name)
			me = fallback if m.scopes[s].kind == local else Value.Obj(o)
			return (f, me)
		s = m.scopes[s].parent
	(Value.Undefined, fallback)

pub fn setVariable(prog Program, mut m Machine, a Activation, name str, v Value) () ? Thrown:
	if isPath(name):
		object, key = try prog.pathParent(m, a, name)
		try prog.setMember(m, object, key, v)
		return
	s = a.scope
	while s >= 0:
		o = m.scopes[s].object
		if m.scopes[s].kind == target or m.scopes[s].parent < 0 or prog.hasProperty(m, o, name):
			try prog.setMember(m, .Obj(o), name, v)
			return
		s = m.scopes[s].parent

# DefineLocal: a variable of the innermost function, or of the target clip outside one
pub fn defineLocal(prog Program, mut m Machine, a Activation, name str, v Value):
	s = a.scope
	while s >= 0:
		kind = m.scopes[s].kind
		if kind == local or kind == target or m.scopes[s].parent < 0:
			m.setOwn(m.scopes[s].object, name, v.copy())
			return
		s = m.scopes[s].parent

fn hasLocal(m Machine, a Activation, name str):
	s = a.scope
	while s >= 0:
		kind = m.scopes[s].kind
		if kind == local or kind == target:
			return m.heap[m.scopes[s].object].props.get(name) != none
		s = m.scopes[s].parent
	false

fn deleteVariable(mut m Machine, a Activation, name str):
	s = a.scope
	while s >= 0:
		o = m.scopes[s].object
		if m.heap[o].props.get(name) != none: return m.deleteOwn(o, name)
		s = m.scopes[s].parent
	false

# a path's value: its last part read from what the parts before it name
fn getPath(prog Program, mut m Machine, a Activation, name str) Value ? Thrown:
	object, key = try prog.pathParent(m, a, name)
	if key.isEmpty: return object
	try prog.getMember(m, object, key)

# what a path's parts but the last name, and the last: "a.b.c" is (a.b, "c"), "/a/b:x" is
# (the clip /a/b, "x"), "/a/b" is (the clip, "")
fn pathParent(prog Program, mut m Machine, a Activation, name str) (Value, str) ? Thrown:
	if ":" in name or "/" in name:
		cut = name.lastIndexOf(":")
		clipPath = name[..cut ?? len]
		key = name[(cut ?? len - 1) + 1..] if cut != none else ""
		n = prog.targetNode(m, a, clipPath) ?? return (Value.Undefined, "")
		return (Value.Obj(m.objectOfNode(prog, n)), key.copy())
	parts = name.split(".")
	object = try prog.getVariable(m, a, parts[0])
	for k in 1..parts.len - 1:
		object = try prog.getMember(m, object, parts[k])
	(object, parts[len - 1].copy())

# The node a target path names, from the activation's target: "/" or "_root" the root, ".." or
# "_parent" a parent, a name a child or, first, a variable holding a clip.
pub fn targetNode(prog Program, mut m Machine, a Activation, path str) i64?:
	if path.isEmpty: return a.target
	n = a.target if a.target >= 0 else 0
	parts = path.replace("/", ".").split(".")
	if path.startsWith("/"): n = 0
	for k, part in parts:
		if part.isEmpty: continue
		if part == ".." or part == "_parent":
			n = m.stage.nodes[n].parent
			if n < 0: return none
		elif part == "_root" or part == "_level0": n = 0
		elif part == "this": pass
		elif m.stage.childNamed(n, part) is c: n = c
		elif k == 0:
			v = prog.getVariable(m, a, part) ?? return none
			n = try m.nodeOf(v)
		else: return none
	n

# the node a value aims at: a clip, or a target path from the activation's target
pub fn nodeOfTarget(prog Program, mut m Machine, a Activation, v Value) i64?:
	if v is Obj: return m.nodeOf(v)
	path = v.primitiveText()
	prog.targetNode(m, a, path)

# TargetPath: a clip's path in slash syntax ("/a/b", "/" for the root)
fn targetPathOf(prog Program, m Machine, v Value):
	n = m.nodeOf(v) ?? return Value.Undefined
	names = []
	p = n
	while m.stage.nodes[p].parent >= 0:
		names.push(m.stage.nodes[p].placed.name.copy())
		p = m.stage.nodes[p].parent
	.Str("/{names.reversed().join("/")}")

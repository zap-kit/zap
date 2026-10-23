# The scripts the VM knows, found by lower-case name (Papyrus's names have no case), and the
# lookups over their inheritance: a function is looked for in the object's state, then in the
# empty state, in the script and then in each parent in turn; a property the same way.

import skyrim

pub type Library:
	scripts Script[]
	byName {str: i64}   # lower-case name to index in scripts

pub fn newLibrary() Library:
	Library(scripts = [], byName = {})

pub fn addScript(mut lib Library, move s Script):
	key = s.objects[0].name.lower()
	match lib.byName.get(key):
		k: lib.scripts[k] = s
		none: lib.byName[key] = lib.scripts.push(s)

# the index of the script with this name, none when it is not loaded
pub fn scriptIndex(lib Library, name str) i64?:
	lib.byName.get(name.lower())

pub fn hasScript(lib Library, name str) bool:
	lib.scriptIndex(name) != none

pub fn nameOf(lib Library, script i64) ref str:
	lib.scripts[script].objects[0].name

# the name of the script's parent, "" for none or when the script is not loaded
pub fn parentName(lib Library, script str) str:
	k = lib.scriptIndex(script) ?? return ""
	lib.scripts[k].objects[0].parent.copy()

# the scripts from this one up to its root, as far as they are loaded
pub fn chainOf(lib Library, name str) i64[]:
	out = []
	at = name.lower()
	while out.len < 64:
		k = lib.scriptIndex(at) ?? break
		out.push(k)
		at = lib.scripts[k].objects[0].parent.lower()
	out

# the first script of the chain from this one up that is not loaded, none when all are
pub fn missingScript(lib Library, name str) str?:
	at = name.lower()
	loop 64:
		if at.isEmpty: return none
		k = lib.scriptIndex(at) ?? return at
		at = lib.scripts[k].objects[0].parent.lower()
	none

# whether script is ancestor or inherits from it
pub fn extendsScript(lib Library, script str, ancestor str) bool:
	want = lib.scriptIndex(ancestor) ?? return false
	want in lib.chainOf(script)

# loads the script with this name and its parents from the install, or says which is missing
pub fn loadScripts(mut lib Library, install skyrim.Install, name str) ? str:
	loop 64:
		missing = lib.missingScript(name) ?? return
		lib.addScript(try install.loadScript(missing))

# where a function's code is: the script that has it, the state (-1 for a property's accessor), and
# the function's index in the state, or the property's
pub type CodeRef:
	script i64
	state i64
	index i64
	setter bool

fn functionIn(o ScriptObject, script i64, state str, name str) CodeRef?:
	for s, st in o.states:
		if st.name.lower() != state: continue
		for k, f in st.functions:
			if f.name.lower() == name: return CodeRef(script, state = s, index = k, setter = false)
	none

# the function `name` an object of `script` in `state` calls, none when no script of the chain has it
pub fn findFunction(lib Library, script str, state str, name str) CodeRef?:
	want = name.lower()
	inState = state.lower()
	for at in lib.chainOf(script):
		o = lib.scripts[at].objects[0]
		if not inState.isEmpty:
			if o.functionIn(at, inState, want) is c: return c
		if o.functionIn(at, "", want) is c: return c
	none

# the property `name` of the chain from script: the script that declares it and its index
pub fn findProperty(lib Library, script str, name str) CodeRef?:
	want = name.lower()
	for at in lib.chainOf(script):
		properties = lib.scripts[at].objects[0].properties
		for k, p in properties:
			if p.name.lower() == want:
				return CodeRef(script = at, state = -1, index = k, setter = false)
	none

pub fn propertyAt(lib Library, c CodeRef) ref Property:
	lib.scripts[c.script].objects[0].properties[c.index]

# the function a CodeRef names
pub fn codeOf(lib Library, c CodeRef) ref Function:
	if c.state >= 0: return lib.scripts[c.script].objects[0].states[c.state].functions[c.index]
	p = lib.propertyAt(c)
	accessor = p.setter if c.setter else p.getter
	match accessor:
		f: f
		none: fail(
			"{lib.nameOf(c.script)}: property {p.name} has no {"setter" if c.setter else "getter"}"
		)

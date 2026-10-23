# The Papyrus virtual machine: objects (instances of scripts bound to game forms, with their
# variables and state), arrays, threads of call frames, and the scheduler that wakes latent waits
# and sends the updates a script registered for. Each step runs one instruction (ops.zap); a thread
# that waits gives way, and every thread runs again when the frame's tick passes its time.
# Semantics after the Creation Kit wiki's Papyrus reference and Champollion's decompiler.

import skyrim
import game.sim

pub type Instance:
	script str   # the script it is an instance of, lower case
	form i64   # the game form it is bound to
	vars {str: Value}   # its variables by lower-case name, every script of its chain's
	state str

pub type ArrayData:
	items Value[]

pub type Frame:
	code CodeRef
	pc i64
	locals {str: Value}   # parameters and locals by lower-case name
	me i64   # the object it runs on, 0 for a global function
	resultTo str   # the caller's variable that takes the result, "" for none

pub type Thread:
	frames Frame[]
	wakeAt f64   # a latent call's end, in Runtime.time
	result Value   # what the first frame returned
	label str

# an update a script registered for: real seconds, or game days for the game-time ones
pub type Update:
	object i64
	at f64
	interval f64   # 0 for a single update
	gameTime bool

pub type Runtime:
	objects Instance[]   # 0 is none
	arrays ArrayData[]
	threads Thread[]
	updates Update[]
	time f64   # real seconds since the VM started
	world sim.GameWorld
	log str[]   # traces, stubbed natives and script errors, in order
	rng Random
	unavailable {str: bool}   # scripts the install lacks: calls into them do nothing
	sleepers i64[] = []   # the objects registered for the player's sleep (RegisterForSleep)

pub type Step:
	Ran
	Waiting
	Finished
	Needs(script str)   # the script must be loaded before the instruction runs again

pub type Vm:
	lib Library
	rt Runtime
	install skyrim.Install?   # where scripts are loaded from when first named

# the most instructions a thread runs in one call of runThreads before giving way
stepBudget = 1_000_000

pub fn newRuntime() Runtime:
	Runtime(
		objects = [Instance(script = "", form = 0, vars = {}, state = "")],
		arrays = [],
		threads = [],
		updates = [],
		time = 0.0,
		world = sim.newWorld(),
		log = [],
		rng = Random(1),
		unavailable = {}
	)

pub fn newVm(move install skyrim.Install?) Vm:
	Vm(lib = newLibrary(), rt = newRuntime(), install)

pub fn note(mut rt Runtime, line str):
	rt.log.push(line.copy())

pub fn top(rt Runtime, t i64) i64:
	rt.threads[t].frames.len - 1

# the value of an identifier in thread t's current frame: self, a local or parameter, the
# object's state or one of its variables; none for a name it does not have
pub fn readName(rt Runtime, t i64, name str) Value:
	key = name.lower()
	f = rt.threads[t].frames[rt.top(t)]
	if key == "self": return .Object(f.me)
	if f.locals.get(key) is v: return v.copy()
	if f.me == 0: return .None
	o = rt.objects[f.me]
	if key == "::state": return .Str(o.state.copy())
	match o.vars.get(key):
		v: v.copy()
		none: .None

pub fn writeName(mut rt Runtime, t i64, name str, move v Value):
	key = name.lower()
	k = rt.top(t)
	if rt.threads[t].frames[k].locals.get(key) != none:
		rt.threads[t].frames[k].locals[key] = v
		return
	me = rt.threads[t].frames[k].me
	if me == 0: return
	if key == "::state":
		if v is Str(s): rt.objects[me].state = s.lower()
		return
	rt.objects[me].vars[key] = v

pub fn read(rt Runtime, t i64, o Operand) Value:
	match o:
		Ident(name): rt.readName(t, name)
		_: o.literal()

pub fn setDest(mut rt Runtime, t i64, o Operand, move v Value):
	if o is Ident(name): rt.writeName(t, name, v)

pub fn identOf(o Operand) str:
	match o:
		Ident(name): name.copy()
		Text(text): text.copy()
		_: ""

# a variable's starting values for an object of this script: each script's of its chain
pub fn initialVars(lib Library, script str) {str: Value}:
	vars {str: Value} = {}
	for k in lib.chainOf(script):
		for v in lib.scripts[k].objects[0].variables:
			vars[v.name.lower()] = defaultOf(v.typeName) if v.initial == .Null
				else v.initial.literal()
	vars

fn autoStateOf(lib Library, script str):
	k = lib.scriptIndex(script) ?? return ""
	lib.scripts[k].objects[0].autoState.lower()

# a new object of this script on the form
pub fn newObject(lib Library, mut rt Runtime, form i64, script str) i64:
	o = Instance(
		script = script.lower(),
		form,
		vars = lib.initialVars(script),
		state = lib.autoStateOf(script)
	)
	rt.objects.push(o)

# the object for the form seen as typeName: an object bound to the form whose script is or
# extends that type, else a new one of that type (a form's native type: Actor, Quest...)
pub fn objectFor(lib Library, mut rt Runtime, form i64, typeName str) i64:
	if form == 0: return 0
	want = typeName.lower()
	for k, o in rt.objects:
		if k > 0 and o.form == form and (o.script == want or lib.extendsScript(o.script, want)):
			return k
	lib.newObject(rt, form, want)

pub fn newThread(mut rt Runtime, label str) i64:
	rt.threads.push(Thread(frames = [], wakeAt = 0.0, result = .None, label = label.copy()))

# pushes a frame running the function c on object me with these arguments
pub fn startCall(
	mut rt Runtime,
	lib Library,
	t i64,
	c CodeRef,
	me i64,
	move args Value[],
	resultTo str
):
	f = lib.codeOf(c)
	locals {str: Value} = {}
	for k, p in f.params:
		locals[p.name.lower()] = args[k].copy() if k < args.len else defaultOf(p.typeName)
	for l in f.locals:
		locals[l.name.lower()] = defaultOf(l.typeName)
	rt.threads[t].frames.push(Frame(code = c, pc = 0, locals, me, resultTo = resultTo.copy()))

# leaves thread t's current function with the value v
pub fn returnFrom(mut rt Runtime, t i64, move v Value):
	k = rt.top(t)
	if k < 0: return
	resultTo = move rt.threads[t].frames[k].resultTo
	rt.threads[t].frames.truncate(k)
	if k == 0:
		rt.threads[t].result = v
		return
	if not resultTo.isEmpty: rt.writeName(t, resultTo, v)

# whether the script and its parents are loaded, loading them from the install when they are not
pub fn ensureScript(mut vm Vm, name str) bool:
	loop 64:
		missing = vm.lib.missingScript(name) ?? return true
		if vm.rt.unavailable.get(missing) != none: return false
		vm.provide(missing)
	false

# loads the script from the install, or marks it unavailable
fn provide(mut vm Vm, name str):
	if vm.install is i:
		match i.loadScript(name):
			s:
				vm.lib.addScript(s)
				return
			error: vm.rt.note("error: {error}")
	vm.rt.note("error: no script {name}")
	vm.rt.unavailable[name.lower()] = true

# runs thread t until it waits or ends or has run budget instructions; whether it ended
fn runThread(mut vm Vm, t i64, budget i64):
	loop budget:
		match vm.lib.step(vm.rt, t):
			Ran: pass
			Waiting: return false
			Finished: return true
			Needs(name): vm.provide(name)
	false

# runs every thread that is not waiting, then forgets the ended ones
pub fn runThreads(mut vm Vm):
	t = 0
	while t < vm.rt.threads.len:
		if vm.rt.threads[t].wakeAt <= vm.rt.time: vm.runThread(t, stepBudget)
		t += 1
	k = vm.rt.threads.len - 1
	while k >= 0:
		if vm.rt.threads[k].frames.isEmpty: vm.rt.threads.remove(k)
		k -= 1

# starts the event `name` on the object when its script has it in its state; whether it has
pub fn sendEvent(mut vm Vm, object i64, name str, move args Value[]) bool:
	script = vm.rt.objects[object].script.copy()
	if not vm.ensureScript(script): return false
	c = vm.lib.findFunction(script, vm.rt.objects[object].state, name) ?? return false
	if vm.lib.codeOf(c).isNative(): return false
	t = vm.rt.newThread("{script}.{name}")
	vm.rt.startCall(vm.lib, t, c, object, args, "")
	true

# sends the event to every object bound to the form; how many have it
pub fn sendFormEvent(mut vm Vm, form i64, name str, args Value[]) i64:
	sent = 0
	for k in 1..vm.rt.objects.len:
		if vm.rt.objects[k].form == form and vm.sendEvent(k, name, args.copy()): sent += 1
	sent

# Runs the function `name` of the object (0 for a global function of script) to its end, a
# latent wait passing no time, and gives its result; none when the function is missing.
pub fn callFunction(mut vm Vm, script str, object i64, name str, move args Value[]) Value:
	if not vm.ensureScript(script): return .None
	state = vm.rt.objects[object].state.copy()
	c = vm.lib.findFunction(script, state, name) ?? return .None
	t = vm.rt.newThread("{script}.{name}")
	vm.rt.startCall(vm.lib, t, c, object, args, "")
	loop 1000:
		if vm.runThread(t, stepBudget): break
		if vm.rt.threads[t].wakeAt > vm.rt.time: vm.rt.time = vm.rt.threads[t].wakeAt
	result = move vm.rt.threads[t].result
	vm.rt.threads.remove(t)
	result

# The player's sleep beginning or ending, sent to the objects registered for it as the game's
# sleep events reach Papyrus: OnSleepStart(start, desired end), OnSleepStop(interrupted).
pub fn sendSleepStart(mut vm Vm, start f64, end f64):
	for object in vm.rt.sleepers.copy():
		vm.sendEvent(object, "OnSleepStart", [.Float(f32(start)), .Float(f32(end))])

pub fn sendSleepStop(mut vm Vm, interrupted bool):
	for object in vm.rt.sleepers.copy():
		vm.sendEvent(object, "OnSleepStop", [.Bool(interrupted)])

# Advances the clocks by seconds, sends the updates that fall due, and runs the threads.
pub fn tick(mut vm Vm, seconds f64):
	vm.rt.time += seconds
	vm.rt.world.playSeconds += seconds
	vm.rt.world.daysPassed += seconds * vm.rt.world.timeScale / 86400.0
	vm.rt.world.tickEffects(f32(seconds))
	k = 0
	while k < vm.rt.updates.len:
		u = vm.rt.updates[k]
		now = vm.rt.world.daysPassed if u.gameTime else vm.rt.time
		if u.at > now:
			k += 1
			continue
		if u.interval > 0.0:
			vm.rt.updates[k].at = now + u.interval
			k += 1
		else:
			vm.rt.updates.remove(k)
		vm.sendEvent(u.object, "OnUpdateGameTime" if u.gameTime else "OnUpdate", [])
	vm.runThreads()

# a value as Papyrus writes it in a string
pub fn valueText(rt Runtime, v Value) str:
	match v:
		None: "None"
		Int(n): "{n}"
		Float(x): floatText(x)
		Bool(b): "True" if b else "False"
		Str(text): text.copy()
		Object(id):
			if id == 0: return "None"
			o = rt.objects[id]
			"[{o.script} <{rt.world.editorIdOf(o.form)} ({o.form:08X})>]"
		Array(id): "[{rt.arrays[id].items.map(rt.valueText(it)).join(", ")}]"

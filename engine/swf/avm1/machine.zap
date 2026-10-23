# The ActionScript 2 virtual machine (AVM1) over a stage, ported from Ruffle's core/src/avm1
# (activation.rs for the actions, object/ and globals/ for the objects): the heap of objects (each
# a handle into a list, with its properties, its prototype and what it is: a plain object, a
# function of the movie's code or a native one, an array, a movie clip or a text field bound to a
# node of the stage, a boxed primitive), the scope chains, and the queue of what runs next. The
# program (Program) is what does not change: the scene and every block of the movie's code
# decoded once.

import engine.swf

# a value thrown by the movie's code (Throw), passed up through the calls to a catch
pub type Thrown:
	value Value

# property flags, as ASSetPropFlags sets them
pub dontEnum = 1
pub dontDelete = 2
pub readOnly = 4

pub type Prop:
	value Value
	getter i64 = -1   # addProperty's functions, -1 none
	setter i64 = -1
	flags i64 = 0

# a function of the movie's code: its DefineFunction action, the constant pool and scope chain it
# was made in, the node whose code made it
pub type ScriptFn:
	block i64
	at i64
	pool i64   # the ConstantPool action of its block it sees, -1 none
	scope i64
	base i64

pub type Kind:
	Plain
	Function(f ScriptFn)
	Native(id i64)
	Array
	Clip(node i64)   # a movie clip (or a button) of the stage
	Text(node i64)   # a text field of the stage
	Boxed(v Value)   # a String, Number or Boolean object
	Super(me i64, base i64)   # `super`: me's methods looked up past the prototype base

pub type Obj:
	proto i64 = -1
	props {str: Prop} = {}
	order str[] = []   # the properties' names in the order made, for enumeration
	kind Kind = .Plain
	items Value[] = []   # an array's elements
	interfaces i64[] = []   # a prototype's interfaces (ImplementsOp)

pub global = 0
pub target = 1
pub local = 2
pub within = 3

# a link of a scope chain: what names are looked up in, then its parent's
pub type Scope:
	parent i64   # -1 the end
	kind i64   # global, target, local or within (a with block)
	object i64

# onClipEvent's handlers decoded: the events and the block run on them
pub type ClipHandler:
	events i64
	key i64
	block i64

# what does not change while a movie plays: its scene and its code, decoded once
pub type Program:
	scene swf.Scene
	version i64
	blocks Block[] = []
	frameBlocks {i64: i64[]} = {}   # character << 24 | frame to the frame's DoActions
	initBlocks i64[] = []   # DoInitAction's, in the file's order
	clipBlocks {i64: ClipHandler[]} = {}   # by clipKey
	buttonBlocks {i64: ClipHandler[]} = {}   # a button's code by its character, events its conditions
	libraries i64[] = []   # each block's library: the movie it came from (0 the main one)
	translations {str: str} = {}   # Scaleform's translation of "$KEY" texts

# the key of a placement's clip actions: the timeline's character, the frame and the depth
pub fn clipKey(owner i64, frame i64, depth i64) i64:
	(owner << 40) | (frame << 20) | depth

# a native function: its group (the file that runs it) and its name
pub type NativeFn:
	group i64
	name str

# what runs next: code with a node as its target, a clip's class constructor, an event method
pub type Job:
	Run(node i64, block i64)
	Construct(node i64, ctor i64)
	Method(node i64, name str)

# setInterval's timer
pub type Interval:
	id i64
	me Value   # the object whose method it calls, or undefined
	function Value   # the function, or the method's name
	every f64   # milliseconds
	next f64
	args Value[]
	once bool   # setTimeout's: removed after it fires

# a function the game may call by name (ExternalInterface.addCallback)
pub type Callback:
	me Value
	function Value

# a call the movie made to the game (ExternalInterface.call, which GameDelegate.call wraps)
pub type ExternalCall:
	name str
	args Value[]

# How the game answers a call at once: by giving GameDelegate's `callback` the value the movie
# holds at `path` from _root (Skyrim answers RequestItemCardInfo with UpdateItemCardInfo and the
# selected item's card before the movie's code goes on).
pub type Answer:
	callback str
	path str

# What the game writes into the objects of a call it answers at once (Machine.replies): the text
# of the text field (or component) the call's argument `slot` is, one
# of `texts` picked by the number in argument `index`, or the array that argument is refilled with
# an object of each row's members; or (Merge) the rows' members set over the objects the array
# holds that have the same `key` member, a row that matches none added at the end. The arguments
# count from the first after the call's id.
pub type Reply:
	Text(slot i64, text str)
	TextAt(slot i64, index i64, texts str[])
	Fill(slot i64, rows Row[])
	Merge(slot i64, key str, rows Row[])

# an object the game makes: its members by name
pub type Row:
	members Member[]

pub type Member:
	name str
	value Value

# the window a movie is shown in: its size in pixels, how the stage is fit into it (Stage's
# scaleMode and align) and Scaleform's safe zone inset (the stage's pixels)
pub type Viewport:
	width f64 = 1280.0
	height f64 = 720.0
	scaleMode str = "showAll"
	align str = ""
	safeX f64 = 0.0
	safeY f64 = 0.0

pub type Protos:
	object i64 = -1
	function i64 = -1
	array i64 = -1
	string i64 = -1
	number i64 = -1
	boolean i64 = -1
	clip i64 = -1
	text i64 = -1
	button i64 = -1
	textFormat i64 = -1
	rectangle i64 = -1
	point i64 = -1
	date i64 = -1
	error i64 = -1

pub type Machine:
	stage swf.Stage
	heap Obj[] = []
	scopes Scope[] = []
	freeObjects i64[] = []   # slots the collector freed
	freeScopes i64[] = []
	liveAfterCollect i64 = 0   # the objects the last collection kept
	globals i64 = 0
	globalScope i64 = 0
	protos Protos = Protos()
	natives NativeFn[] = []
	classes {str: i64} = {}   # Object.registerClass: "library|exported name" to its class
	library i64 = 0   # the library of the code running, whose names registerClass binds
	initJobs Job[] = []
	constructJobs Job[] = []
	jobs Job[] = []
	intervals Interval[] = []
	nextInterval i64 = 1
	external ExternalCall[] = []
	callbacks {str: Callback} = {}   # ExternalInterface.addCallback's
	responses {str: Value[]} = {}   # what the game answers a GameDelegate call with, by its name or "name:first argument"
	answers {str: Answer} = {}   # calls the game answers at once through a callback
	replies {str: Reply[]} = {}   # calls the game answers at once by writing into their arguments
	log str[] = []   # traces and script errors, in order
	errors i64 = 0
	time f64 = 0.0   # milliseconds since the movie started
	depth i64 = 0   # calls deep
	steps i64 = 0   # actions run since the queue last started, against a script that never ends
	viewport Viewport = Viewport()
	stageObject i64 = -1   # the global Stage, whose members are the viewport's
	keyListeners i64 = -1   # Key's listeners, an array
	mouseListeners i64 = -1
	keysDown i64[] = []
	lastKey i64 = 0
	focus i64 = -1   # Selection's focused object
	mouse Vec2 = Vec2(0.0, 0.0)   # the pointer on the stage, pixels
	mouseDown bool = false
	hovered i64 = -1   # the node under the pointer with button handlers
	pressed i64 = -1   # the node the pointer was pressed over
	unimplemented {str: i64} = {}   # natives and actions asked for that do nothing, with counts

# a new plain object with this prototype
pub fn newObject(mut m Machine, proto i64) i64:
	m.place(Obj(proto))

pub fn newOf(mut m Machine, proto i64, move kind Kind) i64:
	m.place(Obj(proto, kind))

pub fn newArray(mut m Machine, move items Value[]) i64:
	m.place(Obj(proto = m.protos.array, kind = .Array, items))

# an object put in a slot the collector freed, else at the heap's end
fn place(mut m Machine, move o Obj):
	if m.freeObjects.pop() is k:
		m.heap[k] = o
		return k
	m.heap.push(o)
	m.heap.len - 1

# a scope over the object, inside parent
pub fn newScope(mut m Machine, parent i64, kind i64, object i64) i64:
	if m.freeScopes.pop() is k:
		m.scopes[k] = Scope(parent, kind, object)
		return k
	m.scopes.push(Scope(parent, kind, object))
	m.scopes.len - 1

# the property the object itself has
pub fn own(m Machine, id i64, name str) ref Prop?:
	m.heap[id].props.get(name)

# the value of the object's own property, undefined when it has none
pub fn ownValue(m Machine, id i64, name str) Value:
	if m.heap[id].props.get(name) is p: return p.value.copy()
	.Undefined

# a property set on the object itself, flags kept when it has it
pub fn setOwn(mut m Machine, id i64, name str, move v Value):
	if m.heap[id].props.getMut(name) is p:
		p.value = v
		return
	m.heap[id].props[name.copy()] = Prop(value = v)
	m.heap[id].order.push(name.copy())

# a property made with these flags (a built-in's, hidden from for-in)
pub fn define(mut m Machine, id i64, name str, move v Value, flags i64):
	m.setOwn(id, name, v)
	m.heap[id].props[name].flags = flags

pub fn deleteOwn(mut m Machine, id i64, name str) bool:
	p = m.heap[id].props.get(name) ?? return false
	if (p.flags & dontDelete) != 0: return false
	m.heap[id].props.remove(name)
	m.heap[id].order = m.heap[id].order.filter(it != name)
	true

# the object of the chain from id (itself, then its prototypes) that holds the property
pub fn holderOf(m Machine, id i64, name str) i64?:
	o = id
	loop 64:
		if o < 0: return none
		if name in m.heap[o].props: return o
		o = m.heap[o].proto
	none

# a native function object, registered under its name
pub fn nativeFn(mut m Machine, group i64, name str) i64:
	m.natives.push(NativeFn(group, name = name.copy()))
	id = m.newOf(m.protos.function, .Native(m.natives.len - 1))
	id

# the script object of a node, made when first asked for
pub fn objectOfNode(mut m Machine, prog Program, n i64) i64:
	if m.stage.nodes[n].object >= 0: return m.stage.nodes[n].object
	character = m.stage.nodes[n].placed.character
	scene = ref prog.scene
	text = m.stage.fieldOf(scene, n) != none
	button = scene.movie.buttons.get(character) != none
	proto = m.protos.text if text else m.protos.button if button else m.protos.clip
	if prog.classOf(m, character) is ctor:
		if m.prototypeOf(ctor) is p: proto = p
	kind Kind = .Text(n) if text else .Clip(n)
	id = m.newOf(proto, kind)
	m.stage.nodes[n].object = id
	id

# a function's "prototype" object
pub fn prototypeOf(m Machine, f i64) i64?:
	p = try m.heap[f].props.get("prototype")
	if p.value is Obj(id): return id
	none

# the node a value is the clip or text field of
pub fn nodeOf(m Machine, v Value) i64?:
	id = try v.objectId()
	match m.heap[id].kind:
		Clip(n): n if m.stage.nodes[n].alive else none
		Text(n): n if m.stage.nodes[n].alive else none
		_: none

# what an object is, a copy to match on while the heap changes
pub fn kindOf(m Machine, id i64) Kind:
	m.heap[id].kind.copy()

pub fn isArray(m Machine, id i64) bool:
	match m.heap[id].kind:
		Array: true
		_: false

pub fn objectId(v Value) i64?:
	if v is Obj(id): return id
	none

# a line of the log, an error counted
pub fn fault(mut m Machine, text str):
	m.errors += 1
	m.log.push("error: {text}")

pub fn missing(mut m Machine, what str):
	m.unimplemented.add(what, 1)

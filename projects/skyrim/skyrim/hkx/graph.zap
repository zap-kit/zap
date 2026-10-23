# A behavior graph (a behaviors/*.hkx packfile, hkbBehaviorGraph) as the game's animation: a tree
# of generators (state machines, blenders, selectors, clips) whose states change on events and
# whose members are bound to variables. Layouts after the Havok 2010 64-bit classes as HKX2
# (ret2end/HKX2Library, Autogen) lays them out: an hkReferencedObject's members start at 16, an
# hkbBindable's variable bindings at 16, an hkbNode's name at 56 and its own members at 72.
# Events and variables are kept by name, so that a graph that refers to another (an
# hkbBehaviorReferenceGenerator) shares them with it.

bindableBindings = 16
nodeName = 56

# hkbVariableBindingSet: bindings of 40 bytes (the member's path, the variable index at 28, the
# binding type at 33: 0 a variable, 1 a character property)
bindingSetBindings = 16
bindingSize = 40
bindingVariable = 28
bindingType = 33

# hkbBehaviorGraph and its data
graphRoot = 128
graphData = 136
dataVariableInfos = 32
dataInitialValues = 112
dataStrings = 120
variableInfoSize = 6
variableInfoType = 4
valueSetWords = 16
stringsEvents = 16
stringsVariables = 48
stringsProperties = 64

# hkbClipGenerator
clipName = 72
clipTriggers = 80
clipSpeed = 100
clipMode = 114
# hkbBlenderGenerator and its children (a child is an hkbBindable: its weight is bound)
blenderParameter = 76
blenderCyclicMin = 80
blenderCyclicMax = 84
blenderFlags = 90
blenderChildren = 96
childGenerator = 48
childWeight = 64
childBones = 56
# hkbBoneWeightArray: an hkbBindable, then its weights, one for each bone of the skeleton
boneWeightsOf = 48
# hkbManualSelectorGenerator
selectorGenerators = 72
selectorIndex = 88
# hkbModifierGenerator and hkbModifierList
modifierGeneratorModifier = 72
modifierGeneratorChild = 80
modifierListModifiers = 80
# BSSynchronizedClipGenerator, BSiStateTaggingGenerator, BSCyclicBlendTransitionGenerator and
# BSBoneSwitchGenerator and BSOffsetAnimationGenerator (their default) wrap one generator
syncClip = 80
taggedGenerator = 80
referenceName = 72
# hkbStateMachine, its states and their transitions
machineStartState = 104
machineStates = 144
machineWildcards = 160
stateEnterEvents = 64
stateExitEvents = 72
stateTransitions = 80
stateGenerator = 88
stateName = 96
stateId = 104
eventPropertyArrayEvents = 16
eventPropertySize = 16
transitionArrayTransitions = 16
transitionSize = 72
transitionEffect = 32
transitionCondition = 40
transitionEvent = 48
transitionToState = 52
transitionToNested = 60
transitionPriority = 64
effectDuration = 80
conditionExpression = 16
# hkbEvaluateExpressionModifier: an hkbExpressionDataArray of 24-byte (expression, variable index,
# event index)
expressionsOf = 80
expressionArray = 16
expressionSize = 24
expressionVariable = 8
expressionEvent = 12

pub type NodeKind:
	Clip
	Blender
	Selector
	Machine
	Pass   # a generator that plays its one child (a modifier's, a sync's, a tag's, a reference's)
	Other

# a member of a node (or of its child, slot >= 0) bound to a variable
pub type Binding:
	slot i64
	member str
	variable str

# a transition of a state machine: on the event, to the state, after a blend of `blend` seconds
pub type Transition:
	event str
	toState i64
	nested i64   # the state of the state machine inside the state it goes to, -1 for its start
	condition str
	priority i64
	blend f32

pub type State:
	id i64
	name str
	generator i64   # the node it plays, -1 for none
	transitions Transition[]
	enter str[]
	exit str[]

# what an hkbEvaluateExpressionModifier does: the variable (or event) its expression is put in
pub type Assignment:
	variable str
	event str
	expression str

# an event a clip sends at a local time (from its end when `fromEnd`)
pub type Trigger:
	time f32
	event str
	fromEnd bool

# the weight each bone of the skeleton gives a blender child's pose (an hkbBoneWeightArray)
pub type BoneMask:
	weights f32[]

pub type Node:
	kind NodeKind
	name str
	class str = ""
	clip str = ""   # a clip's animation, in lower case, without its folder and extension
	speed f32 = 1.0
	looping bool = true
	triggers Trigger[] = []
	children i64[] = []   # a blender's, a selector's, a pass's
	positions f32[] = []   # a blender child's weight, or its place on the blend parameter
	partial bool[] = []   # whether a blender child moves only some bones (an arm's layer)
	bones BoneMask[] = []   # a blender child's weight of each bone of the skeleton, none for a whole-body child
	bindings Binding[] = []
	parameter f32 = 0.0   # a blender's blend parameter
	parametric bool = false
	cyclic bool = false   # a parametric blend around a circle: the parameter wraps from `high` to `low`
	low f32 = 0.0
	high f32 = 0.0
	selected i64 = 0
	states State[] = []
	wildcards Transition[] = []
	start i64 = 0
	chooser str = ""
	modifiers Assignment[] = []   # the expressions a pass's modifiers evaluate each frame
	reference str = ""   # the graph a pass refers to

# the objects of a packfile by address, with the node each became
type Reading:
	p Packfile
	events str[]
	variables str[]
	properties str[]
	made {i64: i64} = {}
	nodes Node[]

pub type Variable:
	name str
	value f32

# one behavior file's nodes (their children indexes within it), its root and its variables
pub type Behavior:
	nodes Node[]
	root i64
	variables Variable[]

fn stringsAt(p Packfile, at i64):
	a = p.arrayAt(at)
	if not p.fits(a, 8): return []
	(0..a.count).map(p.textAt(a.element(it, 8)).copy())

fn nameAt(names str[], i i64):
	names[i].copy() if i >= 0 and i < names.len else ""

# a clip's animation as the rig names it: "Animations\male\Chair_Idle.hkx" is "chair_idle"
fn clipFileOf(path str):
	parts = path.lower().replace("/", "\\").split("\\")
	parts[len - 1].replace(".hkx", "")

fn triggersOf(r Reading, at i64):
	array = r.p.target(at + clipTriggers)
	if array < 0: return []
	list = r.p.arrayAt(array + triggerArrayTriggers)
	if not r.p.fits(list, triggerSize): return []
	(0..list.count).map(Trigger(time = r.p.d.f32le(list.element(it, triggerSize)),
		event = r.eventNameAt(list.element(it, triggerSize) + triggerEvent),
		fromEnd = r.p.d[list.element(it, triggerSize) + triggerRelativeToEnd] != 0))

fn bindingsOf(r Reading, at i64, slot i64):
	set = r.p.target(at + bindableBindings)
	out = []
	if set < 0: return out
	list = r.p.arrayAt(set + bindingSetBindings)
	if not r.p.fits(list, bindingSize): return out
	for i in 0..list.count:
		b = list.element(i, bindingSize)
		index = i64(r.p.d.i32le(b + bindingVariable))
		names = r.properties if r.p.d[b + bindingType] == 1 else r.variables
		out.push(Binding(slot, member = r.p.textAt(b).copy(), variable = names.nameAt(index)))
	out

# the name of the event property at `at` (the hkbEventProperty's id comes first)
fn eventNameAt(r Reading, at i64):
	r.events.nameAt(r.p.d.i32le(at))

fn eventPropertiesOf(r Reading, at i64):
	array = r.p.target(at)
	if array < 0: return []
	list = r.p.arrayAt(array + eventPropertyArrayEvents)
	if not r.p.fits(list, eventPropertySize): return []
	(0..list.count).map(r.eventNameAt(list.element(it, eventPropertySize)))

fn transitionsOf(r Reading, at i64):
	array = r.p.target(at)
	if array < 0: return []
	list = r.p.arrayAt(array + transitionArrayTransitions)
	if not r.p.fits(list, transitionSize): return []
	out = []
	for i in 0..list.count:
		t = list.element(i, transitionSize)
		effect = r.p.target(t + transitionEffect)
		condition = r.p.target(t + transitionCondition)
		duration = 0.0
		if effect >= 0 and r.p.classAt(effect) == "hkbBlendingTransitionEffect":
			duration = r.p.d.f32le(effect + effectDuration)
		out.push(
			Transition(
				event = r.events.nameAt(r.p.d.i32le(t + transitionEvent)),
				toState = r.p.d.i32le(t + transitionToState),
				nested = r.p.d.i32le(t + transitionToNested),
				condition = r.p.textAt(condition + conditionExpression).copy() if condition >= 0 else "",
				priority = r.p.d.i16le(t + transitionPriority),
				blend = duration
			)
		)
	out

fn statesOf(mut r Reading, at i64):
	list = r.p.arrayAt(at + machineStates)
	if not r.p.fits(list, 8): return []
	out = []
	for i in 0..list.count:
		s = r.p.target(list.element(i, 8))
		if s < 0: continue
		generator = r.p.target(s + stateGenerator)
		out.push(
			State(
				id = r.p.d.i32le(s + stateId),
				name = r.p.textAt(s + stateName).copy(),
				generator = r.nodeAt(generator),
				transitions = r.transitionsOf(s + stateTransitions),
				enter = r.eventPropertiesOf(s + stateEnterEvents),
				exit = r.eventPropertiesOf(s + stateExitEvents)
			)
		)
	out

# the expressions of the modifier at `at` (a list's: its members' too)
fn assignmentsOf(r Reading, at i64) Assignment[]:
	if at < 0: return []
	out = []
	match r.p.classAt(at):
		"hkbModifierList":
			list = r.p.arrayAt(at + modifierListModifiers)
			if r.p.fits(list, 8):
				for i in 0..list.count:
					out.extend(r.assignmentsOf(r.p.target(list.element(i, 8))))
		"hkbEvaluateExpressionModifier":
			array = r.p.target(at + expressionsOf)
			if array >= 0:
				list = r.p.arrayAt(array + expressionArray)
				if r.p.fits(list, expressionSize):
					for i in 0..list.count:
						e = list.element(i, expressionSize)
						out.push(
							Assignment(
								variable = r.variables.nameAt(r.p.d.i32le(e + expressionVariable)),
								event = r.events.nameAt(r.p.d.i32le(e + expressionEvent)),
								expression = r.p.textAt(e).copy()
							)
						)
		_: pass
	out

# the bone weights of the hkbBoneWeightArray at `at`, none for no array
fn boneWeightsAt(r Reading, at i64):
	if at < 0: return BoneMask(weights = [])
	list = r.p.arrayAt(at + boneWeightsOf)
	if not r.p.fits(list, 4): return BoneMask(weights = [])
	BoneMask(weights = (0..list.count).map(r.p.d.f32le(list.element(it, 4))))

fn blenderOf(mut r Reading, at i64, mut node Node):
	node.kind = .Blender
	node.parameter = r.p.d.f32le(at + blenderParameter)
	flags = r.p.d.u16le(at + blenderFlags)
	node.parametric = (flags & 16) != 0
	node.cyclic = (flags & 32) != 0
	node.low = r.p.d.f32le(at + blenderCyclicMin)
	node.high = r.p.d.f32le(at + blenderCyclicMax)
	list = r.p.arrayAt(at + blenderChildren)
	if not r.p.fits(list, 8): return
	for i in 0..list.count:
		c = r.p.target(list.element(i, 8))
		if c < 0: continue
		node.children.push(r.nodeAt(r.p.target(c + childGenerator)))
		node.positions.push(r.p.d.f32le(c + childWeight))
		mask = r.p.target(c + childBones)
		node.bones.push(r.boneWeightsAt(mask))
		node.partial.push(not node.bones[len - 1].weights.isEmpty)
		node.bindings.extend(r.bindingsOf(c, node.children.len - 1))

fn passOf(mut r Reading, at i64, mut node Node):
	node.kind = .Pass
	match r.p.classAt(at):
		"hkbModifierGenerator":
			node.modifiers = r.assignmentsOf(r.p.target(at + modifierGeneratorModifier))
			node.children = [r.nodeAt(r.p.target(at + modifierGeneratorChild))]
		"BSSynchronizedClipGenerator": node.children = [r.nodeAt(r.p.target(at + syncClip))]
		"BSiStateTaggingGenerator", "BSCyclicBlendTransitionGenerator", "BSBoneSwitchGenerator", "BSOffsetAnimationGenerator":
			node.children = [r.nodeAt(r.p.target(at + taggedGenerator))]
		_: node.reference = r.p.textAt(at + referenceName).copy()

# the node of the generator at `at`, made once: -1 for none
fn nodeAt(mut r Reading, at i64) i64:
	if at < 0: return -1
	if r.made.get(at) is known: return known
	node = Node(kind = .Other, name = r.p.textAt(at + nodeName).copy(), class = r.p.classAt(at))
	index = r.nodes.len
	r.made[at] = index
	r.nodes.push(Node(kind = .Other, name = node.name.copy()))
	match r.p.classAt(at):
		"hkbClipGenerator":
			node.kind = .Clip
			node.clip = clipFileOf(r.p.textAt(at + clipName))
			node.speed = r.p.d.f32le(at + clipSpeed)
			node.triggers = r.triggersOf(at)
			node.looping = r.p.d[at + clipMode] == 1
		"hkbBlenderGenerator", "hkbPoseMatchingGenerator": r.blenderOf(at, node)
		"hkbManualSelectorGenerator":
			node.kind = .Selector
			list = r.p.arrayAt(at + selectorGenerators)
			if r.p.fits(list, 8):
				node.children = (0..list.count).map(r.nodeAt(r.p.target(list.element(it, 8))))
			node.selected = r.p.d[at + selectorIndex]
		"hkbStateMachine":
			node.kind = .Machine
			node.start = r.p.d.i32le(at + machineStartState)
			node.chooser = r.p.classAt(r.p.target(at + 96))
			node.states = r.statesOf(at)
			node.wildcards = r.transitionsOf(at + machineWildcards)
		"hkbModifierGenerator", "BSSynchronizedClipGenerator", "BSiStateTaggingGenerator", "BSCyclicBlendTransitionGenerator", "BSBoneSwitchGenerator", "BSOffsetAnimationGenerator", "hkbBehaviorReferenceGenerator":
			r.passOf(at, node)
		_: pass
	node.bindings.extend(r.bindingsOf(at, -1))
	r.nodes[index] = node
	index

# the variables' names and initial values: an hkbVariableValueSet's words, one for each variable
# of a word type (bool, ints and real; not the pointers, vectors and quaternions)
fn variablesOf(p Packfile, data i64, names str[]):
	infos = p.arrayAt(data + dataVariableInfos)
	set = p.target(data + dataInitialValues)
	if set < 0 or not p.fits(infos, variableInfoSize):
		return names.map(Variable(name = .copy(), value = 0.0))
	words = p.arrayAt(set + valueSetWords)
	out = []
	word = 0
	for i, name in names:
		kind = i64(p.d[infos.element(i, variableInfoSize) + variableInfoType]) if i < infos.count
			else 4
		value = 0.0
		if kind <= 4 and word < words.count:
			at = words.element(word, 4)
			value = p.d.f32le(at) if kind == 4 else f32(p.d.i32le(at))
		if kind <= 4: word += 1
		out.push(Variable(name = name.copy(), value))
	out

# A behavior file's graph, or why it cannot be read.
pub fn readBehavior(bytes u8[]) Behavior ? str:
	p = try openPackfile(bytes)
	graph = -1
	for o in p.objects:
		if o.className == "hkbBehaviorGraph": graph = o.at
	if graph < 0: return "no hkbBehaviorGraph in the file"
	data = p.target(graph + graphData)
	strings = p.target(data + dataStrings)
	if data < 0 or strings < 0: return "the graph has no data"
	variables = p.stringsAt(strings + stringsVariables)
	r = Reading(
		p,
		events = p.stringsAt(strings + stringsEvents),
		variables = variables.copy(),
		properties = p.stringsAt(strings + stringsProperties),
		nodes = []
	)
	root = r.nodeAt(r.p.target(graph + graphRoot))
	Behavior(nodes = r.nodes.copy(), root, variables = r.p.variablesOf(data, variables))

# Timelines (SWF specification v19, chapter 3): the main one and each DefineSprite's, as frames
# of control tags: PlaceObject 1 to 3 (a depth, the character, its matrix, color transform,
# ratio, instance name, clip depth, blend mode, visibility, filters and clip actions), RemoveObject 1 and 2, FrameLabel and the ActionScript of DoAction kept as bytes.
# The display list at a frame is the frames' commands applied in order. DefineButton 1 and 2 are
# here too: their records are placements per state.

# a PlaceObject: what to place at a depth, or what to change of the object there
pub type Placement:
	depth i64
	moves bool   # changes the object at the depth instead of placing a new one
	character i64 = -1   # -1: the one at the depth stays
	matrix Affine? = none
	color ColorTransform? = none
	ratio i64 = -1
	name str = ""
	clipDepth i64 = 0   # a mask over the depths up to this one, 0 none
	className str = ""
	blend i64 = 0
	visible i64 = -1   # 0 hidden, 1 shown, -1 not said
	filters Filter[]? = none   # the filters the placement sets, none when it says nothing of them
	clipActions ClipAction[] = []

# One of a placed object's filters (SWF's FILTER): the drop shadow (kind 0), blur (1) and glow (2)
# are kept, the bevel and the color and convolution ones read over. The blur is in pixels, the angle
# in radians.
pub type Filter:
	kind i64
	color Vec4 = Vec4(0.0, 0.0, 0.0, 1.0)
	blurX f32 = 0.0
	blurY f32 = 0.0
	angle f32 = 0.0
	distance f32 = 0.0
	strength f32 = 1.0
	inner bool = false
	knockout bool = false
	passes i64 = 1

# onClipEvent's handlers of a placed sprite: the events (ClipEventFlags: load 1, enterFrame 2,
# unload 4 ... construct 0x40000) and the code run on them
pub type ClipAction:
	events i64
	key i64   # the key of a keyPress event
	code u8[]

# a frame's change of the display list
pub type Command:
	Place(p Placement)
	Remove(depth i64)

# a frame's changes, its label and its actions
pub type Frame:
	commands Command[] = []
	label str = ""
	actions u8[,] = []   # DoAction's bytecode, ActionScript 2, not run

# the frames of the main timeline or of a sprite
pub type Timeline:
	frameCount i64 = 1
	frames Frame[] = []

# DefineSprite: a timeline of its own
pub type Sprite:
	id i64
	timeline Timeline

# an object of a display list: what a frame shows at a depth
pub type Placed:
	depth i64
	character i64
	matrix Affine
	color ColorTransform
	ratio i64
	name str
	clipDepth i64
	blend i64
	visible bool
	placedAt i64   # the frame of its timeline that placed it
	filters Filter[] = []

# a character a button shows in some of its states
pub type ButtonRecord:
	states i64   # 1 up, 2 over, 4 down, 8 hit test
	character i64
	depth i64
	matrix Affine
	color ColorTransform

# a button's code and the state changes it runs on (BUTTONCONDACTION's conditions: 1 rolled over,
# 2 rolled out, 4 pressed, 8 released, 0x40 released outside; DefineButton's code runs on 8)
pub type ButtonAction:
	conditions i64
	code u8[]

# DefineButton or DefineButton2
pub type Button:
	id i64
	records ButtonRecord[]
	actions ButtonAction[] = []

# PlaceObject (tag 4), PlaceObject2 (26) or PlaceObject3 (70), the version 1 to 3
pub fn readPlace(mut r TagReader, version i64) Placement:
	if version == 1:
		character = r.u16()
		p = Placement(depth = r.u16(), moves = false, character)
		p.matrix = r.matrix()
		if r.remaining() > 0: p.color = r.colorTransform(false)
		return p
	flags = r.u8()
	flags2 = r.u8() if version == 3 else 0
	p = Placement(depth = r.u16(), moves = (flags & 1) != 0)
	if (flags2 & 8) != 0 or ((flags2 & 16) != 0 and (flags & 2) != 0): p.className = r.text()
	if (flags & 2) != 0: p.character = r.u16()
	if (flags & 4) != 0: p.matrix = r.matrix()
	if (flags & 8) != 0: p.color = r.colorTransform(true)
	if (flags & 16) != 0: p.ratio = r.u16()
	if (flags & 32) != 0: p.name = r.text()
	if (flags & 64) != 0: p.clipDepth = r.u16()
	if (flags2 & 1) != 0: p.filters = r.readFilters()
	if (flags2 & 2) != 0: p.blend = r.u8()
	if (flags2 & 4) != 0: r.u8()   # cache as bitmap
	if (flags2 & 32) != 0: p.visible = r.u8()
	if (flags2 & 64) != 0: r.rgba()   # the opaque background
	if (flags & 128) != 0: p.clipActions = r.readClipActions()
	p

# CLIPACTIONS, the SWF 6 form (32-bit event flags): records up to a zero flag
fn readClipActions(mut r TagReader):
	r.u16()
	r.u32()   # every record's events together
	out = []
	while r.remaining() >= 4:
		events = r.u32()
		if events == 0: break
		size = r.u32()
		key = 0
		if (events & 0x2_0000) != 0:
			key = r.u8()
			size -= 1
		out.push(ClipAction(events, key, code = r.bytes(size)))
	out

# a FILTERLIST: the drop shadows, blurs and glows kept, each other filter passed over by its size
fn readFilters(mut r TagReader):
	out = []
	loop r.u8():
		kind = r.u8()
		if kind == 0:
			f = Filter(
				kind,
				color = r.rgba(),
				blurX = r.fixed(),
				blurY = r.fixed(),
				angle = r.fixed(),
				distance = r.fixed(), strength = r.fixed8())
			f.setFlags(r.u8())
			out.push(f)
		elif kind == 1:
			f = Filter(kind, blurX = r.fixed(), blurY = r.fixed())
			f.passes = r.u8() >> 3
			out.push(f)
		elif kind == 2:
			f = Filter(kind, color = r.rgba(), blurX = r.fixed(), blurY = r.fixed(),
				strength = r.fixed8())
			f.setFlags(r.u8())
			out.push(f)
		elif kind == 3: r.bytes(27)
		elif kind == 4 or kind == 7: r.bytes(r.u8() * 5 + 19)
		elif kind == 5:
			x = r.u8()
			y = r.u8()
			r.bytes(8 + 4 * x * y + 5)
		elif kind == 6: r.bytes(80)
		else: r.short = true
	out

# a filter's flags byte: inner shadow or glow, knockout, composite source and 5 bits of passes
fn setFlags(mut f Filter, flags i64):
	f.inner = (flags & 0x80) != 0
	f.knockout = (flags & 0x40) != 0
	f.passes = flags & 31

# RemoveObject (tag 5, a character and a depth) or RemoveObject2 (28, a depth)
pub fn readRemove(mut r TagReader, version i64) i64:
	if version == 1: r.u16()
	r.u16()

# DefineButton (tag 7) or DefineButton2 (34): the records of its states
pub fn readButton(mut r TagReader, version i64) Button:
	b = Button(id = r.u16(), records = [])
	offset = 0
	if version == 2:
		r.u8()   # track as menu
		offset = r.u16()
	while not r.short:
		flags = r.u8()
		if flags == 0: break
		character = r.u16()
		depth = r.u16()
		matrix = r.matrix()
		color = r.colorTransform(true) if version == 2 else ColorTransform()
		if version == 2 and (flags & 16) != 0: r.readFilters()
		if version == 2 and (flags & 32) != 0: r.u8()
		b.records.push(ButtonRecord(states = flags & 15, character, depth, matrix, color))
	if version == 1:
		b.actions.push(ButtonAction(conditions = 8, code = r.rest()))
	elif offset != 0:
		while r.remaining() >= 4:
			size = r.u16()
			conditions = r.u16()
			code = r.bytes(size - 4) if size >= 4 else r.rest()
			b.actions.push(ButtonAction(conditions, code))
			if size == 0: break
	b

# the objects a timeline shows at a frame (0 the first), by depth
pub fn displayList(t Timeline, frame i64) Placed[]:
	list Placed[] = []
	for k in 0..(frame + 1).min(t.frames.len):
		for c in t.frames[k].commands:
			match c:
				Place(p):
					at = list.findIndex(.depth == p.depth)
					if at is i and p.moves: list[i].moveTo(p)
					elif p.character >= 0:
						if at is i: list.remove(i)
						list.push(p.placedOf(k))
				Remove(depth): list = list.filter(.depth != depth)
	list.sortedBy(.depth)

# what a PlaceObject that is not a move places, at the frame `frame`
pub fn placedOf(p Placement, frame i64) Placed:
	Placed(depth = p.depth, character = p.character, matrix = p.matrix ?? Affine(),
		color = p.color ?? ColorTransform(), ratio = p.ratio, name = p.name.copy(),
		clipDepth = p.clipDepth, blend = p.blend, visible = p.visible != 0, placedAt = frame,
		filters = (p.filters ?? []).copy())

# what a PlaceObject that moves the object at its depth changes of it
pub fn moveTo(mut placed Placed, p Placement):
	if p.character >= 0: placed.character = p.character
	if p.matrix is m: placed.matrix = m
	if p.color is c: placed.color = c
	if p.ratio >= 0: placed.ratio = p.ratio
	if not p.name.isEmpty: placed.name = p.name.copy()
	if p.clipDepth > 0: placed.clipDepth = p.clipDepth
	if p.visible >= 0: placed.visible = p.visible != 0
	if p.filters is list: placed.filters = list.copy()

# the frame with this label, none when no frame has it; AVM1 matches labels in any case
# (Ruffle's frame_label_to_number: "ForceFade" finds "forceFade")
pub fn frameOfLabel(t Timeline, label str) i64?:
	wanted = label.lower()
	for k, f in t.frames:
		if not f.label.isEmpty and f.label.lower() == wanted: return k
	none

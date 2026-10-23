# ACT, Ragnarok Online's animations: "AC", a version, the actions (a body has one per facing of
# each pose: standing 0-7, walking 8-15, ...), each a list of frames; a frame is layers (an
# image of the SPR placed at an offset from the feet, mirrored, tinted, scaled, rotated) and,
# from 0x203, anchor points where a head or headgear attaches. Also IMF, the table of whether a
# player's head is drawn behind the body in a frame.

pub type Layer:
	x i64
	y i64
	image i64   # index in its SPR bank, -1 for none
	mirrored bool
	r i64   # the tint
	g i64
	b i64
	a i64
	xScale f32
	yScale f32
	rotation i64   # degrees
	bank i64   # 0 palette images, 1 RGBA images

pub type Anchor:
	x i64
	y i64

pub type Frame:
	layers Layer[]
	anchors Anchor[]

pub type Act:
	actions Frame[,]
	delays f32[]   # per action: milliseconds a frame is shown

# a layer and an anchor as the file holds them (a layer's later fields follow by version)
type LayerRecord:
	x i32
	y i32
	image i32
	flags u32
	tint u8[4]   # r, g, b, a
	xScale f32

type AnchorRecord:
	unused u32
	x i32
	y i32
	more u32

# the actions of an ACT file, or why it cannot be read
pub fn parseAct(d u8[]) Act ? str:
	if d.len < 30 or not d.startsWith("AC"): return "not an ACT file"
	r = Reader(d, at = 2)
	version = r.u16()
	count = i64(r.u16())
	r.skip(10)
	actions = []
	loop count:
		frames = r.recordCount(36)
		list = []
		loop frames:
			list.push(r.readFrame(version))
			if r.short: return "an ACT frame runs past the end"
		actions.push(list)
	# the frames' sounds (names), then from 0x202 each action's interval in 25 ms ticks
	delays f32[] = fill(count, 100.0)
	if version >= 0x201:
		r.skip(i64(r.u32()) * 40)
		if version >= 0x202:
			for k in 0..count:
				interval = r.f32()
				if not r.short and interval > 0.0:
					delays[k] = interval * 25.0
	Act(actions, delays)

fn readFrame(mut r Reader, version i64):
	r.skip(32)   # two rectangles the client no longer uses
	n = r.recordCount(24)
	layers = []
	loop n:
		l = LayerRecord.fromBytes(r)
		yScale = r.f32() if version >= 0x204 else l.xScale
		rotation = r.i32()
		bank = r.i32()
		if version >= 0x205:
			r.skip(8)   # the image's size
		layers.push(
			Layer(
				x = l.x,
				y = l.y,
				image = l.image,
				mirrored = (l.flags & 1) != 0,
				r = l.tint[0],
				g = l.tint[1],
				b = l.tint[2],
				a = l.tint[3],
				xScale = l.xScale,
				yScale,
				rotation,
				bank
			)
		)
		if r.short: break
	anchors = []
	if version >= 0x200:
		r.skip(4)   # the frame's sound
		if version >= 0x203:
			k = i64(r.u32())
			loop k:
				a = AnchorRecord.fromBytes(r)
				anchors.push(Anchor(x = a.x, y = a.y))
				if r.short: break
	Frame(layers, anchors)

# the frames of an action, none past the end
pub fn framesOf(a Act, action i64) ref Frame[]?:
	if action < 0 or action >= a.actions.len: return none
	a.actions[action]

pub fn frameCount(a Act, action i64) i64:
	match a.framesOf(action):
		frames: frames.len
		none: 0

# IMF: per layer, action and frame, a priority (layer 1 is the head; 1 draws it behind the body)
pub type Imf:
	priorities i64[,,]

pub fn parseImf(d u8[]) Imf ? str:
	r = Reader(d, at = 8)   # a float version, a checksum
	layers = r.recordCount(4)
	out = []
	loop (layers + 1):
		actions = r.recordCount(4)
		perAction = []
		loop actions:
			frames = r.recordCount(12)
			perFrame = []
			loop frames:
				perFrame.push(i64(r.i32()))
				r.skip(8)
			perAction.push(perFrame)
			if r.short: return "an IMF table runs past the end"
		out.push(perAction)
	Imf(priorities = out)

pub fn imfPriority(m Imf, layer i64, action i64, frame i64) i64:
	if layer < 0 or layer >= m.priorities.len: return -1
	actions = m.priorities[layer]
	if action < 0 or action >= actions.len or frame < 0 or frame >= actions[action].len: return -1
	actions[action][frame]

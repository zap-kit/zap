# The lip data of a voice line (a .lip file, the FUZ's first part), as the Creation Kit's
# LipSynchAnim writes it compressed. No public description of the format exists; this one is read
# from the files of the install and borne out by them (tests.zap): a u32 version (1), the u32 size
# of the file once expanded, a u32 (13), then the rest packed so that a 0 byte and a u16 n stand
# for n zero bytes and any other byte for itself. Expanded, the rest is a u32 count of frames, an
# i32 (a small negative number, its meaning unknown), a u32 count of phonemes (16), then each frame
# as 33 f32 weights: the 16 phonemes then the 17 modifiers, in the order of the head's TRI morphs
# (the phonemes checked against the lines' words: "We weep." is W Eee W Eee BMP). The frames are
# taken as 30 a second, which the lines' lengths bear out within the frames a line runs on after
# its sound.

# the phonemes, in the order of each frame's first weights (the head TRI's morph names)
pub lipPhonemes = [
	"Aah", "BigAah", "BMP", "ChJSh", "DST", "Eee", "Eh", "FV", "I", "K", "N", "Oh", "OohQ", "R",
	"Th", "W"
]

# the modifiers, in the order of each frame's weights after the phonemes
pub lipModifiers = [
	"BlinkLeft", "BlinkRight", "BrowDownLeft", "BrowDownRight", "BrowInLeft", "BrowInRight",
	"BrowUpLeft", "BrowUpRight", "LookDown", "LookLeft", "LookRight", "LookUp", "SquintLeft",
	"SquintRight", "HeadPitch", "HeadRoll", "HeadYaw"
]

pub lipFramesPerSecond = 30.0

# one frame: when it falls and each target's weight, the phonemes' then the modifiers'
pub type LipFrame:
	time f32
	weights f32[]

pub type Lip:
	lead i64   # the header's second number, kept as read
	frames LipFrame[]

# the packed bytes expanded: a 0 and a u16 n are n zero bytes
fn expandLip(d u8[], from i64):
	out = []
	at = from
	while at < d.len:
		if d[at] != 0:
			out.push(d[at])
			at += 1
			continue
		if at + 3 > d.len: break
		loop i64(d.u16le(at + 1)):
			out.push(0)
		at += 3
	out

# The frames of the lip data `d`, or why it does not read as one.
pub fn readLip(d u8[]) Lip ? str:
	if d.len < 12 or d.u32le(0) != 1: return "no lip data of version 1"
	body = expandLip(d, 12)
	if i64(d.u32le(4)) != body.len + 16:
		return "the lip data expands to {body.len + 16} bytes, not {d.u32le(4)}"
	targets = lipPhonemes.len + lipModifiers.len
	count = i64(body.u32le(0))
	if body.len < 12 + count * targets * 4:
		return "the lip data holds fewer than its {count} frames"
	frames = []
	for k in 0..count:
		at = 12 + k * targets * 4
		weights = []
		for t in 0..targets:
			weights.push(body.f32le(at + t * 4))
		frames.push(LipFrame(time = f32(k) / f32(lipFramesPerSecond), weights))
	Lip(lead = body.i32le(4), frames)

# The weights of the targets (lipTarget's order) `t` seconds into the line: linear between the
# two frames around it, the last held after the end, all 0 for a track with no frames.
pub fn lipWeights(lip Lip, t f32) f32[]:
	if lip.frames.isEmpty:
		rest f32[] = []
		loop lipPhonemes.len + lipModifiers.len:
			rest.push(0.0)
		return rest
	at = (t * f32(lipFramesPerSecond)).max(0.0)
	k = i64(at.floor()).min(lip.frames.len - 1)
	next = (k + 1).min(lip.frames.len - 1)
	share = (at - f32(k)).clamp(0.0, 1.0)
	a = lip.frames[k].weights
	b = lip.frames[next].weights
	(0..a.len).map(a[it].lerp(b[it], share))

# the name of the target at this place of a frame's weights
pub fn lipTarget(k i64) str:
	lipPhonemes[k] if k < lipPhonemes.len else lipModifiers[k - lipPhonemes.len]

# the frame's strongest phoneme, none when every phoneme is at rest
pub fn strongestPhoneme(f LipFrame) i64?:
	best = 0
	for k in 1..lipPhonemes.len:
		if f.weights[k] > f.weights[best]: best = k
	best if f.weights[best] > 0.0 else none

test "packed lip bytes expand their zero runs":
	packed u8[] = [1, 0, 3, 0, 252, 0, 1, 0, 9]
	expect expandLip(packed, 0) == [1, 0, 0, 0, 252, 0, 9]

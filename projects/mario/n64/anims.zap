# Mario's animations, a bank of their own in the cartridge: a count, then each animation's offset
# and size. An animation is a header (its flags, its frames, how many parts it moves) and two
# arrays its header points to (offsets from the header): an index of channels, each a count and
# an offset into the values, and the values, signed 16-bit. The channels are the root's
# translation (x, y, z), then each part's rotation (x, y, z), in game angle units (0x10000 a turn).

pub type Animation:
	flags i64
	startFrame i64
	loopStart i64
	loopEnd i64
	parts i64
	index i64[]   # per channel: count, offset
	values i64[]

# where the bank starts in the US cartridge
marioAnims = 0x4E_C000

pub animNoLoop = 0x01
pub animBackward = 0x02
pub animFrozen = 0x04
pub animOnlyY = 0x08
pub animOnlyXz = 0x10
pub animNoTranslation = 0x40

# the number of animations in the bank
pub fn animationCount(rom Rom) i64:
	rom.bytes.u32be(marioAnims)

# animation `id` of the bank
pub fn readAnimation(rom Rom, id i64) Animation:
	if id < 0 or id >= rom.animationCount():
		fail("no Mario animation {id}")
	b = rom.bytes
	h = marioAnims + b.u32be(marioAnims + 8 + id * 8)
	parts = i64(b.i16be(h + 0x0A))
	indexAt = h + b.u32be(h + 0x10)
	valuesAt = h + b.u32be(h + 0x0C)
	valuesEnd = h + b.u32be(h + 0x14)
	index = (0..(parts + 1) * 6).map(i64(b.u16be(indexAt + it * 2)))
	values = []
	at = valuesAt
	while at + 2 <= valuesEnd:
		values.push(i64(b.i16be(at)))
		at += 2
	Animation(
		flags = b.i16be(h),
		startFrame = b.i16be(h + 4),
		loopStart = b.i16be(h + 6),
		loopEnd = b.i16be(h + 8),
		parts,
		index,
		values)

# Animation `index` of an object's list at `list` (segmented addresses), for a rig of `parts`
# animated parts: its header as Mario's, its arrays pointed to by segmented addresses. none
# when the list does not hold it.
pub fn readObjectAnimation(s Segments, list i64, index i64, parts i64) Animation?:
	if not s.holds(list + index * 4, 4): return none
	h = s.u32At(list + index * 4)
	if not s.holds(h, 0x18): return none
	indexAt = s.u32At(h + 0x10)
	valuesAt = s.u32At(h + 0x0C)
	channels = (parts + 1) * 3
	if not s.holds(indexAt, channels * 4): return none
	idx = []
	count = 0
	for k in 0..channels * 2:
		idx.push(s.u16At(indexAt + k * 2))
	for c in 0..channels:
		count = count.max(idx[2 * c] + idx[2 * c + 1])
	values = []
	for k in 0..count:
		if not s.holds(valuesAt + k * 2, 2): break
		values.push(s.s16At(valuesAt + k * 2))
	Animation(
		flags = s.s16At(h),
		startFrame = s.s16At(h + 4),
		loopStart = s.s16At(h + 6),
		loopEnd = s.s16At(h + 8),
		parts,
		index = idx,
		values
	)

# the frame an animation shows `ticks` frames after it started at `first`: on one a frame,
# around its loop, or held at its end
pub fn frameAfter(a Animation, first i64, ticks i64) i64:
	frame = first + ticks
	if frame < a.loopEnd: return frame
	if (a.flags & animNoLoop) != 0 or a.loopEnd <= a.loopStart: return a.loopEnd - 1
	a.loopStart + (frame - a.loopStart) % (a.loopEnd - a.loopStart)

# channel c's value at a frame (its last value past its end)
pub fn channelAt(a Animation, c i64, frame i64) i64:
	if 2 * c + 1 >= a.index.len: return 0
	count = a.index[2 * c]
	offset = a.index[2 * c + 1]
	i = offset + (frame if frame < count else count - 1).max(0)
	a.values[i] if i < a.values.len else 0

# The matrices of a rig's nodes (in the model's space) at a frame of an animation, as the game
# draws them: the first animated part takes the root translation, every animated part takes its
# three rotations, in the order the parts are drawn.
pub fn pose(rig RigNode[], a Animation, frame i64) Mat4[]:
	out Mat4[] = []
	channel = 0
	first = true
	for node in rig:
		local = node.local
		if node.animated:
			t = node.offset
			if first:
				if (a.flags & animOnlyY) != 0:
					t.y += f32(a.channelAt(1, frame))
				elif (a.flags & animOnlyXz) != 0:
					t.x += f32(a.channelAt(0, frame))
					t.z += f32(a.channelAt(2, frame))
				elif (a.flags & animNoTranslation) == 0:
					t.x += f32(a.channelAt(0, frame))
					t.y += f32(a.channelAt(1, frame))
					t.z += f32(a.channelAt(2, frame))
				channel = 3
				first = false
			r = Vec3(
				f32(a.channelAt(channel, frame)),
				f32(a.channelAt(channel + 1, frame)),
				f32(a.channelAt(channel + 2, frame))
			)
			channel += 3
			local = t.rotateXyzTranslate(r)
		out.push(out[node.parent] @ local if node.parent >= 0 else local)
	out

# A compute stage: each invocation reads a value of a storage buffer, the lanes that run together
# add theirs, the first lane of each keeps the sum in its group's memory, and once the group's
# invocations meet, its first one adds those sums and writes the group's total.

pub type Sums:
	values f32[]
	totals f32[]
	count i32

# the sums of the group's lanes (64 invocations, one lane at least each)
mut partial f32[64]

pub fn sum(mut p Sums):
	i = globalId.x
	v = p.values[i] if i < p.count else 0.0
	s = v.laneSum()
	kept = (v == v).laneAll() or (v != v).laneAny()   # always: a NaN is not itself
	if lane == 0 and kept:
		partial[localIndex / laneCount] = s
	barrier()
	if localIndex == 0:
		total = 0.0
		for k in 0..(64 + laneCount - 1) / laneCount:
			total += partial[k]
		p.totals[groupId.x] = total

pub type Halves:
	words u32[]
	values f32[]

# each word's two f16s as f32s, by their bits, gathered in a local array that starts as zeros
pub fn halves(mut p Halves):
	i = globalId.x
	pair f32[2]
	for k in 0..2:
		h = (p.words[i] >> u32(16 * k)) & 0xFFFF
		if (h & 0x7C00) != 0:
			pair[k] = f32.fromBits(
				(h & 0x8000) << 16 | ((h >> 10 & 31) + 112) << 23 | (h & 1023) << 13
			)
	p.values[2 * i] = pair[0]
	p.values[2 * i + 1] = pair[1] + f32.fromBits(pair[1].toBits())

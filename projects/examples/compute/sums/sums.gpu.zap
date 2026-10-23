# A kernel that adds a list of numbers by groups of 64: each invocation reads one, the lanes that
# run together add theirs, the first lane of each keeps the sum in the group's memory, and once the
# group's invocations meet, its first one adds those sums and writes the group's total.

pub type Sums:
	values f32[]
	totals f32[]
	count i32

# the sums of the group's lanes (64 invocations: a lane at least each)
mut partial f32[64]

pub fn sum(mut p Sums):
	i = globalId.x
	v = p.values[i] if i < p.count else 0.0
	s = v.laneSum()
	if lane == 0:
		partial[localIndex / laneCount] = s
	barrier()
	if localIndex == 0:
		total = 0.0
		for k in 0..(64 + laneCount - 1) / laneCount:
			total += partial[k]
		p.totals[groupId.x] = total

# What a group of 64 invocations computes together (a row's kernels): the sum and the largest of
# a number each holds, every invocation given the result.

# the sums of the group's lanes
mut sums f32[64]

# the sum of v over the group's invocations, its lanes' sums added in order
fn groupTotal(v f32) f32:
	s = v.laneSum()
	if lane == 0:
		sums[localIndex / laneCount] = s
	barrier()
	total = 0.0
	for q in 0..(64 + laneCount - 1) / laneCount:
		total += sums[q]
	barrier()   # every invocation has read the sums before they are written again
	total

# the largest v of the group's invocations
fn groupMax(v f32) f32:
	s = v.laneMax()
	if lane == 0:
		sums[localIndex / laneCount] = s
	barrier()
	most = sums[0]
	for q in 1..(64 + laneCount - 1) / laneCount:
		most = most.max(sums[q])
	barrier()
	most

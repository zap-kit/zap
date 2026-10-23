# A program's parameter block as the RHI keeps it (32-bit words): a value written says whether
# it changed a word, so a block set again to what it holds is not copied for the GPU again.

import rhi.core

test "a block set to what it holds changes nothing":
	words = fill(4, u32(0))
	first = core.writeParams(words, [1, 2, 3, 4])
	again = core.writeParams(words, [1, 2, 3, 4])
	other = core.writeParams(words, [1, 2, 3, 5])
	print("{first} {again} {other}")
	prints """
		true false true
		"""

test "the counts of a frame's draws on one line":
	s = core.DrawStats(
		draws = 3,
		pipelineBinds = 1,
		pipelinesSkipped = 2,
		vertexBinds = 2,
		vertexSkipped = 1,
		descriptorBinds = 2,
		descriptorsSkipped = 1,
		paramUploads = 1,
		paramsSkipped = 2, bytesUploaded = 64)
	print(s.describeStats())
	prints """
		draws 3, pipelines 1/2, vertices 2/1, indices 0/0, descriptors 2/1, parameters 1/2 (64 bytes)
		"""

test "texture arrays: a list set to what it holds changes nothing, a texture it holds makes it stale":
	l = core.newTextureLists([core.TextureArraySlot(binding = 0, kind = core.samplerKind2D, count = 0), core.TextureArraySlot(
		binding = 1,
		kind = core.samplerKindArray,
		count = 4)])
	first = l.setTextureLists([[3, 5, 7], []])
	again = l.setTextureLists([[3, 5, 7], []])
	print("{first} {again} {l.version}")
	l.touchTexture(9)
	print("{l.setTextureLists([[3, 5, 7]])} {l.version}")
	l.touchTexture(5)
	print("{l.version}")
	before = l.tableRoom(0)
	l.setTextureLists([zeros(65), [1]])
	print("{before} {l.tableRoom(0)} {l.tableRoom(1)}")
	prints """
		true false 1
		false 1
		2
		64 128 4
		"""

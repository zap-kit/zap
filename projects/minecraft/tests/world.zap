# Minecraft's world without a window: its making, its meshes, the ray that aims, the body that walks.

import graphics.shaders
import world

test "the same seed makes the same chunks, with ground, sea and trees":
	print(world.generateChunk(3, -2, 7) == world.generateChunk(3, -2, 7))
	kinds = zeros(world.blockKinds)
	for cz in 0..4:
		for cx in 0..4:
			for b in world.generateChunk(cx, cz, 7):
				kinds[i64(b)] += 1
	print(kinds[world.stone] > 0 and kinds[world.grass] > 0 and kinds[world.dirt] > 0)
	print(kinds[world.log] > 0 and kinds[world.leaves] > 0)
	prints """
		true
		true
		true
		"""

test "chunks lie on both sides of zero, each place its own key":
	print("{world.chunkOf(-16)} {world.chunkOf(-1)} {world.chunkOf(0)} {world.chunkOf(15)} {world.chunkOf(16)}")
	print(
		world.chunkKey(-1, 0) != world.chunkKey(0, -1) and
			world.chunkKey(-1, -1) != world.chunkKey(1, 1)
	)
	prints """
		-1 -1 0 0 1
		true
		"""

test "a tree by a chunk's edge spreads its leaves into the chunk beside it":
	w = world.emptyWorld()
	for cz in -1..5:
		for cx in -1..5:
			w.addChunk(cx, cz, world.generateChunk(cx, cz, 7))
	# every trunk on the last column of a chunk has leaves over the first column of the next
	trunks = 0
	spread = 0
	for z in 0..64:
		for k in 0..4:
			x = k * 16 + 15
			top = -1
			for y in 0..world.height:
				if w.at(x, y, z) == world.log:
					top = y
			if top >= 0:
				trunks += 1
				if (top - 1..top + 3).any(w.at(x + 1, it, z) == world.leaves):
					spread += 1
	print(trunks > 0 and spread == trunks)
	prints """
		true
		"""

test "a lone block has six faces of four corners, a shut-in corner is shut in fully":
	w = world.emptyWorld()
	w.setBlock(5, 5, 5, world.stone)
	print(w.meshChunk(0, 0).solid.len)
	# a block beside it hides one face of each
	w.setBlock(6, 5, 5, world.stone)
	two = w.meshChunk(0, 0)
	print("{two.solid.len} {two.water.len}")
	# a floor with a wall on two sides: the corner in the angle is shut in fully
	c = world.emptyWorld()
	for z in 0..3:
		for x in 0..3:
			c.setBlock(x, 0, z, world.stone)
	c.setBlock(0, 1, 1, world.stone)
	c.setBlock(1, 1, 0, world.stone)
	darkest = 3
	for corner in c.meshChunk(0, 0).solid:
		v = shaders.CornerParts.fromBits(corner.word)
		if v.x == 1 and v.y == 1 and v.z == 1:
			darkest = darkest.min(i64(v.open))
	print(darkest)
	prints """
		24
		40 0
		0
		"""

test "a corner packs into one word and back":
	v = shaders.CornerParts.fromBits(world.vertexWord(16, 64, 16, 1, 0, 5, 2, 3, 31).word)
	print(v)
	prints """
		CornerParts(x = 16, y = 64, z = 16, u = true, v = false, face = 5, material = 2, open = 3, layer = 31)
		"""

test "the ray finds the block aimed at and the face it enters":
	w = world.emptyWorld()
	w.setBlock(4, 2, 3, world.dirt)
	w.setBlock(8, 2, 3, world.brick)
	down = w.raycast(Vec3(4.5, 6.5, 3.5), Vec3(0.0, -1.0, 0.0), 6.0)
	print("{down.found} {down.x} {down.y} {down.z} {down.nx} {down.ny} {down.nz}")
	side = w.raycast(Vec3(5.5, 2.5, 3.5), Vec3(1.0, 0.0, 0.0), 6.0)
	print("{side.found} {side.x} {side.y} {side.z} {side.nx} {side.ny} {side.nz}")
	print(w.raycast(Vec3(5.5, 2.5, 3.5), Vec3(0.0, 1.0, 0.0), 6.0).found)
	prints """
		true 4 2 3 0 1 0
		true 8 2 3 -1 0 0
		false
		"""

test "a body falls to the ground, walks into a wall and stops, jumps onto a step":
	w = world.emptyWorld()
	for z in 0..16:
		for x in 0..16:
			for y in 0..3:
				w.setBlock(x, y, z, world.stone)
	for z in 0..16:
		for x in 10..16:
			w.setBlock(x, 3, z, world.stone)
	b = world.newBody(Vec3(5.5, 8.0, 5.5))
	loop 120:
		w.stepBody(b, Vec3(0.0, 0.0, 0.0), false, 1.0 / 60.0)
	print("{b.onGround} {b.feet.y.round()}")
	loop 180:
		w.stepBody(b, Vec3(4.0, 0.0, 0.0), false, 1.0 / 60.0)
	print(b.feet.x < 10.0 - world.bodyHalfWidth + 0.01 and b.feet.x > 9.0)
	for i in 0..60:
		w.stepBody(b, Vec3(4.0, 0.0, 0.0), i < 3, 1.0 / 60.0)
	print("{b.feet.x > 10.0} {b.feet.y.round()}")
	prints """
		true 3
		true
		true 4
		"""

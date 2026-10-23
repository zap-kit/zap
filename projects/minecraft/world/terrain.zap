# The world without an edge: chunks of chunkSize x height x chunkSize blocks, a byte per block,
# kept while the player is near. A chunk is made from the seed and its place alone (hills,
# beaches, a sea, snowy peaks, ores, the trees of its own columns and of those around it), so any
# chunk can be made on any thread, in any order, and the same seed gives the same world.

import engine

pub chunkSize = 16
pub height = 64
pub seaLevel = 20
chunkBlocks = chunkSize * height * chunkSize

# a chunk: where it lies (in chunks), its blocks (index (y * chunkSize + z) * chunkSize + x),
# whether the player changed it (kept then when the player goes away), and how many times a
# change touched its meshes (a mesh made from an older version is stale)
pub type Chunk:
	cx i64
	cz i64
	blocks u8[]
	edited bool
	version i64

# the chunks by their place: a slot each (a slot let go holds no blocks and is used again)
pub type World:
	slots Chunk[]
	index {i64: i64}   # chunkKey -> slot
	free i64[]

	# the slot of chunk cx, cz, or -1 while it is not made
	fn slotOf(cx i64, cz i64):
		index.get(chunkKey(cx, cz)) ?? -1

	fn has(cx i64, cz i64):
		chunkKey(cx, cz) in index

	# the block at x, y, z; air above and below the world and in a chunk not made yet
	fn at(x i64, y i64, z i64):
		if y < 0 or y >= height: return air
		cx = chunkOf(x)
		cz = chunkOf(z)
		s = slotOf(cx, cz)
		air if s < 0 else slots[s].blocks[blockIndex(x - cx * chunkSize, y, z - cz * chunkSize)]

	fn chunkCount():
		index.len

	# the version of chunk cx, cz (0 when it is not made)
	fn versionOf(cx i64, cz i64):
		s = slotOf(cx, cz)
		0 if s < 0 else slots[s].version

pub fn emptyWorld() World:
	World(slots = [], index = {}, free = [])

# one number per chunk place
pub fn chunkKey(cx i64, cz i64) i64:
	(cx << 32) + (cz & 4_294_967_295)

# the chunk a block coordinate lies in (rounded down, below zero too)
pub fn chunkOf(v i64) i64:
	v / chunkSize if v >= 0 else (v + 1) / chunkSize - 1

fn blockIndex(x i64, y i64, z i64):
	(y * chunkSize + z) * chunkSize + x

# keeps the blocks of chunk cx, cz (made by generateChunk)
pub fn addChunk(mut w World, cx i64, cz i64, move blocks u8[]):
	if w.has(cx, cz): return
	c = Chunk(cx, cz, blocks, edited = false, version = 0)
	if not w.free.isEmpty:
		s = w.free.pop() ?? 0
		w.slots[s] = c
		w.index[chunkKey(cx, cz)] = s
	else:
		w.slots.push(c)
		w.index[chunkKey(cx, cz)] = w.slots.len - 1

# lets chunk cx, cz go (its blocks freed)
pub fn dropChunk(mut w World, cx i64, cz i64):
	s = w.slotOf(cx, cz)
	if s < 0: return
	w.slots[s].blocks = []
	w.index.remove(chunkKey(cx, cz))
	w.free.push(s)

# a change touched the meshes of chunk cx, cz
pub fn touchChunk(mut w World, cx i64, cz i64):
	s = w.slotOf(cx, cz)
	if s >= 0:
		w.slots[s].version += 1

# puts block b at x, y, z, in a chunk of air when none is there yet (nothing above or below
# the world)
pub fn setBlock(mut w World, x i64, y i64, z i64, b i64):
	if y < 0 or y >= height: return
	cx = chunkOf(x)
	cz = chunkOf(z)
	if not w.has(cx, cz):
		w.addChunk(cx, cz, zeros(chunkBlocks))
	s = w.slotOf(cx, cz)
	w.slots[s].blocks[blockIndex(x - cx * chunkSize, y, z - cz * chunkSize)] = u8(b)
	w.slots[s].edited = true

# the height of the ground at column x, z
pub fn groundHeight(x i64, z i64, seed i64) i64:
	hills = engine.fractalNoise(f32(x) / 48.0, f32(z) / 48.0, 4, seed)
	ranges = engine.fractalNoise(f32(x) / 160.0, f32(z) / 160.0, 2, seed + 7)
	mountains = (ranges - 0.45).max(0.0) * 70.0
	i64(10.0 + hills * 22.0 + mountains).min(height - 8)

# ---------- the making ----------

# The blocks of chunk cx, cz: the ground of its columns, the trees of every column within a
# tree's reach of it (only the part inside it), then tufts of tall grass on its open grass.
pub fn generateChunk(cx i64, cz i64, seed i64) u8[]:
	blocks = fill(chunkBlocks, u8(0))
	x0 = cx * chunkSize
	z0 = cz * chunkSize
	heights = Grid<i64>(chunkSize, chunkSize)
	for z in 0..heights.height:
		for x in 0..heights.width:
			h = groundHeight(x0 + x, z0 + z, seed)
			heights[x, z] = h
			for y in 0..=seaLevel.max(h):
				blocks[blockIndex(x, y, z)] = u8(columnBlock(x0 + x, y, z0 + z, h, seed))
	# in the order of the whole world (z, then x), so a block two trees reach ends the same in
	# both chunks it lies near
	for z in z0 - treeReach..z0 + chunkSize + treeReach:
		for x in x0 - treeReach..x0 + chunkSize + treeReach:
			if treeAt(x, z, seed):
				plantTree(blocks, x - x0, groundHeight(x, z, seed) + 1, z - z0, x, z, seed)
	# tufts of tall grass on the open grass, thicker where a slow noise says so
	for z in 0..heights.height:
		for x in 0..heights.width:
			h = heights[x, z]
			meadow = engine.valueNoise(f32(x0 + x) / 12.0, f32(z0 + z) / 12.0, seed + 41)
			if blocks[blockIndex(x, h, z)] == grass and blocks[blockIndex(x, h + 1, z)] == air and
				f32(engine.hash2(x0 + x, z0 + z, seed + 77) % 1000) < meadow * meadow * 700.0:
				blocks[blockIndex(x, h + 1, z)] = u8(tallGrass)
	blocks

# the block at height y of the column x, z whose ground is at h: stone with ores, dirt, then
# grass, sand on a shore, snow on a peak; water up to the sea's level over a low one
fn columnBlock(x i64, y i64, z i64, h i64, seed i64):
	if y > h: return water if y <= seaLevel else air
	beach = h <= seaLevel + 1
	peak = h >= 42
	if y == h: return sand if beach else snow if peak else grass
	if y >= h - 3: return sand if beach else stone if peak else dirt
	r = engine.hash2(x * 7 + y * 131, z, seed + 5) % 1000
	coal if r < 12 else iron if r < 18 else gravel if r < 22 else stone

treeReach = 2   # how far a tree's leaves spread from its trunk

# whether a tree grows at column x, z: on grass (not a shore, not a peak), now and then
fn treeAt(x i64, z i64, seed i64):
	if engine.hash2(x, z, seed + 99) % 1000 >= 12: return false
	h = groundHeight(x, z, seed)
	h > seaLevel + 1 and h < 42

# a tree whose trunk starts at x, y, z of the chunk (wx, wz in the world, for its height): a log
# 4 to 6 high under a ball of leaves; only its blocks inside the chunk are written
fn plantTree(mut blocks u8[], x i64, y i64, z i64, wx i64, wz i64, seed i64):
	trunk = 4 + engine.hash2(wx, wz, seed + 3) % 3
	top = y + trunk
	for dy in -2..3:
		for dz in -2..3:
			for dx in -2..3:
				if dx * dx + dy * dy + dz * dz <= 5 and
					blockIn(blocks, x + dx, top + dy, z + dz) == air:
					putIn(blocks, x + dx, top + dy, z + dz, leaves)
	for k in 0..trunk:
		putIn(blocks, x, y + k, z, log)

fn insideChunk(x i64, y i64, z i64):
	x >= 0 and z >= 0 and y >= 0 and x < chunkSize and z < chunkSize and y < height

# a block of a chunk's list, air outside it
fn blockIn(blocks u8[], x i64, y i64, z i64) i64:
	blocks[blockIndex(x, y, z)] if insideChunk(x, y, z) else air

fn putIn(mut blocks u8[], x i64, y i64, z i64, b i64):
	if insideChunk(x, y, z):
		blocks[blockIndex(x, y, z)] = u8(b)

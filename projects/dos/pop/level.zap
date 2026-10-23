# A level of LEVELS.DAT (resources 2000..2015, 2305 bytes each): 24 rooms of 3 rows of 10 tiles,
# each tile a kind and a modifier, the links between rooms, the doors' buttons, the start and a
# guard a room, laid out as SDLPoP's level_type (types.h) has it.

pub roomCount = 24
pub tilesPerRoom = 30

# the rooms around one, 0 for none
pub type RoomLinks:
	left i64
	right i64
	up i64
	down i64

# the guard of a room as the level places it
pub type GuardStart:
	tile i64   # 0..29; 30 and up for no guard
	direction i64   # 0 right, -1 left
	x i64
	seq i64   # the sequence it starts in, an address of the sequence table (0 for the default)
	skill i64
	color i64

pub type Level:
	tiles u8[]   # 720: room r's tile i at (r - 1) * 30 + i; the low 5 bits the kind, 0x20 a flag
	modifiers u8[]   # 720, beside each tile
	doorLinks1 u8[]   # 256
	doorLinks2 u8[]   # 256
	links RoomLinks[]   # room r at r - 1
	usedRooms i64
	startRoom i64
	startPos i64
	startDir i64
	guards GuardStart[]   # room r at r - 1

# the level of a LEVELS.DAT resource; the last one is a byte short, which reads as zero
pub fn levelOf(src u8[]) Level:
	b = src.copy()
	if b.len < 2305:
		b.extend(zeros(2305 - b.len))
	links = (0..roomCount).map(
		RoomLinks(
			left = b[1952 + it * 4],
			right = b[1953 + it * 4],
			up = b[1954 + it * 4],
			down = b[1955 + it * 4]
		)
	)
	guards = (0..roomCount).map(
		GuardStart(
			tile = b[2119 + it],
			direction = i8.wrap(b[2143 + it]),
			x = b[2167 + it],
			seq = i64(b[2239 + it]) << 8 | b[2191 + it],
			skill = b[2215 + it],
			color = b[2263 + it]
		)
	)
	Level(
		tiles = b[..720].copy(),
		modifiers = b[720..1440].copy(),
		doorLinks1 = b[1440..1696].copy(),
		doorLinks2 = b[1696..1952].copy(),
		links,
		usedRooms = b[2048],
		startRoom = b[2112],
		startPos = b[2113],
		startDir = i8.wrap(b[2114]),
		guards
	)

# level n (0..15) of LEVELS.DAT
pub fn loadLevel(levels Dat, n i64) Level:
	levelOf(levels.need(2000 + n))

# the level as LEVELS.DAT lays it out (2305 bytes): what the game keeps of it, the unused fields
# zero (SDLPoP's reset_level_unused_fields), as a savestate holds it
pub fn bytesOf(l Level) u8[]:
	b u8[] = zeros(2305)
	used = l.usedRooms.min(roomCount)   # only the rooms in use have their skill and colour masked
	for i in 0..720:
		b[i] = l.tiles[i]
		b[720 + i] = l.modifiers[i]
	for i in 0..256:
		b[1440 + i] = l.doorLinks1[i]
		b[1696 + i] = l.doorLinks2[i]
	for i in 0..roomCount:
		k = l.links[i]
		b[1952 + i * 4] = u8.wrap(k.left)
		b[1953 + i * 4] = u8.wrap(k.right)
		b[1954 + i * 4] = u8.wrap(k.up)
		b[1955 + i * 4] = u8.wrap(k.down)
		g = l.guards[i]
		b[2119 + i] = u8.wrap(g.tile)
		b[2143 + i] = u8.wrap(g.direction & 0xFF)
		b[2167 + i] = u8.wrap(g.x)
		b[2191 + i] = u8.wrap(g.seq & 0xFF)
		b[2215 + i] = u8.wrap(g.skill & 0x0F if i < used else g.skill)
		b[2239 + i] = u8.wrap(g.seq >> 8)
		b[2263 + i] = u8.wrap(g.color & 0x0F if i < used else g.color)
	b[2048] = u8.wrap(l.usedRooms.min(roomCount))
	b[2112] = u8.wrap(l.startRoom)
	b[2113] = u8.wrap(l.startPos)
	b[2114] = u8.wrap(l.startDir & 0xFF)
	b

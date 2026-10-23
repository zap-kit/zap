# A level: one 2048-byte section of a levelXXX.dat (the LVL layout, words big-endian), and the
# game's order of its 120 levels (Fun, Tricky, Taxing, Mayhem: 30 each), by the table of the
# executable; a level played again with other numbers takes them from oddtable.dat.

import fs

pub type PlacedObject:
	x i64
	y i64
	kind i64
	noOverwrite bool   # drawn only where nothing is
	onlyOnTerrain bool   # drawn only on terrain
	upsideDown bool

pub type PlacedPiece:
	x i64
	y i64
	piece i64
	noOverwrite bool
	upsideDown bool
	erase bool

pub type SteelArea:
	x i64
	y i64
	width i64
	height i64

pub type Level:
	name str
	releaseRate i64
	lemmings i64
	toRescue i64
	minutes i64
	skills i64[8]   # climber, floater, bomber, blocker, builder, basher, miner, digger
	screenStart i64
	graphicsSet i64
	special i64   # 0 none, else vgaspec<special - 1>
	objects PlacedObject[]
	pieces PlacedPiece[]
	steel SteelArea[]

fn wordBe(b u8[], at i64):
	i64(b[at]) << 8 | b[at + 1]

fn signed16(v i64):
	v - 65_536 if v >= 32_768 else v

fn placedObject(b u8[], at i64) PlacedObject?:
	if (0..8).all(b[at + it] == 0): return none
	PlacedObject(
		x = signed16(wordBe(b, at)) - 16,
		y = signed16(wordBe(b, at + 2)),
		kind = b[at + 5] & 15,
		noOverwrite = b[at + 6] & 0x80 != 0,
		onlyOnTerrain = b[at + 6] & 0x40 != 0,
		upsideDown = b[at + 7] == 0x8F
	)

fn placedPiece(b u8[], at i64) PlacedPiece?:
	if (0..4).all(b[at + it] == 0xFF): return none
	h = i64(b[at + 2]) << 1 | b[at + 3] >> 7
	if h >= 256:
		h -= 512
	PlacedPiece(
		x = (i64(b[at] & 15) << 8 | b[at + 1]) - 16,
		y = h - 4,
		piece = b[at + 3] & 63,
		noOverwrite = b[at] & 0x80 != 0,
		upsideDown = b[at] & 0x40 != 0,
		erase = b[at] & 0x20 != 0
	)

fn steelArea(b u8[], at i64) SteelArea?:
	if (0..4).all(b[at + it] == 0): return none
	SteelArea(
		x = (i64(b[at]) << 1 | b[at + 1] >> 7) * 4 - 16,
		y = i64(b[at + 1] & 0x7F) * 4,
		width = i64(b[at + 2] >> 4) * 4 + 4,
		height = i64(b[at + 2] & 15) * 4 + 4
	)

fn nameOf(b u8[], at i64, n i64):
	str(b[at..at + n]).trimmed().copy()

# a level from its 2048 bytes
pub fn levelOf(b u8[]) Level:
	if b.len != 2048: fail("a level has 2048 bytes, not {b.len}")
	skills i64[8]
	for i in 0..8:
		skills[i] = wordBe(b, 8 + i * 2) & 255
	objects = []
	for i in 0..32:
		if placedObject(b, 0x20 + i * 8) is o:
			objects.push(o)
	pieces = []
	for i in 0..400:
		if placedPiece(b, 0x120 + i * 4) is p:
			pieces.push(p)
	steel = []
	for i in 0..32:
		if steelArea(b, 0x760 + i * 4) is s:
			steel.push(s)
	Level(
		name = nameOf(b, 0x7E0, 32),
		releaseRate = wordBe(b, 0).clamp(1, 99),
		lemmings = wordBe(b, 2).clamp(1, 255),
		toRescue = wordBe(b, 4),
		minutes = wordBe(b, 6).clamp(1, 99),
		skills,
		screenStart = wordBe(b, 0x18),
		graphicsSet = wordBe(b, 0x1A),
		special = wordBe(b, 0x1C),
		objects,
		pieces,
		steel
	)

pub ratings = ["Fun", "Tricky", "Taxing", "Mayhem"]

# the executable's table: each entry less one, halved, is the level's index over the ten files
# (eight a file); an odd entry takes its numbers from oddtable.dat at that index
# long: the game's table
orderTable = [
	[147, 155, 157, 149, 151, 153, 159, 14, 22, 54, 70, 16, 29, 32, 38, 42, 48, 72, 84, 104,
		138, 23, 68, 96, 98, 116, 78, 100, 108, 134],
	[1, 30, 36, 50, 52, 56, 58, 80, 102, 120, 128, 130, 136, 5, 148, 152, 154, 156, 160, 7,
		11, 13, 15, 17, 19, 21, 25, 27, 33, 31],
	[37, 39, 41, 43, 45, 47, 49, 51, 53, 55, 57, 59, 61, 63, 3, 65, 67, 69, 71, 73,
		75, 77, 79, 81, 83, 85, 87, 89, 35, 111],
	[91, 93, 95, 97, 99, 101, 103, 105, 107, 109, 112, 113, 115, 117, 119, 121, 123, 125, 127, 150,
		129, 9, 131, 133, 135, 137, 139, 141, 143, 145]
]

# the level's numbers replaced by the odd table's record (56 bytes: 12 big-endian words, then the
# name)
fn applyOdd(mut level Level, table u8[], index i64):
	at = index * 56
	if at + 56 > table.len: fail("oddtable.dat has no record {index}")
	level.releaseRate = wordBe(table, at).clamp(1, 99)
	level.lemmings = wordBe(table, at + 2).clamp(1, 255)
	level.toRescue = wordBe(table, at + 4)
	level.minutes = wordBe(table, at + 6).clamp(1, 99)
	for i in 0..8:
		level.skills[i] = wordBe(table, at + 8 + i * 2) & 255
	level.name = nameOf(table, at + 24, 32)

# level `number` (0..29) of rating `rating` (0..3) read from the install dir
pub fn loadLevel(dir str, rating i64, number i64) Level:
	entry = orderTable[rating][number] - 1
	odd = entry & 1 != 0
	index = entry / 2
	file = fs.readBytes("{dir}/level{(index / 8):03}.dat") ??
		fail("cannot read level{(index / 8):03}.dat: {error}")
	sections = sectionsOf(file)
	level = levelOf(sections[index % 8].bytes)
	if odd:
		table = fs.readBytes("{dir}/oddtable.dat") ?? fail("cannot read oddtable.dat: {error}")
		level.applyOdd(table, index)
	level

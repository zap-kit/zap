# 7.7 Serialization
#
# The compiler writes `toJson`, `fromJson`, `toBytes` and `fromBytes` for any type made of
# serializable parts: numbers, bools, strings, lists, maps, optionals, structs, enums, grids. Untyped JSON
# is read with the standard library's `json` module.

type Stat:
	Str
	Agi
	Vit

type Skill:
	Passive(name str)
	Active(name str, cost i64, cooldown f64)

type Item:
	id u32
	name str
	price f64

type Character:
	id i64
	name str
	level i64
	alive bool
	stats {str: i64}
	bag Item[]
	mainStat Stat
	skills Skill[]
	guild str?
	tags str[]

fn sample():
	Character(
		id = 7,
		name = "Ana \"the\" Brave",
		level = 42,
		alive = true,
		stats = { "str": 10, "agi": 7 },
		bag = [Item(id = 1, name = "Red Potion", price = 12.5), Item(id = 2, name = "Knife", price = 50.0)],
		mainStat = .Agi,
		skills = [.Passive("Basic Skill"), .Active("Bash", 8, 0.75)],
		guild = none,
		tags = ["novice", "br"],
	)

# `v.toJson()` is a `str` of JSON; an enum variant is an object with `"$tag"` and its fields, an
# absent optional `null`, a float that is not finite `null` (which no float reads back), -0.0 `-0`.

test "toJson writes a value as JSON":
	print(sample().toJson())
	print([1, 2, 3].toJson())
	print({ 1: "a", 2: "b" }.toJson())
	print("tab\tquote\" unicode é".toJson())
	print((0.1 + 0.2).toJson())
	print(2.0.toJson())
	prints r"""
		{"id":7,"name":"Ana \"the\" Brave","level":42,"alive":true,"stats":{"agi":7,"str":10},"bag":[{"id":1,"name":"Red Potion","price":12.5},{"id":2,"name":"Knife","price":50}],"mainStat":{"$tag":"Agi"},"skills":[{"$tag":"Passive","name":"Basic Skill"},{"$tag":"Active","name":"Bash","cost":8,"cooldown":0.75}],"guild":null,"tags":["novice","br"]}
		[1,2,3]
		{"1":"a","2":"b"}
		"tab\tquote\" unicode é"
		0.30000000000000004
		2
		"""

# `T.fromJson(text)` is a `T?`: none on wrong types, missing fields, an integer outside its type's
# values (a u64 reads all of its own) or trailing text; extra keys are ignored, and an absent
# optional field is `none`.

test "fromJson reads it back exactly":
	c = sample()
	text = c.toJson()
	back = Character.fromJson(text) ?? fail("decode failed")
	expect back.toJson() == text
	expect back.mainStat == .Agi
	expect (back.stats.get("agi") ?? 0) == 7
	expect back.skills[1] is Active(name, cost, cooldown) and name == "Bash" and cost == 8 and
		cooldown == 0.75

cases = [
	("\{\"id\": 5, \"name\": \"x\", \"price\": 1, \"extra\": [1, \{\}]\}", "x"),
	("\{\"id\": \"five\", \"name\": \"x\", \"price\": 1\}", "none"),
	("\{\"id\": 5, \"name\": \"x\"\}", "none"),
	("not json", "none"),
	("\{\"id\": 5, \"name\": \"x\", \"price\": 1\} trailing", "none"),
	("\{\"id\": -1, \"name\": \"x\", \"price\": 1\}", "none"),
	("\{\"id\": 4294967296, \"name\": \"x\", \"price\": 1\}", "none"),
	("\{\"price\":1,\"name\":\"y\",\"id\":5\}", "y"),
	("\{\"id\":5,\"n\\u0061me\":\"z\",\"price\" : 1,\"pricey\":2\}", "z"),
	("\{\"id\":5,\"nam\":\"x\",\"price\":1\}", "none")
]

test "fromJson takes extra keys and refuses the rest" for (text, name) in cases:
	expect (Item.fromJson(text)?.name ?? "none") == name

test "fromJson of variants and of an absent optional":
	expect (Skill.fromJson("\{\"$tag\":\"Passive\",\"name\":\"Zen\"\}")?.toJson() ?? "") ==
		"\{\"$tag\":\"Passive\",\"name\":\"Zen\"\}"
	expect Skill.fromJson("\{\"$tag\":\"Nope\"\}") == none
	expect Character.fromJson("\{\"id\":1,\"name\":\"n\",\"level\":1,\"alive\":false,\"stats\":\{\},\"bag\":[],\"mainStat\":\{\"$tag\":\"Vit\"\},\"skills\":[],\"tags\":[]\}") is ch and ch.guild == none

# `T` is a named type, `U[]` or `{K: V}`.

test "a list or map type reads JSON as a named type does":
	items = Item[].fromJson("[\{\"id\": 1, \"name\": \"axe\", \"price\": 2.5}, \{\"id\": 2, \"name\": \"bow\", \"price\": 4.0}]") ?? []
	print("{items.len} {items[1].name}")
	print(Item[].fromJson("[1]"))
	print({str: i64}.fromJson("\{\"axe\": 3}"))
	print((Item[].fromBytes(items.toBytes()) ?? []).len)
	prints r"""
		2 bow
		none
		some({"axe": 3})
		2
		"""

# `v.toBytes()` is a `u8[]`, little-endian, with no names and no padding: numbers and bools as
# stored, a str or list as a `u32` count and its items, a map as count and pairs, an optional as a
# tag byte, a struct as its fields, an enum as a `u32` tag and its fields. Both ends must agree on
# the type.

type Pair:
	small u8
	big i32

type Cell:
	Empty
	Full(v u8)

test "toBytes lays a value out":
	print(i32(258).toBytes())
	print(true.toBytes())
	print("ab".toBytes())
	print([u8(7), 8].toBytes())
	print({ u8(1): u8(2) }.toBytes())
	small u8? = 5
	print(small.toBytes())
	print(Pair(small = 1, big = 2).toBytes())
	print(Cell.Full(9).toBytes())
	prints """
		[2, 1, 0, 0]
		[1]
		[2, 0, 0, 0, 97, 98]
		[2, 0, 0, 0, 7, 8]
		[1, 0, 0, 0, 1, 2]
		[1, 5]
		[1, 2, 0, 0, 0]
		[1, 0, 0, 0, 9]
		"""

# `T.fromBytes(bytes)` is a `T?`: truncated or empty input, or a range type's value outside its
# range, is `none`; it reads a borrowed part of a larger list.

type Vec2:
	x i32
	y f64

type Msg:
	Hello(id i32, name str)
	Move(id i32, at Vec2, tags str[], extra i32?)
	Bye

type World:
	players {str: Vec2}
	log Msg[]

type FileHead:
	version u32
	count i64

test "fromBytes reads it back":
	m = Msg.Move(7, Vec2(x = 3, y = 2.5), ["a", "bb"], none)
	bytes = m.toBytes()
	print(bytes.len)
	print(Msg.fromBytes(bytes))
	w = World(players = { "ana": Vec2(x = 1, y = 1.5) }, log = [.Bye, .Hello(1, "zé")])
	print(World.fromBytes(w.toBytes()))
	broken = m.toBytes()
	broken.pop()
	expect Msg.fromBytes(broken) == none
	expect Msg.fromBytes([]) == none
	file u8[] = [1, 2, 3]
	file.extend(FileHead(version = 7, count = 42).toBytes())
	h = FileHead.fromBytes(file[3..]) ?? FileHead(version = 0, count = 0)
	print("{h.version} {h.count}")
	prints r"""
		36
		some(Move(7, Vec2(x = 3, y = 2.5), ["a", "bb"], none))
		some(World(players = {"ana": Vec2(x = 1, y = 1.5)}, log = [Bye, Hello(1, "zé")]))
		7 42
		"""

# `T.fromBytes(r)` reads one value with a `Reader` (*Modules*) and advances it: the same layout in
# the reader's byte order, so a file's record is a struct read whole (a fixed array is its `N`
# values, which `toBytes` writes too), and a list of numbers is one copy of its bytes. It is a
# `T`, never stopping the program: bytes past the end, a range's value outside it or an enum's
# unknown tag set `r.short` and give the lowest value, checked once a record.

type Record:
	corners f32[2]
	texture u16
	level Level
	heights f32[]

test "fromBytes reads a record with a Reader":
	rec = Record(corners = [0.5, 1.5], texture = 300, level = 7, heights = [1, 2, 3])
	bytes = rec.toBytes()
	r = Reader(d = bytes)
	print("{Record.fromBytes(r)} {r.short} {r.at == bytes.len}")
	big = []
	big.pushU32be(2)
	big.pushU16be(258)
	big.pushU16be(3)
	b = Reader(d = big, big = true)
	print("{u16[].fromBytes(b)} {b.short}")
	cut = Reader(d = bytes[..9])
	print("{Record.fromBytes(cut)} {cut.short}")
	prints """
		Record(corners = [0.5, 1.5], texture = 300, level = 7, heights = [1, 2, 3]) false true
		[258, 3] false
		Record(corners = [0.5, 1.5], texture = 0, level = 1, heights = []) true
		"""

# `T.fromBytesAt(bytes, at)` is a `T?`: one value read in place from `bytes` at the position `at`,
# in the layout of `T.fromBytes(r)` (little-endian), none when the bytes end first or `at` is
# below 0. A file's record is a struct of its fields in order: its padding is a field `pad u8[n]`
# (`pad2`... for more) and a pointer a `u64`, so no offset of the layout is written in the reader.

type Ctda:
	head u8
	pad u8[3]
	value f32
	function u16
	pad2 u8[2]
	reference u64

test "fromBytesAt reads a record in place":
	data u8[] = [9, 9]
	data.push(0xA0)
	data.extend([0, 0, 0])
	data.pushF32le(1.5)
	data.pushU16le(300)
	data.extend([0, 0])
	data.pushU64le(77)
	c = Ctda.fromBytesAt(data, 2) ?? Ctda.fromBytesAt(data, 0) ?? return
	print("{c.head} {c.value} {c.function} {c.reference}")
	expect Ctda.fromBytesAt(data, 3) == none
	expect Ctda.fromBytesAt(data, -1) == none
	expect Ctda.fromBytesAt(data, data.len) == none
	prints """
		160 1.5 300 77
		"""

test "fromBytesAt needs an integer position" refuses FromBytesAtPosition:
	bytes u8[] = []
	print(Ctda.fromBytesAt(bytes, "x"))

# A struct of bools, unsigned integers and range types packs into one word: `v.toBits()` is a
# `u32` (a `u64` past 32 bits), its first field in the lowest bits, each field in the bits its
# values need (a bool one, a `u8` eight, an `i32 in 0..=16` five, kept as its distance from the
# range's lowest), and `T.fromBits(w)` reads it back, bits outside a field's range clamped into
# it. The same functions run on the CPU and in a shader (a vertex packed here, unpacked there).

type Packed:
	x i32 in 0..=16
	y i32 in -3..=60
	lit bool
	layer u8

test "a struct packed into bits and read back":
	p = Packed(x = 16, y = -2, lit = true, layer = 200)
	w = p.toBits()
	expect w == 821_296
	expect Packed.fromBits(w) == p
	print(Packed.fromBits(0xFFFF_FFFF))
	prints """
		Packed(x = 16, y = 60, lit = true, layer = 255)
		"""

test "a field without its bits does not pack" refuses CannotPackBits:
	type Signed:
		v i32
	print(Signed(v = 1).toBits())

# Every part round-trips exactly through both encodings, its extremes included.

type Level = i32 in 1..=99

type Every:
	a i8
	b i16
	c i32
	d i64
	e u8
	f u16
	g u32
	h u64
	i n32
	j n64
	lvl Level
	m f32
	n f64
	stat Stat
	skill Skill
	maybe i32?
	inner Pair
	cell Cell
	list i64[]
	byKey {i8: u64}
	byName {str: i32?}

lows = Every(
	a = -128,
	b = -32_768,
	c = -2_147_483_648,
	d = -9_223_372_036_854_775_807 - 1,
	e = 0,
	f = 0,
	g = 0,
	h = 0,
	i = 0,
	j = 0,
	lvl = 1,
	m = -3.4028235e38,
	n = -1.7976931348623157e308,
	stat = .Str,
	skill = .Active("", -1, -0.5),
	maybe = -1,
	inner = Pair(small = 0, big = -1),
	cell = .Empty,
	list = [-1, -9_223_372_036_854_775_807 - 1],
	byKey = { -128: 18_446_744_073_709_551_615, -1: 0 },
	byName = { "": none, "x": -2_147_483_648 },
)

highs = Every(
	a = 127,
	b = 32_767,
	c = 2_147_483_647,
	d = 9_223_372_036_854_775_807,
	e = 255,
	f = 65_535,
	g = 4_294_967_295,
	h = 18_446_744_073_709_551_615,
	i = 2_147_483_647,
	j = 9_223_372_036_854_775_807,
	lvl = 99,
	m = 1.0e-45,
	n = 5.0e-324,
	stat = .Agi,
	skill = .Passive("é"),
	maybe = none,
	inner = Pair(small = 255, big = 2_147_483_647),
	cell = .Full(255),
	list = [],
	byKey = {},
	byName = {},
)

zeros = Every(
	a = 0,
	b = -1,
	c = -5,
	d = 0,
	e = 1,
	f = 1,
	g = 1,
	h = 9_223_372_036_854_775_808,
	i = 1,
	j = 0,
	lvl = 50,
	m = -0.0,
	n = -0.0,
	stat = .Vit,
	skill = .Passive("Ana \"the\" Brave"),
	maybe = 0,
	inner = Pair(small = 1, big = -2),
	cell = .Full(0),
	list = [0],
	byKey = { 0: 1 },
	byName = { "0": 0 },
)

fn everyCases():
	[(lows, "lows"), (highs, "highs"), (zeros, "zeros")]

test "every part round-trips through toBytes and toJson" for (v, _) in everyCases():
	bytes = v.toBytes()
	expect (Every.fromBytes(bytes)?.toBytes() ?? []) == bytes
	expect (Every.fromJson(v.toJson())?.toBytes() ?? []) == bytes

test "a value outside its type is none":
	expect u8[].fromJson("[-1]") == none
	expect u8[].fromJson("[256]") == none
	expect n32[].fromJson("[-1]") == none
	expect i64[].fromJson("[9223372036854775808]") == none
	expect u64[].fromJson("[18446744073709551616]") == none
	expect {i8: i8}.fromJson("\{\"-129\": 0}") == none
	expect Level[].fromJson("[0]") == none
	expect Level[].fromBytes([1, 0, 0, 0, 100, 0, 0, 0]) == none
	expect Level[].fromBytes([1, 0, 0, 0, 255, 255, 255, 255]) == none
	expect n64[].fromBytes([1, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255]) == none

test "-0 is 0 for every integer type, and a sign before a value above 0 none for an unsigned one":
	print("{u8[].fromJson("[-0]")} {u32[].fromJson("[-0]")} {u64[].fromJson("[-0]")} {n64[].fromJson("[-0]")} {i64[].fromJson("[-0]")}")
	expect u64[].fromJson("[-1]") == none
	expect u64[].fromJson("[-0.0]") == none
	prints "some([0]) some([0]) some([0]) some([0]) some([0])"

# A `Grid<T>` is serialized by its width, its height and its cells; cells that do not fill the size
# read as none.
type Heights:
	name str
	ground Grid<f64>

test "a grid round-trips through toBytes and toJson":
	v = Heights(name = "hills", ground = Grid(2, 2, cells = [1.5, 2.5, 3.5, 4.5]))
	bytes = v.toBytes()
	back = Heights.fromBytes(bytes) ?? Heights(name = "", ground = Grid(0, 0))
	print("{back.name} {back.ground.width}x{back.ground.height} {back.ground.cells}")
	json = v.toJson()
	print(json)
	again = Heights.fromJson(json) ?? Heights(name = "", ground = Grid(0, 0))
	print(again.ground[1, 1])
	prints r"""
		hills 2x2 [1.5, 2.5, 3.5, 4.5]
		{"name":"hills","ground":{"width":2,"height":2,"cells":[1.5,2.5,3.5,4.5]}}
		4.5
		"""

test "a grid whose cells do not fill its size is none":
	expect Heights.fromJson(
		"\{\"name\":\"a\",\"ground\":\{\"width\":2,\"height\":2,\"cells\":[1.0]}}"
	) ==
		none

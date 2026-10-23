# Looks inside the assets of a district's streams, for working out their formats: the count of
# each kind of asset, and for one asset its RW4 dictionary and the first bytes of each object.
# Run from the repository root:
#
#   zap run projects/skate3/inspect.zap                        the University's streams, counted
#   zap run projects/skate3/inspect.zap Pres 12                asset 12 of the Pres stream, its dictionary
#   zap run projects/skate3/inspect.zap Pres 12 1 256          ... and 256 bytes of its object 1
#   zap run projects/skate3/inspect.zap --district DIST_MegaPark Sim 0
#   zap run projects/skate3/inspect.zap recipe                 the fallback skater's recipe
#   zap run projects/skate3/inspect.zap Pres models            every model decoded, what they use counted
#   zap run projects/skate3/inspect.zap data/content/createacharacter/model/cas_db/Arm/0x00000dce03e38811.rx2 model

import ea
import rw4
import skate
import fs

disc, district, big = skate.openToolDistrict()
args.options(
	[
		skate.districtOption,
		skate.isoOption,
		ArgOption("--big", true, "the BIG archive to look into")
	]
)
words = args.positional()
if not words.isEmpty and words[0] == "recipe":
	# the fallback skater's recipe: each slot's level-0 model and textures
	misc = disc.openBig("data/big/miscload.big") ?? fail
	bytes = misc.readBigFile("data/cacrecipes/SavedRecipeFallbackMale.bin") ?? fail
	parts = skate.readRecipe(bytes) ?? fail
	for part in parts:
		print("{part.slot}: model {ea.hex64(part.modelId)} {part.textures.map("{.channel} {ea.hex64(.id)}").join(", ")}")
	return
if not words.isEmpty and words[0].endsWith(".rx2"):
	# an arena kept whole in a BIG archive: --big <archive> <path in it> [object] [bytes]
	other = disc.openBig(args.option("--big") ?? "data/content/createacharacter.big") ??
		fail
	bytes = other.readBigFile(words[0]) ?? fail
	if words.len > 1 and words[1] == "model":
		showModel(bytes)
		return
	showArena(bytes, words[1..])
	return
if words.isEmpty:
	for name in ["Pres", "Sim", "Tex"]:
		started = clockSeconds()
		s = big.openStream(district, name) ?? fail
		kinds {i64: i64} = {}
		for asset in s.assets:
			kinds.add(asset.kind, 1)
		line = "{name}: {s.assets.len} assets ({(clockSeconds() - started):.2} s):"
		for k in kinds.keys():
			line += " {kinds.get(k) ?? 0} of type 0x{k:X}"
		print(line)
	return
s = big.openStream(district, words[0]) ?? fail
if words.len > 1 and words[1] == "models":
	big.surveyModels(s)
	return
if words.len > 1 and words[1] == "list":
	for k, sa in s.assets:
		print("{k} {ea.hex64(sa.id)} 0x{sa.kind:X} {sa.total} {big.entries.items[sa.entry].path}")
	return
index = (i64.parse(words[1]) ?? 0) if words.len > 1 else 0
asset = s.assets[index]
file = big.readBigEntry(big.entries.items[asset.entry]) ?? fail
mut bytes = skate.assetBytes(file, asset) ?? fail
print("asset {index}: id {ea.hex64(asset.id)} type 0x{asset.kind:X}, {bytes.len} bytes, in {big.entries.items[asset.entry].path}")
if words.len > 3 and words[2] == "save":
	_ = fs.writeBytes(words[3], bytes)
	return
showArena(bytes, words[2..])

# an arena's dictionary, and when `rest` names an object, its first bytes (128, or rest[1])
fn showArena(move bytes u8[], rest str[]):
	arena = rw4.openArena(move bytes) ?? fail
	print("resource base 0x{arena.resourceBase:X}")
	for k, e in arena.entries:
		print("  [{k}] {rw4.typeName(e.kind):<22} at 0x{e.at:06X} size {e.size}")
	if not rest.isEmpty:
		k = i64.parse(rest[0]) ?? 0
		n = (i64.parse(rest[1]) ?? 128) if rest.len > 1 else 128
		if k < 0 or k >= arena.entries.len:
			fail("no object {k}: the dictionary holds {arena.entries.len}")
		e = arena.entries[k]
		dump(arena.bytes, e.at, n.min(arena.bytes.len - e.at))

# n bytes from `at`, 16 a line, in hexadecimal and as text
fn dump(d u8[], at i64, n i64):
	row = 0
	while row < n:
		hexes = ""
		text = []
		for k in row..(row + 16).min(n):
			b = d[at + k]
			hexes += "{b:02X}{("  " if k % 4 == 3 else " ")}"
			text.push(b if b >= 32 and b < 127 else '.')
		print("  {row:04X}  {hexes:<60} {str(move text)}")
		row += 16

# every model of the stream decoded, and what they use counted: vertex layouts, shaders, the
# channels of their materials, how many meshes, vertices and triangles
fn surveyModels(big ea.Big, s skate.Stream):
	layouts {str: i64} = {}
	shaders {str: i64} = {}
	channels {str: i64} = {}
	unique {str: i64} = {}
	seen {i64: bool} = {}
	failures = 0
	meshes = 0
	vertices = 0
	triangles = 0
	file = -1
	fileBytes = []
	for asset in s.assets:
		if asset.kind != skate.assetModel: continue
		if asset.entry != file:
			file = asset.entry
			fileBytes = big.readBigEntry(big.entries.items[file]) ?? fail
		bytes = skate.assetBytes(fileBytes, asset) ?? fail
		arena = rw4.openArena(bytes) ?? fail
		model = rw4.Model(materials = [], meshes = [], transform = [], name = "")
		match arena.readModel():
			m: model = m
			error:
				failures += 1
				eprint("{ea.hex64(asset.id)}: {error}")
				continue
		for m in model.meshes:
			meshes += 1
			vertices += m.vertices.len
			triangles += m.indices.len / 3
			key = "stride {m.stride}:"
			for e in m.elements:
				key += " u{e.usage}.{e.usageIndex}@{e.offset}=0x{e.code:06X}"
			layouts.add(key, 1)
			if m.material >= 0:
				mat = model.materials[m.material]
				shaders.add(mat.shader, 1)
				for t in mat.textures:
					channels.add(t.channel, 1)
					if t.id not in seen:
						seen[t.id] = true
						unique.add(t.channel, 1)
			else:
				shaders.add("(none)", 1)
	print("{meshes} meshes, {vertices} vertices, {triangles} triangles, {failures} models not read")
	for k in layouts.keys():
		print("  {layouts.get(k) ?? 0}  {k}")
	for k in shaders.keys():
		print("  shader {k}: {shaders.get(k) ?? 0}")
	for k in channels.keys():
		print("  channel {k}: {channels.get(k) ?? 0} uses, {unique.get(k) ?? 0} textures")

# a model arena's meshes: their vertices' bounds, a few vertices, their materials
fn showModel(move bytes u8[]):
	arena = rw4.openArena(move bytes) ?? fail
	model = arena.readModel() ?? fail
	print("{model.name}: {model.meshes.len} meshes, {model.materials.len} materials")
	for mat in model.materials:
		print("  material {mat.name} shader {mat.shader}")
		for t in mat.textures:
			print("    {t.channel} {ea.hex64(t.id)}")
	for m in model.meshes:
		lo = [1000000.0, 1000000.0, 1000000.0].map(f32(it))
		hi = [-1000000.0, -1000000.0, -1000000.0].map(f32(it))
		n = m.vertices.len
		for p in m.vertices.position:
			for k in 0..3:
				lo[k] = lo[k].min(p[k])
				hi[k] = hi[k].max(p[k])
		print("  mesh: {n} vertices, {m.indices.len / 3} triangles, material {m.material}, stride {m.stride}, positions {lo} .. {hi}")
		for i in 0..n.min(3):
			print("    uv {m.vertices.uv[i].x}, {m.vertices.uv[i].y}")

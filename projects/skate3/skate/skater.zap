# The skater as the game makes him when no saved one is found: the fallback recipe
# (data/cacrecipes/SavedRecipeFallbackMale.bin in miscload.big) names, for each slot of the body
# and the board (Arm, Feet, Hair, Organ, OuterTorso, Pants, Rostral, SkateBoard, SkateTruck,
# SkateWheel, ...), an asset with its models by level of detail, each model's id and the textures
# of its material by channel. The models are RW4 arenas in createacharacter.big
# (createacharacter/model/cas_db/<slot>/0x<id>.rx2), the textures beside them
# (createacharacter/texture/0x<id>.rx2).
#
# The recipe (big-endian, after a 16-byte wrapper): its name's length at 7 and the name, its kind,
# then lists: a list's name, its asset count, and per asset its 64-bit id, its model count and
# 37-byte model blocks (the level of detail, the arena's id, the model's id at 9, the material's
# at 25, the texture loops at 20, the texture count last), each followed by its textures (a
# channel's name and the texture's id) and the extra loops' textures.
#
# A character's vertices keep their place as four signed shorts: the position is twice the
# normalized value, raised 0.8 m (the body stands on y = 0, facing +z).

import ea
import graphics.shaders
import rw4
import xbox
import fs

pub type RecipePart:
	slot str
	modelId i64
	textures rw4.ChannelTexture[]

# the slots worn by the fallback skater (the recipe also lists some it leaves empty)
wornSlots = [
	"Arm",
	"Feet",
	"Hair",
	"Organ",
	"OuterTorso",
	"Pants",
	"Rostral",
	"SkateBoard",
	"SkateTruck",
	"SkateWheel"
]

# The level-0 model of each slot the recipe fills, or why it cannot be read.
pub fn readRecipe(wrapped u8[]) RecipePart[] ? str:
	if wrapped.len < 64: return "a recipe too short"
	d = wrapped[16..]
	nameLength = i64(d[7])
	at = 0x18 + nameLength
	lists = i64(d[at - 1])
	out = []
	loop lists:
		slotLength = i64(d[at + 3])
		slotBytes = []
		slotBytes.extend(d[at + 4..at + 4 + slotLength])
		slot = str(move slotBytes)
		at += 8 + slotLength
		assets = i64(d[at - 1])
		loop assets:
			models = i64(d[at + 11])
			at += 12
			for m in 0..models:
				block = at
				modelId = d.i64be(block + 9)
				loops = i64(d[block + 0x14])
				count = i64(d[block + 0x24])
				at += 0x25
				textures = []
				loop count:
					channelLength = i64(d[at + 3])
					channel = []
					channel.extend(d[at + 4..at + 4 + channelLength])
					textures.push(
						rw4.ChannelTexture(
							str(move channel),
							d.i64be(at + 4 + channelLength)
						)
					)
					at += 12 + channelLength
				loop (loops - 1).max(0):
					at += 0x10
					extra = i64(d[at - 1])
					loop extra:
						at += 12 + i64(d[at + 3])
				if m == 0 and slot in wornSlots:
					out.push(RecipePart(slot = slot.copy(), modelId, textures))
	out

# a part of the skater ready to draw: triangles of position, normal and texture place
pub type SkaterMesh:
	slot str
	color i64   # the diffuse texture's id
	tint f32[]   # r, g, b the texture is multiplied by
	alphaTest bool
	vertices u8[]   # the bytes of graphics.shaders.SkaterVertex values

pub type Skater:
	meshes SkaterMesh[]
	textures WorldTexture[]

# skin and hair are grey in their textures and take the recipe's colors: the fallback's
skinTint = [0.72, 0.57, 0.49]
hairTint = [0.30, 0.22, 0.15]

# The fallback skater decoded from the disc, or why he cannot be.
pub fn decodeSkater(disc xbox.Disc) Skater ? str:
	misc = try disc.openBig("data/big/miscload.big")
	parts = try readRecipe(try misc.readBigFile("data/cacrecipes/SavedRecipeFallbackMale.bin"))
	cac = try disc.openBig("data/content/createacharacter.big")
	meshes = []
	wanted i64[] = []
	for part in parts:
		path = "data/content/createacharacter/model/cas_db/{part.slot}/0x{ea.hex64(part.modelId).lower()}.rx2"
		arena = try rw4.openArena(try cac.readBigFile(path))
		model = try arena.readModel()
		color = 0
		for t in part.textures:
			if t.channel == "diffuse":
				color = t.id
		if color != 0 and color not in wanted:
			wanted.push(color)
		tint = skinTint if part.slot == "Arm" or part.slot == "Rostral"
			else hairTint if part.slot == "Hair"
			else [1.0, 1.0, 1.0]
		for m in model.meshes:
			vertices = []
			m.characterVertices(part.slot.startsWith("Skate"), vertices)
			meshes.push(
				SkaterMesh(
					slot = part.slot.copy(),
					color,
					tint = tint.map(f32(it)),
					alphaTest = part.slot == "Hair",
					vertices
				)
			)
	textures = []
	for id in wanted:
		arena = try rw4.openArena(
			try ea.readBigFile(
				cac,
				"data/content/createacharacter/texture/0x{ea.hex64(id).lower()}.rx2"
			)
		)
		decoded = arena.arenaTextures()
		if not decoded.isEmpty:
			if move decoded[0].image is img:
				textures.push(WorldTexture(id, image = img))
	Skater(meshes, textures)

# A character mesh's triangles as the shader's vertices' bytes, its positions put back in meters. The
# board's parts are turned a quarter about y (its nose from +z to +x) so he stands across it, his
# left foot forward, as a regular skater rides.
fn characterVertices(m rw4.ModelMesh, board bool, mut out u8[]):
	quantized = false
	for e in m.elements:
		if e.usage == rw4.usagePosition and e.format == 26:
			quantized = true
	v = m.vertices
	vertices = []
	for i in m.indices:
		scale = 2.0 if quantized else 1.0
		p = v.position[i]
		x = p.x * scale
		y = p.y * scale + (0.8 if quantized else 0.0)
		z = p.z * scale
		n = v.normal[i]
		uv = v.uv[i]
		vertices.push(shaders.SkaterVertex(
			position = Vec3(z if board else x, y, -x if board else z),
			normal = Vec3(n.z if board else n.x, n.y, -n.x if board else n.z),
			uv = Vec3(uv.x, uv.y, 0.0), spare = 0.0))
	out.extend(vertices.rawBytes())

# ---------- the prepared file ----------

skaterVersion = 3

# the skater written to `path`
pub fn saveSkater(s Skater, path str) ? fs.Error:
	out = PackedParts.pack("ZK3S", skaterVersion, [], [])
	out.extend(textureFiles(s.textures).toBytes())
	out.extend(s.meshes.toBytes())
	try fs.writeBytes(path, out)

# the skater prepared at `path`, or why he cannot be read
pub fn loadSkater(path str) Skater ? str:
	text, bodyAt = try packedFile(path, "ZK3S", skaterVersion)
	u = Reader(d = text.bytes(), at = bodyAt)
	textures = u.readTextures()
	meshes = SkaterMesh[].fromBytes(u)
	if u.short: return "{path} is cut short"
	Skater(meshes, textures)

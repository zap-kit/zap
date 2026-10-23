# A model flattened into what a renderer draws: each shape the game shows (not hidden, not an
# EditorMarker), its vertices moved by the product of the node transforms from the root down to it
# (Skyrim's units, Z up), with the textures and the material numbers it is drawn with.

pub type Part:
	name str
	transform Mat4   # the shape's to the model's space, already applied to positions and normals
	positions Vec3[]
	normals Vec3[]
	tangents Vec3[]   # as the file names them, none when it keeps none
	bitangents Vec3[]
	uvs Vec2[]   # the material's offset and scale applied
	colors Vec4[]   # none when the material does not read them
	indices u32[]
	diffuse str   # texture paths as the model gives them ("textures\clutter\x.dds"), "" for none
	normal str
	alpha Alpha
	twoSided bool
	glossiness f32
	specularStrength f32   # 0 when the material has no highlight
	shading Shading
	lit LitMaterial?   # a lit material's fields, which its shading and highlight come from
	effect Effect?   # an effect shader's (fire, glow, dust in a beam): drawn unlit
	billboard Billboard?   # under a billboard node: turned by the game to the camera each frame
	ancestors i64[] = []   # the blocks of the nodes it hangs under, the root first
	skinned bool
	weights f32[]   # four per vertex when skinned
	bones i64[]   # four per vertex, indices into boneNames
	boneNames str[]   # the skeleton's nodes the bones are
	skinToBone Mat4[]   # each bone's, from the positions' space to the bone's in the bind pose

# the billboard node a part is under: its mode (nodes.zap) and its transform to the model's space,
# whose turn the game replaces each frame by one toward the camera
pub type Billboard:
	mode i64
	pivot Mat4

# What an effect shader draws with: its texture's grey read through a palette when it names one
# (its color, its alpha or both), the palette's row being the base color's red (which the game
# animates); else the base color times its scale. It fades by the angle it is seen at.
pub type Effect:
	palette str   # "" for none
	paletteColor bool
	paletteAlpha bool
	baseColor Vec4
	scale f32
	falloff Vec4   # where fading starts and stops (cosines of the angle to the eye), the opacities there
	vertexColors bool   # the vertex colors read
	vertexAlpha bool   # their alpha read
	uvOffset Vec2
	uvScale Vec2
	tracks Track[]   # what its controllers animate (controllers.zap's effect variables)
	lighting f32 = 0.0   # how far the cell's light at it colors it (0: not lit)
	soft f32 = 0.0   # over how much depth it fades in where it meets what is behind it (0: hard)
	clamp i64 = 3   # its texture's addressing: 0 clamped both ways, 1 only u, 2 only v, 3 wrapped
	external bool = false   # its light's color is its reference's emittance source's, else white

# a material's flags 1: a highlight; the vertex colors' alpha; an effect's grey through a palette
# (color, alpha); its falloff; an effect faded where it meets what is behind it
flagSpecular = 0x1
flagVertexAlpha = 0x8
flagPaletteColor = 0x10
flagPaletteAlpha = 0x20
flagFalloff = 0x40
flagSoftEffect = 0x4000_0000
# a material's flags 1 of a surface drawn as a distortion of what is behind it (heat over a fire)
flagRefraction = 0x8000
flagFireRefraction = 0x1_0000
# a material's flags 2: the vertex colors read; an effect lit by the cell's light
flagVertexColors = 0x20
flagEffectLighting = 0x4000_0000

# no fading whatever the angle
noFalloff = Vec4(1.0, 0.0, 1.0, 1.0)

type Material:
	diffuse str = ""
	normal str = ""
	twoSided bool = false
	glossiness f32 = 0.0
	specularStrength f32 = 0.0
	uvOffset Vec2 = Vec2(0.0, 0.0)
	uvScale Vec2 = Vec2(1.0, 1.0)
	colors bool = false
	effect Effect? = none
	shading Shading = Shading()
	lit LitMaterial? = none

# the paths of the texture set at block i, none when there is none
fn setPaths(n Nif, i i64) str[]:
	if i < 0 or i >= n.blocks.len: return []
	match n.blocks[i]:
		TextureSetBlock(paths): paths.copy()
		_: []

# what the controllers from block `first` on animate of a shader
fn shaderTracks(n Nif, first i64):
	out = []
	for c in n.controllerChain(first):
		if c.variable < 0: continue
		if n.trackOf(c.interpolator, c.variable, c.timing) is t: out.push(t)
	out

fn effectOf(n Nif, m EffectShader):
	color = (m.flags1 & flagPaletteColor) != 0
	alpha = (m.flags1 & flagPaletteAlpha) != 0
	Effect(
		palette = m.greyscaleTexture.copy() if color or alpha else "",
		paletteColor = color,
		paletteAlpha = alpha,
		baseColor = m.baseColor,
		scale = m.baseColorScale,
		falloff = m.falloff if (m.flags1 & flagFalloff) != 0 else noFalloff,
		vertexColors = (m.flags2 & flagVertexColors) != 0,
		vertexAlpha = (m.flags1 & flagVertexAlpha) != 0,
		uvOffset = m.uvOffset,
		uvScale = m.uvScale,
		tracks = n.shaderTracks(m.controller),
		lighting = m.lightingInfluence if (m.flags2 & flagEffectLighting) != 0 else 0.0,
		soft = m.softDepth if (m.flags1 & flagSoftEffect) != 0 else 0.0,
		clamp = m.clampMode,
		external = (m.flags1 & flagExternalEmittance) != 0
	)

fn materialOf(n Nif, i i64):
	if i < 0 or i >= n.blocks.len: return Material()
	match n.blocks[i]:
		LightingBlock(m):
			lit = LitMaterial(shader = m.copy(), paths = n.setPaths(m.textureSet))
			Material(
				diffuse = lit.slotPath(slotDiffuse),
				normal = lit.slotPath(slotNormal),
				twoSided = (m.flags2 & flagDoubleSided) != 0,
				glossiness = m.glossiness,
				specularStrength = lit.specularOf(),
				uvOffset = m.uvOffset,
				uvScale = m.uvScale,
				colors = (m.flags2 & flagVertexColors) != 0,
				shading = lit.shadingOf(),
				lit
			)
		# a sky object keeps its vertex colors (the dome's gradient weights) and draws both sides
		SkyBlock(m):
			Material(
				diffuse = m.sourceTexture.copy(),
				twoSided = true,
				colors = true,
				uvOffset = m.uvOffset,
				uvScale = m.uvScale
			)
		# an effect's UV transform is animated: its parts keep their own UVs
		EffectBlock(m):
			Material(
				diffuse = m.sourceTexture.copy(),
				twoSided = (m.flags2 & flagDoubleSided) != 0,
				colors = (m.flags2 & flagVertexColors) != 0 or (m.flags1 & flagVertexAlpha) != 0,
				effect = n.effectOf(m)
			)
		_: Material()

# whether the material at block i distorts what is behind it: drawn by nothing here
fn refracts(n Nif, i i64):
	if i < 0 or i >= n.blocks.len: return false
	flags = match n.blocks[i]:
		LightingBlock(m): m.flags1
		EffectBlock(m): m.flags1
		_: 0
	(flags & (flagRefraction | flagFireRefraction)) != 0

fn alphaOf(n Nif, i i64):
	if i < 0 or i >= n.blocks.len: return Alpha()
	match n.blocks[i]:
		AlphaBlock(a): a.copy()
		_: Alpha()

fn dataBlock(n Nif, i i64):
	if i < 0 or i >= n.blocks.len: return Geometry()
	match n.blocks[i]:
		DataBlock(g): g.copy()
		_: Geometry()

# a shape's own geometry, its data block's, or for a skinned shape without vertices its skin
# partition's
fn geometryOf(n Nif, shape Shape):
	if shape.data >= 0: return n.dataBlock(shape.data)
	if not shape.geometry.indices.isEmpty or shape.skin < 0 or shape.skin >= n.blocks.len:
		return shape.geometry.copy()
	match n.blocks[shape.skin]:
		SkinBlock(skin):
			g = n.dataBlock(skin.partition)
			if g.positions.isEmpty: g.positions = shape.geometry.positions.copy()
			g
		_: shape.geometry.copy()

# the skin instance of a shape, none for a rigid one
fn skinOf(n Nif, shape Shape) Skin?:
	if shape.skin < 0 or shape.skin >= n.blocks.len: return none
	match n.blocks[shape.skin]:
		SkinBlock(skin): skin.copy()
		_: none

# the names of the nodes a skin's bones are, and each one's skin-to-bone matrix made to take the
# part's positions, which `world` has moved
fn bonesOf(n Nif, shape Shape, world Mat4) (str[], Mat4[]):
	skin = n.skinOf(shape) ?? return ([], [])
	names = skin.bones.map(n.blockName(it) if it >= 0 and it < n.blocks.len else "")
	toShape = world.inverseAffine()
	matrices = []
	if skin.data >= 0 and skin.data < n.blocks.len:
		if n.blocks[skin.data] is SkinDataBlock(data):
			matrices = data.bones.map(it @ toShape)
	(names, matrices)

fn partOf(n Nif, shape Shape, world Mat4, billboard Billboard?):
	g = n.geometryOf(shape)
	# a LOD shape's first level: its first triangles
	lod = shape.lodTriangles * 3
	if lod > 0 and lod < g.indices.len: g.indices = g.indices[..lod].copy()
	m = n.materialOf(shape.shader)
	boneNames, skinToBone = n.bonesOf(shape, world)
	Part(
		name = shape.av.name.copy(),
		transform = world,
		positions = g.positions.map(world.applyPoint(it)),
		normals = g.normals.map(world.applyDirection(it).normalized()),
		tangents = g.tangents.map(world.applyDirection(it).normalized()),
		bitangents = g.bitangents.map(world.applyDirection(it).normalized()),
		uvs = g.uvs.map(it * m.uvScale + m.uvOffset),
		colors = g.colors.copy() if m.colors else [],
		indices = g.indices.copy(),
		diffuse = m.diffuse.copy(),
		normal = m.normal.copy(),
		alpha = n.alphaOf(shape.alpha),
		twoSided = m.twoSided,
		glossiness = m.glossiness,
		specularStrength = m.specularStrength,
		shading = m.shading.copy(),
		lit = m.lit,
		effect = m.effect,
		billboard,
		skinned = not g.weights.isEmpty,
		weights = g.weights.copy(),
		bones = g.bones.copy(),
		boneNames,
		skinToBone
	)

# whether the game draws an object: not hidden by its flags, not the editor's marker
fn shown(av Av):
	(av.flags & flagHidden) == 0 and not av.name.startsWith("EditorMarker")

# an add-on node (BSValueNode): the ADDN index the game attaches there, and where it is
pub type AddOn:
	index i64
	place Mat4

# What the game draws of a model: its parts, its particle systems, and where each object it
# draws is (block -> its transform in the model's space).
pub type Drawn:
	parts Part[] = []
	systems Particles[] = []
	worlds {i64: Mat4} = {}
	found i64[] = []   # the particle systems met, made into systems once all is placed
	addOns AddOn[] = []

# the children of a node the game draws: a switch's active one, a LOD node's first, else all
fn drawnChildren(n Nif, i i64, node Node):
	if node.active < 0: return node.children.copy()
	k = 0 if n.blockKind(i) == "NiLODNode" else node.active
	[node.children[k]] if k < node.children.len else []

# block i and what is under it, under the transform `parent` (and the billboard node it is
# under, the outermost); `seen` stops a damaged file's loops
fn addParts(
	n Nif,
	i i64,
	parent Mat4,
	billboard Billboard?,
	path i64[],
	mut seen bool[],
	mut out Drawn
):
	if i < 0 or i >= n.blocks.len or seen[i]: return
	seen[i] = true
	match n.blocks[i]:
		NodeBlock(node):
			if not node.av.shown(): return
			world = parent @ node.av.transform
			out.worlds[i] = world
			if node.value >= 0: out.addOns.push(AddOn(index = node.value, place = world))
			turned = billboard
			if turned == none and node.billboardMode >= 0:
				turned = Billboard(mode = node.billboardMode, pivot = world)
			below = path.copy()
			below.push(i)
			for c in n.drawnChildren(i, node):
				n.addParts(c, world, turned, below, seen, out)
		ShapeBlock(shape):
			out.worlds[i] = parent @ shape.av.transform
			if not shape.av.shown() or n.refracts(shape.shader): return
			part = n.partOf(shape, out.worlds[i], billboard)
			part.ancestors = path.copy()
			if not part.indices.isEmpty: out.parts.push(part)
		ParticlesBlock(p):
			out.worlds[i] = parent @ p.av.transform
			if p.av.shown(): out.found.push(i)
		_: return

# where a root starts: a reference's placement takes the place of its root node's own transform
# (the game sets the root's local transform to the reference's), so that transform is undone
fn rootParent(n Nif, r i64):
	if r >= 0 and r < n.blocks.len:
		if n.blocks[r] is NodeBlock(node): return node.av.transform.inverseAffine()
	Mat4(1.0)

# what the game draws of a model, from its roots
pub fn drawModel(n Nif) Drawn:
	out = Drawn()
	seen = fill(n.blocks.len, false)
	for r in n.rootBlocks():
		n.addParts(r, n.rootParent(r), none, [], seen, out)
	for i in out.found:
		if n.blocks[i] is ParticlesBlock(p):
			out.systems.push(n.particlesOf(p, out.worlds[i], out.worlds))
	out

# the parts the game draws of a model
pub fn drawParts(n Nif) Part[]:
	n.drawModel().parts

# The tangents the file keeps for a normal map, none when it keeps none: the way u runs (what
# Bethesda's files name the bitangent) made square to the normal, w the sign of the way v runs
# (their tangent) against normal x tangent.
pub fn storedTangents(p Part) Vec4[]:
	if p.bitangents.len != p.positions.len or p.normals.len != p.positions.len: return []
	out = []
	for i, n in p.normals:
		u = p.bitangents[i] - n * (n @ p.bitangents[i])
		if u.length() < 1.0e-6: return []
		w f32 = -1.0 if n.cross(u) @ p.tangents[i] < 0.0 else 1.0
		out.push(u.normalized().withW(w))
	out

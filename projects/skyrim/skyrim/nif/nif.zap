# Skyrim Special Edition's models: NIF files of Gamebryo 20.2.0.7 (header.zap), their blocks read
# in order, each at the size the header gives it, so a block of a kind not read here is kept as
# Other and skipped whole. What a renderer draws of them is drawParts (parts.zap), what collides
# collisionShapes (collision.zap).

import engine

pub type Block:
	NodeBlock(node Node)
	ShapeBlock(shape Shape)
	DataBlock(geometry Geometry)   # NiTriShapeData, NiTriStripsData, NiSkinPartition
	SkinBlock(skin Skin)
	SkinDataBlock(data SkinData)
	LightingBlock(shader LightingShader)
	EffectBlock(shader EffectShader)
	SkyBlock(shader SkyShader)   # BSSkyShaderProperty
	TextureSetBlock(paths str[])
	AlphaBlock(alpha Alpha)
	ControllerBlock(controller Controller)
	InterpolatorBlock(interpolator Interpolator)
	KeysBlock(keys engine.Curve)   # NiFloatData, NiPosData, NiBoolData
	ParticlesBlock(system ParticleSystem)
	ParticleDataBlock(data ParticleData)
	ModifierBlock(modifier Modifier)   # a particle system's emitter or modifier
	CollisionBlock(flags i64, body i64)   # bhkCollisionObject and its kinds: the body's block
	BodyBlock(body RigidBody)
	HavokBlock(shape HavokShape)
	ConstraintBlock(constraint Constraint)
	FurnitureBlock(markers FurnitureMarker[])
	SequenceBlock(sequence SequenceBlockData)   # NiControllerSequence
	TransformInterpolatorBlock(interpolator TransformInterpolator)
	TransformDataBlock(data TransformData)
	Other

pub type Nif:
	header Header
	strings str[]
	blocks Block[]
	roots i64[]   # the footer's root blocks

# the type name of block i
pub fn blockKind(n Nif, i i64) str:
	n.header.types[n.header.blockKinds[i]].copy()

# the name of block i, "" for a block without one
pub fn blockName(n Nif, i i64) str:
	match n.blocks[i]:
		NodeBlock(node): node.av.name.copy()
		ShapeBlock(shape): shape.av.name.copy()
		LightingBlock(shader): shader.name.copy()
		EffectBlock(shader): shader.name.copy()
		_: ""

# the block of this type name at the stream, as far as it is read
fn readBlock(mut s Reader, names str[], kind str, bsVersion i64) Block:
	if kind in nodeKinds: return .NodeBlock(s.readNode(names, kind))
	if kind in shapeKinds: return .ShapeBlock(s.readTriShape(names, kind, bsVersion))
	if kind in oldShapeKinds: return .ShapeBlock(s.readOldShape(names, kind))
	if kind in havokKinds: return .HavokBlock(s.readHavokShape(kind))
	if kind in constraintKinds: return .ConstraintBlock(s.readConstraint(kind))
	if isController(kind): return .ControllerBlock(s.readController(names, kind))
	if s.readInterpolator(kind) is p: return .InterpolatorBlock(p)
	if s.readKeyData(kind) is k: return .KeysBlock(k)
	if s.readModifier(names, kind) is m: return .ModifierBlock(m)
	match kind:
		"NiTriShapeData": .DataBlock(s.readTriShapeData())
		"NiTriStripsData": .DataBlock(s.readTriStripsData())
		"BSLightingShaderProperty": .LightingBlock(s.readLightingShader(names))
		"BSEffectShaderProperty": .EffectBlock(s.readEffectShader(names))
		"BSSkyShaderProperty": .SkyBlock(s.readSkyShader(names))
		"BSShaderTextureSet": .TextureSetBlock(s.readStrings(s.u32()))
		"NiAlphaProperty": .AlphaBlock(s.readAlpha(names))
		"NiSkinInstance", "BSDismemberSkinInstance": .SkinBlock(s.readSkin())
		"NiSkinPartition": .DataBlock(s.readSkinPartition(bsVersion))
		"NiSkinData": .SkinDataBlock(s.readSkinData())
		"NiParticleSystem": .ParticlesBlock(s.readParticleSystem(names))
		"NiPSysData": .ParticleDataBlock(s.readParticleData())
		"bhkCollisionObject", "bhkBlendCollisionObject", "bhkSPCollisionObject":
			s.skip(4)   # the target
			flags = s.u16()
			.CollisionBlock(flags, s.i32())
		"bhkRigidBody", "bhkRigidBodyT": .BodyBlock(s.readRigidBody(kind == "bhkRigidBodyT"))
		"BSFurnitureMarker", "BSFurnitureMarkerNode": .FurnitureBlock(s.readFurniture())
		"NiControllerSequence": .SequenceBlock(s.readSequence(names))
		"NiTransformInterpolator": .TransformInterpolatorBlock(s.readTransformInterpolator())
		"NiTransformData": .TransformDataBlock(s.readTransformData())
		_: .Other

# the blocks a model's scene starts from: the footer's roots, the first block when it names none
fn rootBlocks(n Nif):
	n.roots.copy() if not n.roots.isEmpty else [0]

# the blocks and the string table of a NIF file's bytes, or why they cannot be read
pub fn readNif(bytes u8[]) Nif ? str:
	s = Reader(d = bytes)
	header = try s.readHeader()
	blocks = []
	at = header.start
	for i in 0..header.sizes.len:
		kind = header.types[header.blockKinds[i]]
		end = at + header.sizes[i]
		if end > bytes.len: return "block {i} ({kind}) runs past the end of the file"
		s.at = at
		s.end = end
		blocks.push(s.readBlock(header.strings, kind, header.bsVersion))
		if s.short: return "block {i} ({kind}) is cut short"
		at = end
	s.at = at
	s.end = bytes.len
	roots = s.readRefs()
	Nif(header, header.strings.copy(), blocks, roots)

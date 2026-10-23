# RenderWare 4 arenas as the Xbox 360 keeps them (.rx2, magic "\x89RW4xb2"): every asset of Skate 3
# is one. The header gives the dictionary (its entry count at 0x20, its offset at 0x30) and where
# the base resources start (0x44: the GPU data, vertices, indices and texels, laid after the CPU
# objects). A dictionary entry is 24 bytes: the object's offset (from the base resources' start
# for a base resource, else from the file's), a relocation word, its size, its alignment, its index
# in the type list and its type. Objects refer to one another by their dictionary index.

pub typeBaseResource = 0x0001_0031
pub typeTexture = 0x0002_00E8
pub typeVertexDescriptor = 0x0002_00E9
pub typeVertexBuffer = 0x0002_00EA
pub typeIndexBuffer = 0x0002_00EB
pub typeRenderModel = 0x00EB_0001
pub typeRenderMaterial = 0x00EB_0005
pub typeCollisionModel = 0x00EB_000A
pub typeTableOfContents = 0x00EB_000B
pub typeInstance = 0x00EB_000D
pub typeOptiMesh = 0x00EB_0023
pub typeClusteredMesh = 0x0008_0006
pub typeSkeleton = 0x00EB_0000

pub type ArenaEntry:
	at i64   # the object's offset in the arena's bytes
	size i64
	kind i64   # its type

pub type Arena:
	bytes u8[]
	entries ArenaEntry[]
	resourceBase i64

# The arena of these bytes with its dictionary read, or why it is not one.
pub fn openArena(move d u8[]) Arena ? str:
	if d.len < 0x60 or d[0] != 0x89 or not d.matchesAt(1, "RW4xb2"):
		return "not an Xbox 360 RW4 arena"
	count = i64(d.u32be(0x20))
	table = i64(d.u32be(0x30))
	base = i64(d.u32be(0x44))
	if table + count * 24 > d.len: return "an RW4 dictionary runs past its arena"
	entries = (0..count).map(i:
		e = table + i * 24
		kind = d.u32be(e + 20)
		ptr = i64(d.u32be(e))
		ArenaEntry(
			at = base + ptr if kind == typeBaseResource else ptr,
			size = d.u32be(e + 8),
			kind
		)
	)
	Arena(bytes = d, entries, resourceBase = base)

# the dictionary indices of the objects of a type, in order
pub fn objectsOf(a Arena, kind i64) i64[]:
	(0..a.entries.len).filter(a.entries[it].kind == kind)

# the name of a type, for listings
pub fn typeName(kind i64) str:
	match kind:
		0x0001_0031: "BaseResource"
		0x0002_00E8: "Texture"
		0x0002_00E9: "VertexDescriptor"
		0x0002_00EA: "VertexBuffer"
		0x0002_00EB: "IndexBuffer"
		0x0002_0081: "MeshHelper"
		0x00EB_0000: "RenderMeshData"
		0x00EB_0001: "RenderModelData"
		0x00EB_0003: "SimpleTriMeshData"
		0x00EB_0004: "SplineData"
		0x00EB_0005: "RenderMaterialData"
		0x00EB_0006: "CollisionMaterialData"
		0x00EB_0008: "VersionData"
		0x00EB_0009: "LocationDescData"
		0x00EB_000A: "CollisionModelData"
		0x00EB_000B: "TableOfContents"
		0x00EB_000D: "InstanceData"
		0x00EB_0019: "TriggerInstanceData"
		0x00EB_001D: "DmoData"
		0x00EB_0023: "RenderOptiMeshData"
		0x00EB_0024: "IrradianceData"
		0x0008_0006: "ClusteredMesh"
		0x0008_0001: "Volume"
		0x0008_0005: "BBox"
		_: "{kind:08X}"

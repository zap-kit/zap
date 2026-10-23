# The scene blocks: the fields every object of the scene has (NiObjectNET's name, extra data and
# controller, then NiAVObject's flags, transform and collision object), the nodes (NiNode and every
# block that extends it: BSFadeNode, BSLeafAnimNode, BSMultiBoundNode...), which add their
# children and effects, and the shapes' fields before their geometry (geometry.zap).

# the type names read as nodes; what a kind adds after NiNode's fields is skipped by size
nodeKinds = [
	"NiNode", "BSFadeNode", "BSLeafAnimNode", "BSTreeNode", "BSMultiBoundNode", "BSOrderedNode",
	"BSValueNode", "BSMasterParticleSystem", "BSDamageStage", "BSBlastNode", "BSDebrisNode",
	"NiBillboardNode", "NiSwitchNode", "NiLODNode", "NiBone", "BSRangeNode"
]

pub flagHidden = 1   # NiAVObject's flag of an object the game does not draw

# what every object of the scene has
pub type Av:
	name str
	extraData i64[]
	controller i64
	flags i64
	transform Mat4   # to its parent's space
	collision i64

pub type Node:
	av Av
	children i64[]
	effects i64[]
	billboardMode i64 = -1   # a NiBillboardNode's: how it turns to the camera (billboardModes)
	active i64 = -1   # a NiSwitchNode's (or NiLODNode's) child drawn, by its place in children
	value i64 = -1   # a BSValueNode's: the add-on node (ADDN) the game attaches there

# NiBillboardNode's modes (nif.xml's BillboardMode, the lowest 3 bits)
pub faceCamera = 0
pub rotateAboutUp = 1
pub rigidFaceCamera = 2
pub faceCenter = 3
pub rigidFaceCenter = 4
pub bsRotateAboutUp = 5

# NiObjectNET's fields: the name, the extra data, the controller
fn readNet(mut s Reader, names str[]):
	name = s.readName(names)
	extraData = s.readRefs()
	(name, extraData, s.i32())

fn readAv(mut s Reader, names str[]):
	name, extraData, controller = s.readNet(names)
	flags = s.u32()
	transform = s.readTransform()
	Av(name, extraData, controller, flags, transform, collision = s.i32())

# a node of this kind: NiBillboardNode adds its mode, NiSwitchNode (and NiLODNode, which extends
# it) its flags and the active child's index
fn readNode(mut s Reader, names str[], kind str):
	av = s.readAv(names)
	children = s.readRefs()
	node = Node(av, children, effects = s.readRefs())
	if kind == "NiBillboardNode": node.billboardMode = s.u16() & 7
	if kind == "NiSwitchNode" or kind == "NiLODNode":
		s.skip(2)
		node.active = s.u32()
	if kind == "BSValueNode": node.value = s.u32()
	node

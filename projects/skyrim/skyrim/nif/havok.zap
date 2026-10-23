# The Havok blocks of a model (niftools' nif.xml, Skyrim Special Edition's layouts): the collision
# object a node points to, the rigid body it holds (bhkRigidBody, bhkRigidBodyT) and the shapes
# under the body. Lengths are Havok's units (meters, 1 m = havokScale model units) except the
# vertices of bhkNiTriStripsShape's NiTriStripsData, which are the model's. collision.zap turns
# them into colliders.

import math

pub havokScale f32 = 69.99124908

# the rigid body of bhkRigidBodyCInfo2010, which Special Edition writes
pub type RigidBody:
	shape i64
	layer i64   # the collision filter's low byte (SkyrimLayer)
	filterFlags i64
	group i64
	moves bool   # bhkRigidBodyT: the translation and rotation apply
	translation Vec3
	rotation Quat
	linearVelocity Vec3
	angularVelocity Vec3
	inertia Mat3
	center Vec3   # the center of mass
	mass f32   # 0 for a body that never moves
	linearDamping f32
	angularDamping f32
	friction f32
	restitution f32
	maxLinearVelocity f32
	maxAngularVelocity f32
	penetrationDepth f32
	motionSystem i64   # hkMotionType: 6 keyframed, 7 fixed, others simulated
	deactivator i64
	solverDeactivation i64
	quality i64
	constraints i64[]

pub motionKeyframed = 6
pub motionFixed = 7

# triangles of a mesh shape: Havok units, the Havok material of each triangle
pub type HavokMesh:
	positions Vec3[] = []
	indices u32[] = []
	materials i64[] = []

pub type HavokShape:
	BoxShape(material i64, radius f32, halfExtents Vec3)   # radius: the shell around the shape
	SphereShape(material i64, radius f32)
	CapsuleShape(material i64, radius f32, a Vec3, b Vec3)
	ConvexShape(material i64, radius f32, vertices Vec3[], planes Vec4[])   # planes: n, -n.v - radius
	MultiSphereShape(material i64, spheres Vec4[])   # a sphere's center then its radius
	TransformShape(shape i64, transform Mat4)   # bhkConvexTransformShape, bhkTransformShape
	ListShape(shapes i64[])
	MoppShape(shape i64)   # bhkMoppBvTreeShape: its MOPP code is not read
	CompressedShape(data i64)
	StripsShape(material i64, data i64[])   # bhkNiTriStripsShape: NiTriStripsData blocks
	PackedShape(data i64)
	MeshData(mesh HavokMesh)   # bhkCompressedMeshShapeData, hkPackedNiTriStripsData

havokKinds = [
	"bhkBoxShape", "bhkSphereShape", "bhkCapsuleShape", "bhkConvexVerticesShape",
	"bhkMultiSphereShape", "bhkConvexTransformShape", "bhkTransformShape", "bhkListShape",
	"bhkMoppBvTreeShape", "bhkCompressedMeshShape", "bhkCompressedMeshShapeData",
	"bhkNiTriStripsShape", "bhkPackedNiTriStripsShape", "hkPackedNiTriStripsData"
]

fn readQuat(mut s Reader):
	v = s.vec4()
	Quat(v.x, v.y, v.z, v.w)

fn readVec4s(mut s Reader, n i64):
	out = []
	if not s.has(n * 16): return out
	loop n:
		out.push(s.vec4())
	out

# Havok's 3 x 3 matrix, rows of four floats (the fourth unused)
fn readHkMatrix3(mut s Reader):
	a = s.vec4().xyz
	b = s.vec4().xyz
	Mat3(a, b, s.vec4().xyz).transpose()

# Matrix44 as Havok keeps a transform: four columns, the last the translation
fn readMatrix44(mut s Reader):
	a = s.vec4()
	b = s.vec4()
	c = s.vec4()
	Mat4(a, b, c, s.vec4())

# bhkWorldObject's shape and filter, bhkEntity's response, then bhkRigidBodyCInfo2010 (whose own
# copy of the filter is skipped), the constraints and the body flags
fn readRigidBody(mut s Reader, moves bool):
	shape = s.i32()
	layer = s.u8()
	filterFlags = s.u8()
	group = s.u16()
	s.skip(20 + 4 + 20)   # the world object's info, the entity's, the info's filter and response
	translation = s.vec4().xyz
	rotation = s.readQuat()
	linearVelocity = s.vec4().xyz
	angularVelocity = s.vec4().xyz
	inertia = s.readHkMatrix3()
	center = s.vec4().xyz
	mass = s.f32()
	linearDamping = s.f32()
	angularDamping = s.f32()
	s.skip(8)   # the time and gravity factors
	friction = s.f32()
	s.skip(4)   # the rolling friction multiplier
	restitution = s.f32()
	maxLinearVelocity = s.f32()
	maxAngularVelocity = s.f32()
	penetrationDepth = s.f32()
	motionSystem = s.u8()
	deactivator = s.u8()
	solverDeactivation = s.u8()
	quality = s.u8()
	s.skip(4 + 12)   # remove level, response flags, shape keys, PPU; unused
	RigidBody(
		shape, layer, filterFlags, group, moves, translation, rotation, linearVelocity,
		angularVelocity, inertia, center, mass, linearDamping, angularDamping, friction,
		restitution, maxLinearVelocity, maxAngularVelocity, penetrationDepth, motionSystem,
		deactivator, solverDeactivation, quality, constraints = s.readRefs()
	)

# bhkConvexShape's material and shell radius, then what each kind adds
fn readConvexShape(mut s Reader, kind str) HavokShape:
	material = s.u32()
	radius = s.f32()
	match kind:
		"bhkSphereShape": .SphereShape(material, radius)
		"bhkBoxShape":
			s.skip(8)
			.BoxShape(material, radius, s.vec3())
		"bhkCapsuleShape":
			s.skip(8)
			a = s.vec4()
			b = s.vec4()
			.CapsuleShape(material, a.w, a.xyz, b.xyz)
		_:
			s.skip(24)   # the vertices' and normals' properties
			vertices = s.readVec4s(s.u32()).map(.xyz)
			.ConvexShape(material, radius, vertices, s.readVec4s(s.u32()))

# a shape block of one of havokKinds
fn readHavokShape(mut s Reader, kind str) HavokShape:
	match kind:
		"bhkSphereShape", "bhkBoxShape", "bhkCapsuleShape", "bhkConvexVerticesShape":
			s.readConvexShape(kind)
		"bhkConvexTransformShape", "bhkTransformShape":
			shape = s.i32()
			s.skip(16)   # the material, the radius, unused
			.TransformShape(shape, s.readMatrix44())
		"bhkListShape": .ListShape(s.readRefs())
		"bhkMoppBvTreeShape": .MoppShape(s.i32())
		"bhkCompressedMeshShape":
			s.skip(52)   # the target, the user data, the radii and scales
			.CompressedShape(s.i32())
		"bhkPackedNiTriStripsShape":
			s.skip(52)   # the user data, unused, the radii and scales
			.PackedShape(s.i32())
		"bhkNiTriStripsShape":
			material = s.u32()
			s.skip(44)   # the radius, unused, grow by, the scale
			.StripsShape(material, s.readRefs())
		"bhkMultiSphereShape":
			material = s.u32()
			s.skip(12)
			.MultiSphereShape(material, s.readVec4s(s.u32()))
		"bhkCompressedMeshShapeData": .MeshData(s.readCompressedMesh())
		_: .MeshData(s.readPackedStrips())

# hkPackedNiTriStripsData: triangles (three indices and the welding), the vertices (floats or
# halves), and the sub shapes, each a run of vertices with its filter and material
fn readPackedStrips(mut s Reader):
	mesh = HavokMesh()
	triangles = s.u32()
	if not s.has(triangles * 8): return mesh
	loop triangles:
		mesh.indices.extend([s.u16(), s.u16(), s.u16()])
		s.skip(2)
	vertices = s.u32()
	if s.u8() != 0:
		if not s.has(vertices * 6): return mesh
		for v in 0..vertices:
			at = s.at + v * 6
			mesh.positions.push(
				Vec3(s.d.f16le(at), s.d.f16le(at + 2), s.d.f16le(at + 4))
			)
		s.at += vertices * 6
	else:
		mesh.positions = s.readVec3s(vertices)
	ends = []
	materials = []
	end = 0
	loop s.u16():
		s.skip(4)
		end += s.u32()
		ends.push(end)
		materials.push(i64(s.u32()))
	for t in 0..triangles:
		first = i64(mesh.indices[t * 3])
		k = ends.findIndex(first < it) ?? ends.len - 1
		mesh.materials.push(materials[k] if k >= 0 else 0)
	mesh

# a chunk of a compressed mesh: its vertices are u16s times the quantization error from its
# translation, then moved by its transform; its indices run first as strips (their lengths
# given), the rest as plain triangles
fn readChunk(mut s Reader, error f32, transforms Mat4[], materials i64[], mut mesh HavokMesh):
	origin = s.vec4().xyz
	material = s.u32()
	s.skip(2)   # the reference to another chunk
	t = s.u16()
	place = transforms[t] if t < transforms.len else Mat4(1.0)
	coords = s.numbers(s.u32(), u16(0)).map(i64(it))
	indices = s.numbers(s.u32(), u16(0)).map(i64(it))
	strips = s.numbers(s.u32(), u16(0)).map(i64(it))
	s.skip(s.u32() * 2)   # the welding
	base = mesh.positions.len
	for v in 0..coords.len / 3:
		q = Vec3(f32(coords[v * 3]), f32(coords[v * 3 + 1]), f32(coords[v * 3 + 2]))
		mesh.positions.push(place.applyPoint(origin + q * error))
	triangles = []
	at = 0
	for n in strips:
		stripTriangles(indices[at..(at + n).min(len)].copy(), triangles)
		at += n
	while at + 3 <= indices.len:
		triangles.extend([u32(indices[at]), u32(indices[at + 1]), u32(indices[at + 2])])
		at += 3
	for k in triangles:
		mesh.indices.push(u32(base) + k)
	m = materials[material] if material < materials.len else 0
	loop triangles.len / 3:
		mesh.materials.push(m)

# bhkCompressedMeshShapeData: the quantization error, the materials (each with a filter), the
# chunks' transforms, the big triangles over their own vertices, then the chunks
fn readCompressedMesh(mut s Reader):
	mesh = HavokMesh()
	s.skip(16)   # the shape key's bits and masks
	error = s.f32()
	s.skip(32 + 2)   # the bounding box, the welding and material types
	loop 3:
		s.skip(s.u32() * 4)   # the unused 32, 16 and 8-bit materials
	materials = []
	loop s.u32():
		materials.push(i64(s.u32()))
		s.skip(4)
	s.skip(4)   # the named materials, none
	transforms = []
	loop s.u32():
		if s.short: break
		at = s.vec4().xyz
		transforms.push(Mat4.translation(at) @ Mat4.rotationOf(s.readQuat()))
	mesh.positions = s.readVec4s(s.u32()).map(.xyz)
	loop s.u32():
		if s.short: break
		mesh.indices.extend([s.u16(), s.u16(), s.u16()])
		material = s.u32()
		mesh.materials.push(materials[material] if material < materials.len else 0)
		s.skip(2)
	loop s.u32():
		if s.short: break
		s.readChunk(error, transforms, materials, mesh)
	mesh

# ---------- constraints ----------

# A constraint's frame in one body's space (Havok units): its pivot and three axes, the first the
# one it turns about or slides along. A hinge's: the axle, then the two axes square to it that
# measure its angle (the first the zero, the second the positive way); a ragdoll's: the twist,
# the plane and their cross product (nif.xml's motor axis); a prismatic's: the sliding, the
# rotation and the plane axes. A ball and socket's and a stiff spring's are their pivots alone.
pub type JointFrame:
	pivot Vec3
	axes Mat3   # columns

# what a constraint keeps between its two bodies, with its limits (radians, Havok units)
pub type Joint:
	BallJoint
	HingeJoint
	LimitedHingeJoint(minAngle f32, maxAngle f32, maxFriction f32)
	RagdollJoint(
		coneMax f32,
		planeMin f32,
		planeMax f32,
		twistMin f32,
		twistMax f32,
		maxFriction f32
	)
	PrismaticJoint(minDistance f32, maxDistance f32, friction f32)
	SpringJoint(length f32)

# a constraint block read (the wrappers' joint with their strength and threshold)
pub type Constraint:
	entityA i64   # the bodies' blocks
	entityB i64
	priority i64   # 1 the PSI solver's, 2 a time of impact's
	joint Joint
	a JointFrame   # in entityA's space
	b JointFrame   # in entityB's space
	strength f32 = 1.0   # a malleable constraint's: its share of a rigid one's stiffness
	threshold f32 = 0.0   # a breakable one's: the impulse it breaks at (0: never)
	removeWhenBroken bool = false

pub constraintKinds = [
	"bhkBallAndSocketConstraint", "bhkHingeConstraint", "bhkLimitedHingeConstraint",
	"bhkPrismaticConstraint", "bhkRagdollConstraint", "bhkStiffSpringConstraint",
	"bhkMalleableConstraint", "bhkBreakableConstraint"
]

# hkConstraintType's numbers, which name the joint a wrapper holds
wrappedKinds = {
	0: "bhkBallAndSocketConstraint",
	1: "bhkHingeConstraint",
	2: "bhkLimitedHingeConstraint",
	6: "bhkPrismaticConstraint",
	7: "bhkRagdollConstraint",
	8: "bhkStiffSpringConstraint"
}

fn pivotFrame(pivot Vec3):
	JointFrame(pivot, axes = Mat3(1.0))

# three axes then the pivot, as nif.xml lays out a frame since 20.2.0.7
fn readFrame(mut s Reader):
	first = s.vec4().xyz
	second = s.vec4().xyz
	third = s.vec4().xyz
	JointFrame(pivot = s.vec4().xyz, axes = Mat3(first, second, third))

# bhkConstraintMotorDesc: its type, then a position, velocity or spring motor (not simulated)
fn skipMotor(mut s Reader):
	match s.u8():
		1: s.skip(25)
		2: s.skip(18)
		3: s.skip(17)
		_: return

# the joint of this kind (constraintKinds' first six) and its two frames
fn readJoint(mut s Reader, kind str) (Joint, JointFrame, JointFrame):
	match kind:
		"bhkBallAndSocketConstraint", "bhkStiffSpringConstraint":
			a = pivotFrame(s.vec4().xyz)
			b = pivotFrame(s.vec4().xyz)
			if kind == "bhkBallAndSocketConstraint": return (.BallJoint, a, b)
			(.SpringJoint(s.f32()), a, b)
		_:
			a = s.readFrame()
			b = s.readFrame()
			joint = match kind:
				"bhkHingeConstraint": Joint.HingeJoint
				"bhkLimitedHingeConstraint":
					min = s.f32()
					max = s.f32()
					Joint.LimitedHingeJoint(min, max, s.f32())
				"bhkRagdollConstraint":
					cone = s.f32()
					planeMin = s.f32()
					planeMax = s.f32()
					twistMin = s.f32()
					twistMax = s.f32()
					Joint.RagdollJoint(cone, planeMin, planeMax, twistMin, twistMax, s.f32())
				_:
					min = s.f32()
					max = s.f32()
					Joint.PrismaticJoint(min, max, s.f32())
			if kind != "bhkHingeConstraint": s.skipMotor()
			(joint, a, b)

# bhkConstraintCInfo: the count of entities (two), the two bodies and the priority
fn readDescriptor(mut s Reader):
	s.skip(4)
	entityA = s.i32()
	entityB = s.i32()
	(entityA, entityB, s.u32())

# A constraint block of constraintKinds: its descriptor, then its joint; a wrapper (malleable,
# breakable) then names the joint it wraps (hkConstraintType) and repeats the descriptor (its
# bodies left null) before it, and adds its strength or its threshold.
fn readConstraint(mut s Reader, kind str):
	entityA, entityB, priority = s.readDescriptor()
	wrapper = kind == "bhkMalleableConstraint" or kind == "bhkBreakableConstraint"
	inner = (wrappedKinds.get(i64(s.u32())) ?? "bhkBallAndSocketConstraint").copy() if wrapper
		else kind.copy()
	if wrapper: s.readDescriptor()
	joint, a, b = s.readJoint(inner)
	c = Constraint(entityA, entityB, priority, joint, a, b)
	if kind == "bhkMalleableConstraint": c.strength = s.f32()
	if kind == "bhkBreakableConstraint":
		c.threshold = s.f32()
		c.removeWhenBroken = s.u8() != 0
	c

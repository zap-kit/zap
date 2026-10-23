# The ragdoll a character's skeleton.hkx holds besides its skeleton (Havok 2010's classes, the
# layouts in layouts.zap): the hkaRagdollInstance (the ragdoll's own skeleton of fewer bones, a
# rigid body a bone), each hkpRigidBody (a capsule, its mass, inertia and center, its material,
# damping and collision filter, and its frame in the ragdoll's model space at the reference pose),
# the hkpConstraintInstances between them (hkpRagdollConstraintData, hkpLimitedHingeConstraintData:
# each body's frame and the limits), and the two hkaSkeletonMappers (mapper.zap). Lengths are
# Skyrim's units, as the file keeps them.

# a ragdoll body's frame in the ragdoll's model space, as the reference pose places it
pub type BodyFrame:
	translation Vec3
	turn Mat3   # columns

pub type RagdollBody:
	name str
	frame BodyFrame
	center Vec3   # the center of mass in the body's frame
	mass f32
	inertia Vec3   # the principal inertia, about the body's axes
	a Vec3   # the capsule's ends in the body's frame, and its radius
	b Vec3
	radius f32
	friction f32
	restitution f32
	linearDamping f32
	angularDamping f32
	filter i64   # the collision filter info: Havok's subsystem and the bone's parent
	part i64 = -1   # the bone's biped part, as the skeleton's NIF gives it (character.zap)
	deactivation i64   # its solver deactivation class (hkpSolverInfo's: 2 low)

# what a ragdoll constraint keeps: Havok's ragdoll limits (radians) or a limited hinge's
pub type RagdollLimits:
	ConeLimits(coneMax f32, planeMin f32, planeMax f32, twistMin f32, twistMax f32)
	HingeLimits(min f32, max f32)

# a constraint between two bodies (a the child, b the parent): each one's frame in its body's
# space (the pivot, then the twist or axle and the two axes square to it)
pub type RagdollJoint:
	name str
	a i64
	b i64
	pivotA Vec3
	axesA Mat3
	pivotB Vec3
	axesB Mat3
	limits RagdollLimits
	maxFriction f32   # the most torque its friction holds (N m)
	priority i64   # hkpConstraintPriority: 1 is the discrete step's (PSI), 2 and up the time of impact's
	motor RagdollMotor?   # the position motor its atom holds (a ragdoll's three share it)
	motorOn bool   # whether the atom switches it on (the file's constraints do not)

# hkpPositionConstraintMotor: the force limits and the spring of a joint driven toward a target
pub type RagdollMotor:
	minForce f32
	maxForce f32
	tau f32
	damping f32
	proportionalRecoveryVelocity f32
	constantRecoveryVelocity f32

pub type Ragdoll:
	skeleton Skeleton
	bodies RagdollBody[]
	joints RagdollJoint[]
	boneToBody i64[]
	toRagdoll SkeletonMapper   # the animation skeleton's pose to the ragdoll's
	toAnimation SkeletonMapper   # and back

fn vec3At(d ref u8[], at i64):
	Vec3(d.f32le(at), d.f32le(at + 4), d.f32le(at + 8))

# Havok's hkHalf: a float's high 16 bits
fn halfAt(d ref u8[], at i64):
	bits = [u8(0), u8(0), d[at], d[at + 1]]
	bits.f32le(0)

# three hkVector4 columns
fn columnsAt(d ref u8[], at i64):
	Mat3(vec3At(d, at), vec3At(d, at + 16), vec3At(d, at + 32))

fn bodyAt(p Packfile, at i64) RagdollBody ? str:
	d = p.d
	shape = p.target(at + bodyShape)
	if p.classAt(shape) != "hkpCapsuleShape":
		return "the ragdoll body {p.textAt(at + bodyName)} is a {p.classAt(shape)}, not a capsule"
	inverse = vec3At(d, at + bodyInverseInertia)
	inverseMass = d.f32le(at + bodyInverseInertia + 12)
	if inverseMass <= 0.0 or inverse.x <= 0.0 or inverse.y <= 0.0 or inverse.z <= 0.0:
		return "the ragdoll body {p.textAt(at + bodyName)} has no mass"
	RagdollBody(
		name = p.textAt(at + bodyName),
		frame = BodyFrame(
			translation = vec3At(d, at + bodyTranslation),
			turn = columnsAt(d, at + bodyTurn)
		),
		center = vec3At(d, at + bodyCenter),
		mass = 1.0 / inverseMass,
		inertia = Vec3(1.0 / inverse.x, 1.0 / inverse.y, 1.0 / inverse.z),
		a = vec3At(d, shape + capsuleA),
		b = vec3At(d, shape + capsuleB),
		radius = d.f32le(shape + capsuleRadius),
		friction = d.f32le(at + bodyFriction),
		restitution = d.f32le(at + bodyRestitution),
		linearDamping = halfAt(d, at + bodyLinearDamping),
		angularDamping = halfAt(d, at + bodyAngularDamping),
		filter = d.u32le(at + bodyFilter),
		deactivation = d[at + bodyDeactivation]
	)

# the position motor the constraint data points to, none without one
fn motorOf(p Packfile, data i64, kind str) RagdollMotor?:
	at = data + (motorPointers if kind == "hkpRagdollConstraintData" else hingeMotorPointer)
	m = p.target(at)
	if m < 0 or p.classAt(m) != "hkpPositionConstraintMotor": return none
	RagdollMotor(
		minForce = p.d.f32le(m + motorMinForce),
		maxForce = p.d.f32le(m + motorMinForce + 4),
		tau = p.d.f32le(m + motorMinForce + 8),
		damping = p.d.f32le(m + motorMinForce + 12),
		proportionalRecoveryVelocity = p.d.f32le(m + motorMinForce + 16),
		constantRecoveryVelocity = p.d.f32le(m + motorMinForce + 20)
	)

# the constraint instance at `at` between two of the ragdoll's bodies (at their addresses)
fn jointAt(p Packfile, at i64, bodies i64[]) RagdollJoint ? str:
	d = p.d
	data = p.target(at + instanceData)
	a = bodies.indexOf(p.target(at + instanceEntityA)) ??
		return "a constraint's body A is not the ragdoll's"
	b = bodies.indexOf(p.target(at + instanceEntityB)) ??
		return "a constraint's body B is not the ragdoll's"
	kind = p.classAt(data)
	limits = match kind:
		"hkpRagdollConstraintData":
			RagdollLimits.ConeLimits(
				d.f32le(data + ragdollConeMax),
				d.f32le(data + ragdollPlaneMin),
				d.f32le(data + ragdollPlaneMax),
				d.f32le(data + ragdollTwistMin),
				d.f32le(data + ragdollTwistMax)
			)
		"hkpLimitedHingeConstraintData":
			RagdollLimits.HingeLimits(d.f32le(data + hingeMin), d.f32le(data + hingeMax))
		_: return "a ragdoll constraint of {kind}, which is not read"
	friction = d.f32le(
		data + (ragdollFriction if kind == "hkpRagdollConstraintData" else hingeFriction)
	)
	RagdollJoint(
		name = p.textAt(at + instanceName),
		a,
		b,
		pivotA = vec3At(d, data + transformA + 48),
		axesA = columnsAt(d, data + transformA),
		pivotB = vec3At(d, data + transformB + 48),
		axesB = columnsAt(d, data + transformB),
		limits,
		maxFriction = friction,
		priority = d[at + instancePriority],
		motor = p.motorOf(data, kind),
		motorOn = d[data + motorAtom + 2] != 0
	)

# The ragdoll of a character's skeleton.hkx: its instance at the root, with the mappers between
# its skeleton and the animation container's first skeleton; or why it has none.
pub fn readRagdoll(bytes u8[]) Ragdoll ? str:
	p = try openPackfile(bytes)
	instances = p.rootObjectsOf("hkaRagdollInstance")
	if instances.isEmpty or instances[0] < 0: return "no hkaRagdollInstance at the root"
	at = instances[0]
	container = try p.animationContainer()
	skeletons = try p.containerList(container, containerSkeletons)
	if skeletons.isEmpty: return "no animation skeleton"
	ragdollAt = p.target(at + ragdollSkeleton)
	skeleton = try p.skeletonAt(ragdollAt)
	bodyList = p.arrayAt(at + ragdollBodies)
	jointList = p.arrayAt(at + ragdollConstraints)
	map = p.arrayAt(at + ragdollBoneToBody)
	if not p.fits(bodyList, 8) or not p.fits(jointList, 8) or not p.fits(map, 4):
		return "the ragdoll's arrays run past the end"
	addresses = p.pointedBy(bodyList)
	bodies = []
	for b in addresses:
		bodies.push(try p.bodyAt(b))
	joints = []
	for c in p.pointedBy(jointList):
		joints.push(try p.jointAt(c, addresses))
	mappers = p.rootObjectsOf("hkaSkeletonMapper")
	toRagdoll = try p.mapperBetween(mappers, skeletons[0], ragdollAt)
	toAnimation = try p.mapperBetween(mappers, ragdollAt, skeletons[0])
	Ragdoll(
		skeleton,
		bodies,
		joints,
		boneToBody = (0..map.count).map(i64(p.d.i32le(map.element(it, 4)))),
		toRagdoll,
		toAnimation
	)

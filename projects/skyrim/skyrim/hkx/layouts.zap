# The members of the Havok 2010 classes Skyrim's files hold, where the 64-bit C++ layout puts them
# (pointers 8 bytes, an hkArray 16: pointer, size, capacity and flags; hkVector4 and hkQuaternion
# 16 bytes on 16). A class of hkReferenceObject starts its own members at 16, after the vtable
# pointer and the two 16-bit counts.

refObject = 16

# hkRootLevelContainer: an hkArray of NamedVariant (name, className, object)
variantSize = 24
variantClass = 8
variantObject = 16

# hkaAnimationContainer: hkArrays of pointers
containerSkeletons = refObject
containerAnimations = refObject + 16
containerBindings = refObject + 32

# hkaSkeleton: name, then hkArrays of i16 parents, hkaBone (name, hkBool lockTranslation) and
# hkQsTransform (translation, rotation, scale), then referenceFloats, floatSlots, localFrames
skeletonName = refObject
skeletonParents = refObject + 8
skeletonBones = refObject + 24
skeletonPose = refObject + 40
boneSize = 16
qsTransformSize = 48

# hkaAnimation: type, duration, the transform and float track counts, extractedMotion,
# annotationTracks
animationDuration = refObject + 4
animationTransformTracks = refObject + 8
animationFloatTracks = refObject + 12
animationAnnotationTracks = refObject + 24

# hkaAnnotationTrack: trackName, an hkArray of Annotation (time, then text at 8)
annotationTrackSize = 24
annotationTrackAnnotations = 8
annotationSize = 16
annotationText = 8

# hkaSplineCompressedAnimation after hkaAnimation's 56 bytes
splineFrames = 56
splineBlocks = 60
splineFramesPerBlock = 64
splineBlockDuration = 72
splineFrameDuration = 80
splineBlockOffsets = 88
splineData = 152

# hkaInterleavedUncompressedAnimation after hkaAnimation: hkArrays of hkQsTransform and of f32
interleavedTransforms = 56

# hkaAnimationBinding: originalSkeletonName, the animation, the hkArray of i16
# transformTrackToBoneIndices
bindingSkeletonName = refObject
bindingAnimation = refObject + 8
bindingTrackToBone = refObject + 16

# a bone's place relative to its parent
pub type Transform:
	translation Vec3
	rotation Quat
	scale Vec3

# the hkQsTransform at `at`: three 16-byte vectors, the rotation's x, y, z, w
fn qsTransformAt(d ref u8[], at i64):
	Transform(
		translation = Vec3(d.f32le(at), d.f32le(at + 4), d.f32le(at + 8)),
		rotation = Quat(x = d.f32le(at + 16), y = d.f32le(at + 20), z = d.f32le(at + 24), w = d.f32le(at + 28)),
		scale = Vec3(d.f32le(at + 32), d.f32le(at + 36), d.f32le(at + 40))
	)

# the objects an hkArray of pointers points to
fn pointedBy(p Packfile, a HkArray):
	(0..a.count).map(p.target(a.element(it, 8)))

# the objects of the root container's named variants of that class (none when it has none)
fn rootObjectsOf(p Packfile, className str):
	variants = p.arrayAt(p.root)
	found = []
	if not p.fits(variants, variantSize): return found
	for i in 0..variants.count:
		v = variants.element(i, variantSize)
		if p.textAt(v + variantClass) == className: found.push(p.target(v + variantObject))
	found

# the file's hkaAnimationContainer, or why it has none
fn animationContainer(p Packfile) i64 ? str:
	found = p.rootObjectsOf("hkaAnimationContainer")
	if found.isEmpty or found[0] < 0: return "no hkaAnimationContainer at the root"
	found[0]

# the objects the container's hkArray of pointers at `member` points to
fn containerList(p Packfile, container i64, member i64) i64[] ? str:
	a = p.arrayAt(container + member)
	if not p.fits(a, 8): return "an array of the animation container runs past the end"
	p.pointedBy(a)

# hkaRagdollInstance: hkArrays of hkpRigidBody* and hkpConstraintInstance*, the hkArray of i32
# boneToRigidBodyMap, then the ragdoll's hkaSkeleton*
ragdollBodies = refObject
ragdollConstraints = refObject + 16
ragdollBoneToBody = refObject + 32
ragdollSkeleton = refObject + 48

# hkpRigidBody (hkpEntity of 2010): its collidable's shape at 32 and filter info at 76, the name,
# the material's friction and restitution, and its hkpMaxSizeMotion at 336: the motion state's
# transform (three columns, then the translation), the swept transform's local center of mass,
# the damping (hkHalf: a float's high 16 bits) and the inverse inertia's diagonal with the inverse
# mass
bodyShape = 32
bodyFilter = 76
bodyName = 176
bodyFriction = 212
bodyRestitution = 216
bodyTurn = 368
bodyTranslation = 416
bodyCenter = 496
bodyLinearDamping = 532
bodyAngularDamping = 534
bodyInverseInertia = 544
bodyDeactivation = 540   # the motion state's deactivation class

# hkpCapsuleShape: the radius (hkpConvexShape's), then the two ends' hkVector4s
capsuleRadius = 32
capsuleA = 48
capsuleB = 64

# hkpConstraintInstance: its data, the two entities (A the child), the priority byte
instanceData = 24
instanceEntityA = 40
instanceEntityB = 48
instanceName = 80
instancePriority = 56

# the constraint datas' atoms: the local transforms (A then B: three columns and the
# translation each), then each kind's: the ragdoll's friction, twist, cone and plane limits, the
# limited hinge's friction and angle limit
transformA = 48
transformB = 112
motorAtom = 192   # the motor atom, a ragdoll's and a limited hinge's alike
motorPointers = 256
hingeMotorPointer = 208
motorMinForce = 24   # hkpPositionConstraintMotor: the force limits, then the spring
ragdollFriction = 296
ragdollTwistMin = 308
ragdollTwistMax = 312
ragdollConeMax = 332
ragdollPlaneMin = 348
ragdollPlaneMax = 352
hingeFriction = 224
hingeMin = 232
hingeMax = 236

# hkaSkeletonMapper: its hkaSkeletonMapperData's skeletons A and B, hkArrays of SimpleMapping
# (boneA, boneB, aFromBTransform at 16) and ChainMapping (start and end bones of A and B, then
# the start's and the end's aFromBTransform), unmappedBones (i16), keepUnmappedLocal
mapperSkeletonA = refObject
mapperSkeletonB = refObject + 8
mapperSimple = refObject + 16
mapperChains = refObject + 32
mapperUnmapped = refObject + 48
mapperKeepLocal = 128
simpleMappingSize = 64
chainMappingSize = 112
mappingTransform = 16
chainEndTransform = 64

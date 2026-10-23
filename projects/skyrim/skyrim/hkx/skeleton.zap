# A skeleton of a packfile's animation container (hkaSkeleton): its bones' names and parents and
# the reference pose, each bone's place relative to its parent.

pub type Bone:
	name str
	parent i64   # -1: a root
	pose Transform

pub type Skeleton:
	name str
	bones Bone[]

# the first skeleton of an HKX file, or why there is none
pub fn readSkeleton(bytes u8[]) Skeleton ? str:
	p = try openPackfile(bytes)
	container = try p.animationContainer()
	skeletons = try p.containerList(container, containerSkeletons)
	if skeletons.isEmpty or skeletons[0] < 0: return "no skeleton in the file"
	p.skeletonAt(skeletons[0])

fn skeletonAt(p Packfile, at i64) Skeleton ? str:
	parents = p.arrayAt(at + skeletonParents)
	bones = p.arrayAt(at + skeletonBones)
	pose = p.arrayAt(at + skeletonPose)
	if not p.fits(parents, 2) or not p.fits(bones, boneSize) or not p.fits(pose, qsTransformSize):
		return "a skeleton's arrays run past the end"
	if parents.count != bones.count or pose.count != bones.count:
		return "a skeleton of {bones.count} bones with {parents.count} parents and {pose.count} poses"
	list = []
	for i in 0..bones.count:
		parent = i64(p.d.i16le(parents.element(i, 2)))
		if parent >= i or parent < -1: return "bone {i}'s parent {parent} does not come before it"
		list.push(
			Bone(
				name = p.textAt(bones.element(i, boneSize)),
				parent,
				pose = qsTransformAt(p.d, pose.element(i, qsTransformSize))
			)
		)
	Skeleton(name = p.textAt(at + skeletonName), bones = list)

# the bone of that name, none when the skeleton has none
pub fn boneNamed(s Skeleton, name str) n64?:
	s.bones.findIndex(.name == name)

# hkaSkeletonMapper: how one skeleton's pose (A) gives another's (B), as Havok's
# hkaSkeletonMapper::mapPose does it in model space (the class as the 2010 SDK documents it).
# A simple mapping puts bone B where bone A is, moved by its aFromBTransform (B's model transform
# is A's times it); a chain mapping does that for the chain's start and end bones; a bone of B no
# mapping names keeps its local transform from B's pose before (keepUnmappedLocal) and follows its
# parent.

import math

pub type SimpleMapping:
	boneA i64
	boneB i64
	aFromB Transform

pub type ChainMapping:
	startA i64
	endA i64
	startB i64
	endB i64
	startAFromB Transform
	endAFromB Transform

pub type SkeletonMapper:
	simple SimpleMapping[]
	chains ChainMapping[]
	unmapped i64[]   # B's bones no mapping moves
	keepUnmappedLocal bool

fn boneAt(d ref u8[], at i64) i64:
	d.i16le(at)

# the mapper of `mappers` from skeleton `a` to skeleton `b` (their addresses), or why there is none
fn mapperBetween(p Packfile, mappers i64[], a i64, b i64) SkeletonMapper ? str:
	at = mappers.find(
		p.target(it + mapperSkeletonA) == a and p.target(it + mapperSkeletonB) == b
	) ??
		return "no skeleton mapper between the ragdoll and the animation skeleton"
	simple = p.arrayAt(at + mapperSimple)
	chains = p.arrayAt(at + mapperChains)
	unmapped = p.arrayAt(at + mapperUnmapped)
	if not p.fits(simple, simpleMappingSize) or not p.fits(chains, chainMappingSize) or
		not p.fits(unmapped, 2):
		return "a skeleton mapper's arrays run past the end"
	d = p.d
	SkeletonMapper(
		simple = (0..simple.count).map(m:
			e = simple.element(m, simpleMappingSize)
			SimpleMapping(
				boneA = boneAt(d, e),
				boneB = boneAt(d, e + 2),
				aFromB = qsTransformAt(d, e + mappingTransform)
			)
		),
		chains = (0..chains.count).map(m:
			e = chains.element(m, chainMappingSize)
			ChainMapping(
				startA = boneAt(d, e),
				endA = boneAt(d, e + 2),
				startB = boneAt(d, e + 4),
				endB = boneAt(d, e + 6),
				startAFromB = qsTransformAt(d, e + mappingTransform),
				endAFromB = qsTransformAt(d, e + chainEndTransform)
			)
		),
		unmapped = (0..unmapped.count).map(boneAt(d, unmapped.element(it, 2))),
		keepUnmappedLocal = d[at + mapperKeepLocal] != 0
	)

# a after b: b's transform taken into a's space (Havok's hkQsTransform::setMul)
pub fn times(a Transform, b Transform) Transform:
	Transform(
		translation = a.translation + a.rotation.rotate(a.scale * b.translation),
		rotation = (a.rotation @ b.rotation).normalized(),
		scale = a.scale * b.scale
	)

# the transform that undoes t (a scale alike on every axis, as the skeletons' are)
pub fn inverted(t Transform) Transform:
	r = t.rotation.inverse()
	s = Vec3(1.0 / t.scale.x, 1.0 / t.scale.y, 1.0 / t.scale.z)
	Transform(translation = r.rotate(-t.translation) * s, rotation = r, scale = s)

# each bone's transform in the skeleton's model space, given each one's local to its parent
pub fn modelPose(s Skeleton, locals Transform[]) Transform[]:
	out Transform[] = []
	for i, b in s.bones:
		out.push(locals[i].copy() if b.parent < 0 else out[b.parent].times(locals[i]))
	out

# each bone's transform local to its parent, given each one's in model space
pub fn localPose(s Skeleton, model Transform[]) Transform[]:
	(0..s.bones.len).map(i:
		p = s.bones[i].parent
		model[i].copy() if p < 0 else model[p].inverted().times(model[i])
	)

# B's pose in model space mapped from A's (`modelA`), B's locals before (`localsB`, which a bone
# no mapping moves keeps; by B's skeleton `b`)
pub fn mapPose(m SkeletonMapper, modelA Transform[], b Skeleton, localsB Transform[]) Transform[]:
	set = fill(b.bones.len, false)
	out = localsB.copy()
	for s in m.simple:
		out[s.boneB] = modelA[s.boneA].times(s.aFromB)
		set[s.boneB] = true
	for c in m.chains:
		out[c.startB] = modelA[c.startA].times(c.startAFromB)
		out[c.endB] = modelA[c.endA].times(c.endAFromB)
		set[c.startB] = true
		set[c.endB] = true
	for i, bone in b.bones:
		if set[i]: continue
		out[i] = localsB[i].copy() if bone.parent < 0 else out[bone.parent].times(localsB[i])
	out

# B's bones no mapping moves that lie between two it moves: each mapped bone's ancestors up to
# the next mapped one
pub fn betweenBones(m SkeletonMapper, b Skeleton) i64[]:
	mapped = fill(b.bones.len, false)
	for s in m.simple:
		mapped[s.boneB] = true
	for c in m.chains:
		mapped[c.startB] = true
		mapped[c.endB] = true
	out i64[] = []
	for i in 0..b.bones.len:
		if not mapped[i]: continue
		up = []
		p = b.bones[i].parent
		while p >= 0 and not mapped[p]:
			up.push(p)
			p = b.bones[p].parent
		if p < 0: continue
		for u in up:
			if u not in out: out.push(u)
	out

# Skinning on the CPU: a vertex posed is the sum over its four bones of weight * the bone's
# matrix in the pose * its skin-to-bone matrix * the vertex. A part's bones are the model's
# nodes, matched to the skeleton's bones by name.

import skyrim.hkx
import skyrim.nif

# the skeleton's bone of each of the part's bones, none for a name the skeleton lacks
pub fn partBones(part nif.Part, s hkx.Skeleton) n64?[]:
	part.boneNames.map(s.boneNamed(it))

# the names of the part's bones the skeleton lacks
pub fn unmatchedBones(part nif.Part, s hkx.Skeleton) str[]:
	part.boneNames.filter(s.boneNamed(it) == none).map(.copy())

# each of the part's bones' matrix in the pose `worlds` (the skeleton's), the identity for one
# the skeleton lacks
pub fn partBoneWorlds(part nif.Part, s hkx.Skeleton, worlds Mat4[]) Mat4[]:
	part.partBones(s).map(worlds.worldOf(it))

fn worldOf(worlds Mat4[], bone n64?):
	b = bone ?? return Mat4(1.0)
	worlds[b]

# the part's positions posed: boneWorld and skinToBone are by the part's bones
pub fn skinVertices(part nif.Part, boneWorld Mat4[], skinToBone Mat4[]) Vec3[]:
	moved = (0..boneWorld.len.min(skinToBone.len)).map(boneWorld[it] @ skinToBone[it])
	out = []
	for v, p in part.positions:
		sum = Vec3(0.0, 0.0, 0.0)
		total = 0.0
		for k in v * 4..v * 4 + 4:
			w = part.weights[k]
			bone = part.bones[k]
			if w <= 0.0 or bone >= moved.len: continue
			sum += moved[bone].applyPoint(p) * w
			total += w
		out.push(sum / total if total > 0.0 else p)
	out

# the farthest a posed vertex is from a bone it weighs on
pub fn largestReach(part nif.Part, posed Vec3[], boneWorld Mat4[]) f32:
	reach f32 = 0.0
	for v, p in posed:
		for k in v * 4..v * 4 + 4:
			bone = part.bones[k]
			if part.weights[k] <= 0.0 or bone >= boneWorld.len: continue
			reach = reach.max((p - boneWorld[bone].applyPoint(Vec3(0.0, 0.0, 0.0))).length())
	reach

# a copy of each worn model's parts with their positions posed by `worlds`, the skeleton's bones'
# matrices
pub fn posedParts(body BodyPart[], s hkx.Skeleton, worlds Mat4[]) nif.Part[]:
	out = []
	for b in body:
		for part in b.parts:
			posed = part.copy()
			posed.positions = part.skinVertices(part.partBoneWorlds(s, worlds), part.skinToBone)
			out.push(posed)
	out

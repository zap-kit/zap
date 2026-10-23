# A skeleton posed: each bone's transform, local to its parent, multiplied down the parent chain
# into its matrix in the skeleton's space (Skyrim's units, Z up). An animation's tracks move the
# bones its track-to-bone map names; the others keep the reference pose.

import math
import skyrim.hkx

fn matrixOf(t hkx.Transform):
	Mat4.transformOf(t.translation, t.rotation, t.scale)

# each bone's matrix in the skeleton's space, given each bone's transform local to its parent
pub fn localToWorld(s hkx.Skeleton, locals hkx.Transform[]) Mat4[]:
	out Mat4[] = []
	for i, b in s.bones:
		local = locals[i].matrixOf()
		out.push(local if b.parent < 0 else out[b.parent] @ local)
	out

# each bone's matrix in the skeleton's reference pose, the pose the models are bound in
pub fn bindPose(s hkx.Skeleton) Mat4[]:
	s.localToWorld(s.bones.map(.pose.copy()))

# each bone's matrix with the tracks' transforms (an animation's frame) on the bones trackToBone
# names
pub fn poseWorld(s hkx.Skeleton, trackToBone i64[], tracks hkx.Transform[]) Mat4[]:
	locals = s.bones.map(.pose.copy())
	for t in 0..tracks.len.min(trackToBone.len):
		bone = trackToBone[t]
		if bone >= 0 and bone < locals.len: locals[bone] = tracks[t].copy()
	s.localToWorld(locals)

# each bone's matrix at frame i of the animation
pub fn framePose(s hkx.Skeleton, a hkx.Animation, i i64) Mat4[]:
	s.poseWorld(a.trackToBone, a.frame(i))

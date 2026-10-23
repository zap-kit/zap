# The models an actor wears read into skinned parts. A body model in two (x_0.nif thin, x_1.nif
# heavy, the same vertices) is blended at the actor's weight, as the game's slider does.

import skyrim
import skyrim.nif

# one worn model: its skinned parts, each with its bones' names and skin-to-bone matrices
pub type BodyPart:
	slot str
	model str   # the archive key read (the heavy end's of a weighted pair)
	parts nif.Part[]

# a's positions and normals moved toward b's by t, where the two are the same mesh
fn blendPart(mut a nif.Part, b nif.Part, t f32):
	if a.positions.len != b.positions.len: return
	for i in 0..a.positions.len:
		a.positions[i] += (b.positions[i] - a.positions[i]) * t
	if a.normals.len != b.normals.len: return
	for i in 0..a.normals.len:
		a.normals[i] = (a.normals[i] + (b.normals[i] - a.normals[i]) * t).normalized()

fn skinnedParts(i skyrim.Install, key str) nif.Part[] ? str:
	model = try i.readModel(key)
	model.drawParts().filter(.skinned and not .boneNames.isEmpty)

# the keys a worn model is read from: a heavy end (x_1.nif) comes with its thin end (x_0.nif)
pub fn weightedKeys(key str) str[]:
	if key.endsWith("_1.nif"): return ["{key[..key.len - 6]}_0.nif", key.copy()]
	[key.copy()]

# The worn model with this key read at `weight` (0 the thin end, 1 the heavy one) when it has
# both ends, or why it cannot be read.
pub fn readBodyPart(i skyrim.Install, slot str, key str, weight f32) BodyPart ? str:
	parts = try i.skinnedParts(key)
	thinKey = key.weightedKeys()[0]
	if thinKey != key and i.installHas(thinKey):
		thin = try i.skinnedParts(thinKey)
		if thin.len == parts.len:
			for k in 0..thin.len:
				thin[k].blendPart(parts[k], weight)
			parts = thin
	BodyPart(slot = slot.copy(), model = key.copy(), parts)

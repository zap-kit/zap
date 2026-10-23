# Where the human characters' skeletons and animations lie in the archives.

import skyrim
import skyrim.hkx
import skyrim.nif

pub characterSkeleton = "meshes/actors/character/character assets/skeleton.hkx"
pub characterSkeletonModel = "meshes/actors/character/character assets/skeleton.nif"
femaleSkeletonModel = "meshes/actors/character/character assets female/skeleton_female.nif"
pub femaleSkeleton = "meshes/actors/character/character assets female/skeleton_female.hkx"
pub characterAnimations = "meshes/actors/character/animations/"
pub maleAnimations = "meshes/actors/character/animations/male/"
pub femaleAnimations = "meshes/actors/character/animations/female/"
pub characterBehaviors = "meshes/actors/character/behaviors/"
pub maleCharacter = "meshes/actors/character/characters/defaultmale.hkx"

# the human characters' skeleton, or why it cannot be read
pub fn readCharacterSkeleton(i skyrim.Install) hkx.Skeleton ? str:
	i.readSkeletonOf(false)

# the men's or the women's skeleton.hkx: its key and bytes, or why it cannot be read
fn skeletonFile(i skyrim.Install, female bool) (str, u8[]) ? str:
	key = (femaleSkeleton if female else characterSkeleton).copy()
	bytes = i.installRead(key) ?? return "{key} is in no archive"
	(key, bytes)

# the men's or the women's skeleton, or why it cannot be read
pub fn readSkeletonOf(i skyrim.Install, female bool) hkx.Skeleton ? str:
	key, bytes = try i.skeletonFile(female)
	hkx.readSkeleton(bytes) ?? return "{key}: {error}"

# The ragdoll of the men's or the women's skeleton, or why it cannot be read: its bodies' biped
# parts from the skeleton's NIF, whose node of each ragdoll body's bone ("Ragdoll_" and the bone's
# name) carries the body's filter.
pub fn readRagdollOf(i skyrim.Install, female bool) hkx.Ragdoll ? str:
	key, bytes = try i.skeletonFile(female)
	r = hkx.readRagdoll(bytes) ?? return "{key}: {error}"
	modelKey = femaleSkeletonModel if female else characterSkeletonModel
	model = i.installRead(modelKey) ?? return "{modelKey} is in no archive"
	parts = (nif.readNif(model) ?? return "{modelKey}: {error}").bipedParts()
	for k, b in r.bodies:
		r.bodies[k].part = parts.get(b.name.replace("Ragdoll_", "")) ?? -1
	r

# the male animation of this name ("mt_idle"), or why it cannot be read
pub fn readMaleAnimation(i skyrim.Install, name str) hkx.Animation ? str:
	i.readActorAnimation(name, false)

# The archive key of the animation of this name a man or a woman plays, as the behaviors find it:
# the sex's own (female/, male/), else the one both share (animations/), else a woman plays the
# man's; none when no archive has it.
pub fn actorAnimationKey(i skyrim.Install, name str, female bool) str?:
	dirs = [femaleAnimations, characterAnimations, maleAnimations] if female
		else [maleAnimations, characterAnimations]
	for dir in dirs:
		key = "{dir}{name}.hkx"
		if i.installHas(key): return key
	none

# the animation of this name a man or a woman plays (actorAnimationKey), or why it cannot be read
pub fn readActorAnimation(i skyrim.Install, name str, female bool) hkx.Animation ? str:
	key = i.actorAnimationKey(name, female) ?? return "{name}.hkx is in no archive"
	bytes = i.installRead(key) ?? return "{key} cannot be read"
	hkx.readAnimation(bytes) ?? return "{key}: {error}"

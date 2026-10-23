# Footsteps as the game sounds them: the clips the behavior graph plays carry text keys as their
# feet land ("FootLeft", "FootRight" in mt_walkforward and mt_runforward, "FootSprintLeft" in the
# sprint's), and a step sounds when the clip the graph plays most crosses one of its keys. The
# actor's footstep set (its feet's armor addon's SNDD: barefoot, light or heavy) gives, for the
# gait of the clip, the footstep (FSTP) of that key, whose impact data set gives the impact for
# the material of the floor under the foot (the scene's triangle there, its Havok material hashed
# to a MATT, its parents tried in turn), whose sound is the player's own (NAM1) or the NPCs'
# (SNAM), played at the feet.

import game
import engine.physics
import skyrim
import skyrim.actor
import skyrim.esm
import skyrim.hkx

# a text key of a foot landing: when in the clip (seconds) and its name
pub type FootKey:
	at f32
	tag str

# the foot keys of the locomotion clips of one sex, by the clip's name, and the clips' lengths
pub type StepKeys:
	clips {str: FootKey[]}
	lengths {str: f32}

# One actor's feet: its footstep set, whether it is the player, and the clip the graph played
# most last frame and how far into it.
pub type Feet:
	name str
	set esm.FootstepSet
	player bool
	clip str = ""
	time f32 = 0.0

# the clips that move the actor: the graph's locomotion and turns, which are the "mt_" ones
locomotionPrefix = "mt_"
# the weight from which the clip the graph plays is the one whose feet sound
leadWeight f32 = 0.3

# the foot keys and the length of the clip of this name a man or a woman plays, none when it
# cannot be read or has no key
fn footKeysOf(install skyrim.Install, name str, female bool) (FootKey[], f32)?:
	key = try install.actorAnimationKey(name, female)
	bytes = try install.installRead(key)
	t = hkx.readClipTimes(bytes) ?? return none
	feet = t.events.filter(.text.startsWith("Foot"))
	if feet.isEmpty: return none
	(feet.map(FootKey(at = .time, tag = .text.copy())), t.duration)

# The foot keys of the locomotion clips among `names` (a rig's), read from the install's clips of
# the sex.
pub fn stepKeysOf(install skyrim.Install, names str[], female bool) StepKeys:
	out = StepKeys(clips = {}, lengths = {})
	for name in names:
		if not name.startsWith(locomotionPrefix): continue
		if install.footKeysOf(name, female) is found:
			keys, length = found
			out.clips[name.copy()] = keys
			out.lengths[name.copy()] = length
	out

# The feet of an actor wearing `addons` (actor.wornAddons): their footstep set, the default one
# when they name none.
pub fn feetOf(mut b Book, name str, addons actor.WornAddon[], player bool) Feet:
	id = b.plugin.footstepSetOf(addons)
	if id == 0: id = b.plugin.formByEditorId("FSTS", "DefaultFootstepSet") ?? 0
	set = b.plugin.footstepSet(id) ??
		esm.FootstepSet(walk = [], run = [], sprint = [], sneak = [], swim = [])
	Feet(name = name.copy(), set, player)

# whether going from `from` to `to` through a cycle (forward, past its end) passes `at`
fn passes(from f32, to f32, at f32):
	if to >= from: return at > from and at <= to
	at > from or at <= to

# The Havok material under the feet, 0 when no triangle is there.
pub fn floorMaterial(mut s physics.Scene, feet Vec3) i64:
	t = s.triangleBelow(feet + Vec3(0, 0, 8), 64.0) ?? return 0
	s.materials[t]

# Plays the footstep of the key's tag in the gait's list on the floor's material; false when the
# set has no footstep for it or the material no impact.
fn playStep(mut f Feet, mut b Book, steps i64[], tag str, feet Vec3, material i64):
	for id in steps:
		step = b.plugin.footstep(id) ?? continue
		if step.tag.lower() != tag.lower(): continue
		impact = b.plugin.impactFor(step.impacts, material) ?? return false
		sound = b.plugin.impactSound(impact, f.player)
		where = b.plugin.material(material)?.editorId ?? "?"
		return b.playDescriptor(sound, feet, "{f.name} {tag} on {where}") != none
	false

# the footsteps of the gait a locomotion clip is: by its name in the graph
fn stepsOf(set esm.FootstepSet, clip str):
	name = clip.lower()
	if name.indexOf("sprint") != none: return set.sprint.copy()
	if name.indexOf("sneak") != none: return set.sneak.copy()
	if name.indexOf("run") != none: return set.run.copy()
	set.walk.copy()

# The feet one frame on: the clip the graph plays most (the animator's heaviest layer) sounds the
# footstep of each foot key it passed since last frame, on the floor under the body at `feet`.
# `materials`: the materials by their Havok hash (esm.materialsByHash).
pub fn stepFeet(
	mut f Feet,
	mut b Book,
	a game.Animator,
	feet Vec3,
	keys StepKeys,
	mut s physics.Scene,
	materials {i64: i64}
):
	if a.layers.isEmpty:
		f.clip = ""
		return
	lead = a.layers[0]
	if lead.weight < leadWeight or keys.clips.get(lead.clip) == none:
		f.clip = ""
		return
	length = keys.lengths.get(lead.clip) ?? 1.0
	phase = lead.time % length
	if lead.clip != f.clip:
		f.clip = lead.clip.copy()
		f.time = phase
		return
	from = f.time
	f.time = phase
	steps = f.set.stepsOf(lead.clip)
	for k in keys.clips.get(lead.clip) ?? []:
		if not passes(from, phase, k.at): continue
		material = materials.get(s.floorMaterial(feet)) ?? 0
		f.playStep(b, steps, k.tag, feet, material)

# The character's behavior graph as the game ships it: 0_master.hkx with every behavior file it
# refers to (and they to others), joined into one.

import skyrim
import skyrim.hkx

masterBehavior = "0_master.hkx"

# the character's graph, or why a file of it cannot be read
pub fn readCharacterGraph(i skyrim.Install) hkx.Graph ? str:
	files {str: hkx.Behavior} = {}
	pending = [masterBehavior]
	while not pending.isEmpty:
		name = (pending.pop() ?? break).copy()
		if files.get(name) != none: continue
		key = "{characterBehaviors}{name}"
		bytes = i.installRead(key) ?? return "{key} is in no archive"
		b = match hkx.readBehavior(bytes):
			found: found
			error: return "{key}: {error}"
		pending.extend(b.referencesOf())
		files[name] = b
	hkx.joinBehaviors(files, masterBehavior)

# the lengths in seconds of the male clips of these names, none for one the archives lack
pub fn clipDurations(i skyrim.Install, names str[]) {str: f32}:
	out {str: f32} = {}
	for name in names:
		key = i.actorAnimationKey(name, false) ?? continue
		bytes = i.installRead(key) ?? continue
		if hkx.readClipTimes(bytes) is t: out[name.copy()] = t.duration
	out

# the animations a graph's clips play, once each
pub fn clipNamesOf(g hkx.Graph) str[]:
	out str[] = []
	for n in g.nodes:
		if n.kind == .Clip and n.clip not in out: out.push(n.clip.copy())
	out

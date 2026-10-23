# How far an animation carries the actor: Skyrim keeps it out of the HKX files, in the
# behavior project's text files (meshes/animationdata/): the project's (defaultmale.txt) lists
# its clip generators (a name, the cache index of its motion, its playback speed, its crop, its
# events), the bound animations' (boundanims/anims_defaultmale.txt) the motion of each cache
# index: its duration, then translation keys (time, x, y, z: where the root is by then, from where
# the clip began) and rotation keys (time, x, y, z, w). A generator named as an HKX file
# ("MT_WalkForward", mt_walkforward.hkx) plays that file.

import math
import skyrim

pub animationData = "meshes/animationdata/"

# where a clip has carried the actor by each key's time, in the actor's own space (Y forward,
# Z up), from the clip's start
pub type Motion:
	duration f32
	times f32[]
	moves Vec3[]
	turnTimes f32[]
	turns Quat[]

fn linesOf(i skyrim.Install, key str) str[] ? str:
	bytes = i.installRead(key) ?? return "{key} is in no archive"
	str(move bytes).lines()

# the numbers of a line of words
fn numbersOf(line str):
	line.words().map(f32.parse(it) ?? 0.0)

# the cache index of each clip generator, by its name in lower case: after the project's files
# (their count, then one a line) and a 1, each generator's name, cache index, speed, crop start
# and end, its events (their count, then one a line) and a blank line
fn generators(lines str[]):
	out {str: i64} = {}
	at = 3 + (i64.parse(lines[1].trimmed()) ?? 0)
	while at + 5 < lines.len:
		name = lines[at].trimmed()
		index = i64.parse(lines[at + 1].trimmed()) ?? break
		out[name.lower()] = index
		at += 6 + (i64.parse(lines[at + 5].trimmed()) ?? 0)
		while at < lines.len and lines[at].trimmed() == "":
			at += 1
	out

# the motions of the bound animations' file by cache index
fn motions(lines str[]):
	out {i64: Motion} = {}
	at = 0
	while at + 2 < lines.len:
		index = i64.parse(lines[at].trimmed()) ?? break
		m = Motion(duration = f32.parse(lines[at + 1].trimmed()) ?? 0.0, times = [], moves = [],
			turnTimes = [], turns = [])
		at += 2
		count = i64.parse(lines[at].trimmed()) ?? 0
		for line in lines[at + 1..at + 1 + count]:
			v = numbersOf(line)
			m.times.push(v[0])
			m.moves.push(Vec3(v[1], v[2], v[3]))
		at += 1 + count
		count = i64.parse(lines[at].trimmed()) ?? 0
		for line in lines[at + 1..at + 1 + count]:
			v = numbersOf(line)
			m.turnTimes.push(v[0])
			m.turns.push(Quat(v[1], v[2], v[3], v[4]))
		at += 1 + count
		while at < lines.len and lines[at].trimmed() == "":
			at += 1
		out[index] = m
	out

# The motion of each of the clip generators `names` of the project ("defaultmale"), none for one
# it lacks, or why the project cannot be read.
pub fn readMotions(i skyrim.Install, project str, names str[]) Motion?[] ? str:
	clips = generators(try i.linesOf("{animationData}{project}.txt"))
	bound = motions(try i.linesOf("{animationData}boundanims/anims_{project}.txt"))
	out = []
	for name in names:
		found Motion? = none
		if bound.get(clips.get(name.lower()) ?? -1) is m: found = m.copy()
		out.push(found)
	out

# where the motion has carried the actor `t` seconds in (0..duration), from the clip's start
pub fn movedBy(m Motion, t f32) Vec3:
	before = Vec3(0, 0, 0)
	start = 0.0
	for k in 0..m.times.len:
		if t <= m.times[k]:
			share = (t - start) / (m.times[k] - start).max(1.0e-6)
			return before + (m.moves[k] - before) * share.clamp(0.0, 1.0)
		before = m.moves[k]
		start = m.times[k]
	before

# how fast the motion carries the actor on average, units a second
pub fn speedOf(m Motion) f32:
	m.movedBy(m.duration).length() / m.duration.max(1.0e-6)

# how far the motion has turned the actor `t` seconds in: radians clockwise seen from above (as a
# heading turns), its rotation keys' turn about Z eased from the one before
pub fn turnedBy(m Motion, t f32) f32:
	before = 0.0
	start = 0.0
	for k in 0..m.turnTimes.len:
		q = m.turns[k]
		angle = -2.0 * q.z.atan2(q.w)
		if t <= m.turnTimes[k]:
			share = ((t - start) / (m.turnTimes[k] - start).max(1.0e-6)).clamp(0.0, 1.0)
			return before + math.angleBetween(before, angle) * share
		before = angle
		start = m.turnTimes[k]
	before

# no motion: a clip that leaves the actor where it stands
pub fn stillMotion() Motion:
	Motion(duration = 0.0, times = [], moves = [], turnTimes = [], turns = [])

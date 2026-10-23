# The music as Skyrim's music system plays it (CommonLibSSE's BSIMusicType, BGSMusicTrack and
# their flags; xEdit's MUSC and MUST). Music types are asked for: the location's (an interior's
# own, XCMO, in place of the region's explore music) and those that come over it (combat, a
# discovery, a stinger); the one of the lowest priority number plays, the others wait. A type
# plays its tracks one after another, in their order (Maintain Track Order) or picked at random
# among those it has not played since it last played them all; it ends after one (Plays One
# Selection), or after all of them unless it cycles (Cycle Tracks). It fades in and out over its
# fade (WNAM) unless its transition is abrupt; a track lasts its duration (FLTV) or its file's
# length, a silent track its duration, a palette plays one of its tracks; the next starts as it
# ends. Each start and stop goes to the book's log, its why beginning with "music".
# Approximated: a type that plays over the others (Ducks Current Track) pauses them instead of
# lowering them by its ducking (the engine's music plays one song at a time); a track's finale,
# loops and cue points are not played.

import engine.audio
import skyrim.esm
import skyrim

pub type MusicPlayer:
	category i64   # the music's sound category (the default objects' MDSC)
	location i64 = 0   # the location's music type, 0 for none
	locationDone bool = false   # it played all it plays (a type that does not cycle)
	asked i64[] = []   # the types that come over it, in the order asked
	played {i64: i64[]} = {}   # by type: the tracks played since it last played them all
	current i64 = 0   # the type playing, 0 for none
	until f64 = 0.0   # when its track ends

pub fn newMusicPlayer(mut b Book) MusicPlayer:
	MusicPlayer(category = b.plugin.defaultObject("MDSC") ?? 0)

# The location's music type (an interior's XCMO): it plays while nothing comes over it.
pub fn setLocationMusic(mut m MusicPlayer, kind i64):
	if kind != m.location: m.locationDone = false
	m.location = kind

# A music type asked for over the location's (combat, a discovery).
pub fn askMusic(mut m MusicPlayer, kind i64):
	if kind not in m.asked: m.asked.push(kind)

# the type that should play: the lowest priority number, the latest asked of equal ones
fn leading(mut m MusicPlayer, mut b Book):
	best = 0
	bestPriority = 1 << 30
	kinds i64[] = [] if m.locationDone else [m.location]
	kinds.extend(m.asked)
	for kind in kinds:
		t = b.plugin.musicType(kind) ?? continue
		if t.priority <= bestPriority:
			best = kind
			bestPriority = t.priority
	best

fn musicLine(mut b Book, what str, key str, why str):
	b.log.push(LogLine(time = b.time, what = what.copy(), key = key.copy(), volume = 0.0,
		gain = 1.0, distance = -1.0, why = "music: {why}"))

# The track to play next of the type: in order, or at random among those not played since all were.
fn pickTrack(mut m MusicPlayer, mut b Book, t esm.MusicType) i64?:
	if t.tracks.isEmpty: return none
	done i64[] = (m.played.get(m.current) ?? []).copy()
	if done.len >= t.tracks.len:
		last = done[len - 1]
		done = []
		if t.tracks.len > 1 and (t.flags & esm.musicInOrder) == 0: done.push(last)
	left = t.tracks.filter(it not in done)
	if left.isEmpty: left = t.tracks.copy()
	pick = left[0] if (t.flags & esm.musicInOrder) != 0 else left[b.dice.nextInt(0, len)]
	done.push(pick)
	m.played[m.current] = done
	pick

# a palette's tracks resolved to one of its single or silent tracks
fn resolvedTrack(mut b Book, id i64) esm.Track?:
	at = id
	loop 4:
		t = try b.plugin.musicTrack(at)
		if t.kind != esm.trackPalette or t.tracks.isEmpty: return t
		at = t.tracks[b.dice.nextInt(0, len)]
	none

# Plays the track (streamed, at the music's volume), fading in over `fade`; its seconds.
fn playTrack(mut m MusicPlayer, mut b Book, t esm.Track, fade f32, kind str) f64:
	if t.kind == esm.trackSilent or t.file == "":
		b.musicLine(t.editorId, "", "{kind} is silent {t.duration:.1} s")
		return f64(t.duration)
	found = b.install.installSound(t.file) ?? ""
	bytes = b.install.installRead(found) ?? []
	length = audio.declaredSeconds(bytes) ?? 0.0
	seconds = f64(t.duration) if t.duration > 0.0 else length
	volume = b.categoryVolume(m.category)
	if not audio.playMusicBytes(bytes, looping = false, fade = fade, volume = volume):
		b.musicLine(t.editorId, t.file, "{kind}: {t.file} does not play")
		return 0.0
	b.log.push(LogLine(time = b.time, what = t.editorId.copy(), key = t.file.copy(), volume,
		gain = 1.0, distance = -1.0, why = "music: {kind} plays {seconds:.1} s"))
	seconds

# the type's next track started, fading in over `fade`; false when the type is done
fn nextTrack(mut m MusicPlayer, mut b Book, fade f32):
	t = b.plugin.musicType(m.current) ?? return false
	done = m.played.get(m.current) ?? []
	once = (t.flags & esm.musicPlaysOnce) != 0 and not done.isEmpty
	ended = (t.flags & esm.musicCycles) == 0 and done.len >= t.tracks.len
	if once or ended: return false
	id = m.pickTrack(b, t) ?? return false
	track = b.resolvedTrack(id) ?? return false
	m.until = b.time + m.playTrack(b, track, fade, t.editorId)
	true

# the type that played done: the location's stays asked (it plays again when nothing is over it)
fn finishType(mut m MusicPlayer, mut b Book):
	t = b.plugin.musicType(m.current)
	b.musicLine(t?.editorId ?? "", "", "ends")
	if m.current == m.location: m.locationDone = true
	m.asked = m.asked.filter(it != m.current)
	m.played.remove(m.current)
	m.current = 0

# The music one frame on (the book's clock already moved): the leading type started when it is
# not the one playing (the one playing faded out over its fade), the next track when one ends.
pub fn stepMusic(mut m MusicPlayer, mut b Book):
	want = m.leading(b)
	if want != m.current:
		if m.current != 0:
			old = b.plugin.musicType(m.current)
			fade f32 = 0.0 if ((old?.flags ?? 0) & esm.musicAbrupt) != 0 else (old?.fade ?? 0.0)
			audio.stopMusic(fade)
			b.musicLine(old?.editorId ?? "", "", "stops, fading {fade:.1} s")
		m.current = want
		if want == 0: return
		t = b.plugin.musicType(want) ?? return
		fade f32 = 0.0 if (t.flags & esm.musicAbrupt) != 0 else t.fade
		b.musicLine(t.editorId, "", "starts (priority {t.priority}, fade {fade:.1} s)")
		if not m.nextTrack(b, fade): m.finishType(b)
		return
	if m.current == 0 or b.time < m.until: return
	if not m.nextTrack(b, 0.0):
		audio.stopMusic(0.0)
		m.finishType(b)

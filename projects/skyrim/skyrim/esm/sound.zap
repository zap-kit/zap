# The plugin's sound records (UESP's Skyrim Mod:Mod File Format, xEdit's definitions): a sound
# descriptor (SNDR) names its files (ANAM, one picked at random) and may stand for another (SNAM);
# a sound marker (SOUN) places a descriptor (SDSC); an acoustic space (ASPC) has an ambient loop
# (SNAM), a region whose sounds it uses (RDAT) and a reverb (BNAM); a music type (MUSC) lists its
# tracks (TNAM), and a track (MUST) its file (ANAM, its finale BNAM) or, as a palette, other
# tracks (SNAM). The paths are under Data\Sound\ or Data\ as written, in any case; a .wav that
# is not in the archives is read as the .xwm (music) or .fuz (voices) beside it, as the game does.
# How the game plays them: a descriptor's category (SNCT, its volume through its parents), its
# output model (SOPM: attenuated by distance along a curve, or played as is to the speakers), its
# loop, its random variance of pitch and loudness and its static attenuation; the layouts after
# xEdit's wbDefinitionsTES5 and CommonLibSSE's BGSSoundOutput, BGSSoundCategory, BGSMusicType and
# BGSStandardSoundDef.

# The archive key of a sound path a record names ("fx\fire\x.wav", "\Data\Music\x.wav").
pub fn soundKey(path str) str:
	key = path.replace("\\", "/").lower()
	from = 0
	while from < key.len and key[from] == '/':
		from += 1
	if key[from..].startsWith("data/"): from += 5
	rest = key[from..]
	if rest.startsWith("sound/") or rest.startsWith("music/"): return rest.copy()
	"sound/{rest}"

# The files a sound descriptor or a sound marker may play (keys as written; see soundKey), with
# those of the descriptor it stands for; none for another record.
pub fn soundFiles(mut e Esm, formId i64) str[]:
	out = []
	e.addSoundFiles(formId, out, 4)
	out

fn addSoundFiles(mut e Esm, formId i64, mut out str[], depth i64):
	if depth == 0: return
	r = e.recordOf(formId) ?? return
	if r.kind == "SOUN":
		e.addSoundFiles(r.formOf("SDSC") ?? 0, out, depth - 1)
		return
	if r.kind != "SNDR": return
	for f in r.fields:
		if f.tag == "ANAM": out.push(soundKey(r.body.cStringAt(f.at)))
	other = r.formOf("SNAM") ?? 0
	if other != 0: e.addSoundFiles(other, out, depth - 1)

# A sound category: its parent and its volumes; a sound's volume is the product of its category's
# and its parents' (staticVolume, and for a category on the audio menu the slider, at menuDefault
# until the player moves it).
pub type SoundCategory:
	editorId str
	parent i64   # PNAM, 0 for the master
	onMenu bool   # FNAM's "Should Appear on Menu"
	staticVolume f32   # VNAM: 0..1
	menuDefault f32   # UNAM: the slider's default, 0..1

# An output model: how a sound reaches the speakers.
pub type OutputModel:
	editorId str
	attenuates bool   # NAM1's "Attenuates With Distance": placed in the world, else heard as is (2D)
	reverbSend i64   # percent
	speakers bool   # MNAM: defined speaker output (ONAM), else placed by HRTF
	minDistance f32   # ANAM: full volume up to here
	maxDistance f32
	curve f32[5]   # the volume (0..1) at five distances spread evenly from min to max

# A sound descriptor as it plays.
pub type Descriptor:
	editorId str
	category i64
	output i64   # its output model, 0 for none
	files str[]   # one picked at random each play (soundKey's keys)
	looping i64   # LNAM: loopNone, loopRepeat, 16 and 32 an envelope (fast, slow)
	frequencyShift i64   # BNAM: percent
	frequencyVariance i64   # percent either way
	priority i64
	dbVariance i64   # decibels quieter, at most, picked each play
	staticAttenuation f32   # decibels
	conditioned bool   # it has conditions (CTDA), which are not evaluated

pub loopNone = 0
pub loopRepeat = 8

fn u16At(r Record, tag str, k i64) i64:
	at = dataOf(r.fields, tag) ?? return -1
	r.body.u16le(at + 2 * k)

fn f32Of(r Record, tag str, k i64) f32:
	at = dataOf(r.fields, tag) ?? return 0.0
	r.body.f32le(at + 4 * k)

fn u32Of(r Record, tag str, k i64, otherwise i64) i64:
	at = dataOf(r.fields, tag) ?? return otherwise
	r.body.u32le(at + 4 * k)

# A sound category by form id, none when it is no SNCT.
pub fn soundCategory(mut e Esm, formId i64) SoundCategory?:
	r = try e.recordOf(formId)
	if r.kind != "SNCT": return none
	volume = r.u16At("VNAM", 0)
	menu = r.u16At("UNAM", 0)
	SoundCategory(
		editorId = textOf(r.body, r.fields, "EDID"),
		parent = r.formOf("PNAM") ?? 0,
		onMenu = (r.u32Of("FNAM", 0, 0) & 2) != 0,
		staticVolume = f32(volume) / 65_535.0 if volume >= 0 else 1.0,
		menuDefault = f32(menu) / 65_535.0 if menu >= 0 else 1.0
	)

# An output model by form id, none when it is no SOPM.
pub fn outputModel(mut e Esm, formId i64) OutputModel?:
	r = try e.recordOf(formId)
	if r.kind != "SOPM": return none
	data = r.u32Of("NAM1", 0, 0)
	m = OutputModel(
		editorId = textOf(r.body, r.fields, "EDID"),
		attenuates = (data & 1) != 0,
		reverbSend = data >> 24,
		speakers = r.u32Of("MNAM", 0, 0) == 1,
		minDistance = r.f32Of("ANAM", 1),
		maxDistance = r.f32Of("ANAM", 2),
		curve = [1.0, 1.0, 1.0, 1.0, 1.0]
	)
	at = dataOf(r.fields, "ANAM") ?? return m
	for k in 0..5:
		m.curve[k] = f32(r.body[at + 12 + k]) / 100.0
	m

# A sound descriptor by form id, none when it is no SNDR.
pub fn descriptor(mut e Esm, formId i64) Descriptor?:
	r = try e.recordOf(formId)
	if r.kind != "SNDR": return none
	d = Descriptor(
		editorId = textOf(r.body, r.fields, "EDID"),
		category = r.formOf("GNAM") ?? 0,
		output = r.formOf("ONAM") ?? 0,
		files = e.soundFiles(formId),
		looping = (r.u32Of("LNAM", 0, 0) >> 8) & 255,
		frequencyShift = 0,
		frequencyVariance = 0,
		priority = 128,
		dbVariance = 0,
		staticAttenuation = 0.0,
		conditioned = r.fields.any(.tag == "CTDA")
	)
	at = dataOf(r.fields, "BNAM") ?? return d
	d.frequencyShift = i8(r.body[at])
	d.frequencyVariance = i8(r.body[at + 1])
	d.priority = r.body[at + 2]
	d.dbVariance = r.body[at + 3]
	d.staticAttenuation = f32(r.body.u16le(at + 4)) / 100.0
	d

# A music type: how it plays its tracks.
pub type MusicType:
	editorId str
	flags i64   # FNAM: musicPlaysOnce, musicAbrupt, musicCycles, musicInOrder, musicPlaysOver
	priority i64   # PNAM: the lower, the more it takes over
	ducking f32   # decibels the types under it are lowered by, when it plays over them
	fade f32   # WNAM: seconds it fades in and out over
	tracks i64[]   # TNAM

pub musicPlaysOnce = 1
pub musicAbrupt = 2
pub musicCycles = 4
pub musicInOrder = 8
pub musicPlaysOver = 32

# A music type by form id, none when it is no MUSC.
pub fn musicType(mut e Esm, formId i64) MusicType?:
	r = try e.recordOf(formId)
	if r.kind != "MUSC": return none
	MusicType(
		editorId = textOf(r.body, r.fields, "EDID"),
		flags = r.u32Of("FNAM", 0, 0),
		priority = r.u16At("PNAM", 0).max(0),
		ducking = f32(r.u16At("PNAM", 1).max(0)) / 100.0,
		fade = r.f32Of("WNAM", 0),
		tracks = formsOf(r.body, r.fields, "TNAM")
	)

# A music track: a single track's file (its finale, its length when it says, its fade-out, its
# loop and cue points), a palette's tracks, or a silence of its duration.
pub type Track:
	editorId str
	kind i64   # CNAM: trackSingle, trackPalette or trackSilent
	file str   # ANAM's key, "" for none
	finale str   # BNAM's key, "" for none
	duration f32   # FLTV: seconds, 0 when the file's length is meant
	fadeOut f32   # DNAM: seconds
	loopFrom f32   # LNAM: the loop's start and end (seconds) and its count, 0 for none
	loopTo f32
	loops i64
	cues f32[]   # FNAM: seconds
	tracks i64[]   # SNAM: a palette's

pub trackPalette = 0x23F6_78C3
pub trackSingle = 0x6ED7_E048
pub trackSilent = 0xA1A9_C4D5

fn keyOf(r Record, tag str):
	text = textOf(r.body, r.fields, tag)
	soundKey(text) if text != "" else ""

# A music track by form id, none when it is no MUST.
pub fn musicTrack(mut e Esm, formId i64) Track?:
	r = try e.recordOf(formId)
	if r.kind != "MUST": return none
	cueBytes = bytesOf(r.body, r.fields, "FNAM")
	Track(
		editorId = textOf(r.body, r.fields, "EDID"),
		kind = r.u32Of("CNAM", 0, trackSingle),
		file = r.keyOf("ANAM"),
		finale = r.keyOf("BNAM"),
		duration = r.f32Of("FLTV", 0),
		fadeOut = r.f32Of("DNAM", 0),
		loopFrom = r.f32Of("LNAM", 0),
		loopTo = r.f32Of("LNAM", 1),
		loops = r.u32Of("LNAM", 2, 0),
		cues = (0..cueBytes.len / 4).map(cueBytes.f32le(4 * it)),
		tracks = formsOf(r.body, r.fields, "SNAM")
	)

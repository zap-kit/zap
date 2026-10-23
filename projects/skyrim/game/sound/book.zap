# Skyrim's sounds played through the engine's audio as the game plays them. A sound descriptor
# (esm.Descriptor) plays one of its files picked at random, at its category's volume (the static
# volumes of the category and its parents, times the audio menu's sliders at their defaults and
# the master slider) lowered by its static attenuation and a random part of its dB variance, at the
# pitch its frequency shift and variance give; placed in the world when its output model
# attenuates with distance (the model's curve over its min and max distance, the engine's curved
# voices), heard as is otherwise. Positions are Skyrim's units, Z up; the listener is the camera.
# Every play is logged: when, what, the file, the volume and the distance.

import engine.audio
import fs
import skyrim
import skyrim.esm

masterCategory = "audiocategorymaster"   # the category whose slider is fAudioMasterVolume

# one sound started
pub type LogLine:
	time f64
	what str   # the descriptor's or the music track's editor id
	key str   # the file played
	volume f32   # its own (category, attenuation, variance)
	gain f32   # what its distance leaves of it, 1 for a sound heard as is
	distance f32   # from the listener, -1 for a sound heard as is
	why str

pub type Book:
	install skyrim.Install
	plugin esm.Esm
	descriptors {i64: esm.Descriptor} = {}
	models {i64: esm.OutputModel} = {}
	volumes {i64: f32} = {}   # by category
	sliders {str: f32} = {}   # the audio menu's sliders (0..1) by category editor id, lower case; a missing one is at its default
	sounds {str: audio.Sound} = {}   # decoded, by key
	lacking {str: bool} = {}   # keys no archive holds or that do not decode
	dice Random = Random(17)
	time f64 = 0.0   # seconds since the cell opened
	listener Vec3 = Vec3(0, 0, 0)
	log LogLine[] = []

pub fn newBook(move install skyrim.Install, move plugin esm.Esm) Book:
	Book(install, plugin)

# the gain of a level in decibels (negative: quieter)
pub fn decibels(db f32) f32:
	f32(10.0.pow(f64(db) / 20.0))

# A category's volume: the static volumes of it and its parents, the sliders of those on the audio
# menu at their defaults, the master slider.
pub fn categoryVolume(mut b Book, category i64) f32:
	if b.volumes.get(category) is v: return v
	v = b.sliders.get(masterCategory) ?? 1.0
	at = category
	loop 16:
		c = b.plugin.soundCategory(at) ?? break
		v *= c.staticVolume
		key = c.editorId.lower()
		if c.onMenu and key != masterCategory: v *= b.sliders.get(key) ?? c.menuDefault
		at = c.parent
		if at == 0: break
	b.volumes[category] = v
	v

# The audio menu's sliders set (the volumes of the categories heard from now on).
pub fn setSliders(mut b Book, sliders {str: f32}):
	b.sliders = sliders.copy()
	b.volumes = {}

pub fn descriptorOf(mut b Book, id i64) esm.Descriptor?:
	if b.descriptors.get(id) is d: return d.copy()
	d = try b.plugin.descriptor(id)
	b.descriptors[id] = d.copy()
	d

pub fn modelOf(mut b Book, id i64) esm.OutputModel?:
	if b.models.get(id) is m: return m.copy()
	m = try b.plugin.outputModel(id)
	b.models[id] = m.copy()
	m

# the bytes a sound key plays as the install holds it: a voice's FUZ gives its xWMA
fn soundBytes(b Book, key str) u8[]?:
	found = try b.install.installSound(key)
	bytes = try b.install.installRead(found)
	if not found.endsWith(".fuz"): return bytes
	(skyrim.readFuz(bytes) ?? return none).sound

# The sound of a key decoded once; none when no archive holds it or it does not decode.
pub fn soundOf(mut b Book, key str) audio.Sound?:
	if b.sounds.get(key) is s: return s
	if key in b.lacking: return none
	bytes = b.soundBytes(key) ?? []
	match audio.decodeSound(bytes):
		s:
			b.sounds[key.copy()] = s
			s
		none:
			b.lacking[key.copy()] = true
			none

# Where the sounds are heard from: the camera at `eye` looking toward `heading` (radians from
# north toward east).
pub fn hearFrom(mut b Book, eye Vec3, heading f32):
	b.listener = eye
	eye.setListener(Vec3(heading.sin(), heading.cos(), 0), Vec3(0, 0, 1))

# a number in lo..hi at random, lo when the range is empty
fn uniform(mut b Book, lo f32, hi f32):
	f32(b.dice.nextFloat(f64(lo), f64(hi))) if hi > lo else lo

# what the descriptor plays with, the model placing it at `at` when it attenuates
fn paramsOf(mut b Book, d esm.Descriptor, at Vec3):
	quieter = d.staticAttenuation + b.uniform(0.0, f32(d.dbVariance))
	variance = f32(d.frequencyVariance)
	p = audio.PlayParams(
		volume = b.categoryVolume(d.category) * decibels(-quieter),
		pitch = 1.0 + (f32(d.frequencyShift) + b.uniform(-variance, variance)) / 100.0,
		looping = d.looping != esm.loopNone
	)
	m = b.modelOf(d.output) ?? return p
	if not m.attenuates: return p
	p.positional = true
	p.position = at
	p.minDistance = m.minDistance
	p.maxDistance = m.maxDistance
	p.curved = true
	p.curve = m.curve
	p

# the sound's line in the log, its gain at its distance as the mixer computes it
fn logPlay(mut b Book, what str, key str, p audio.PlayParams, why str):
	distance = (p.position - b.listener).length() if p.positional else -1.0
	gain = audio.curveGain(p.curve, p.minDistance, p.maxDistance, distance) if p.positional
		else 1.0
	b.log.push(LogLine(time = b.time, what = what.copy(), key = key.copy(), volume = p.volume,
		gain, distance, why = why.copy()))

# Plays the sound descriptor `id`, placed at `at` when its output model places it; the voice,
# none when it has no file the install holds.
pub fn playDescriptor(mut b Book, id i64, at Vec3, why str) audio.Voice?:
	b.playDescriptorThrough(id, 0, at, why)

# playDescriptor through the output model `model` instead of the descriptor's own (0 for its own)
pub fn playDescriptorThrough(mut b Book, id i64, model i64, at Vec3, why str) audio.Voice?:
	d = try b.descriptorOf(id)
	if model != 0: d.output = model
	if d.files.isEmpty: return none
	key = d.files[b.dice.nextInt(0, len)].copy()
	sound = try b.soundOf(key)
	p = b.paramsOf(d, at)
	b.logPlay(d.editorId, key, p, why)
	sound.play(p)

# Plays a file as a sound of the category through the output model (a voice line), at `at`.
pub fn playFile(
	mut b Book,
	key str,
	category i64,
	model i64,
	at Vec3,
	why str
) audio.Voice?:
	sound = try b.soundOf(key)
	d = esm.Descriptor(editorId = "", category, output = model, files = [key.copy()], looping = 0,
		frequencyShift = 0, frequencyVariance = 0, priority = 128, dbVariance = 0,
		staticAttenuation = 0.0, conditioned = false)
	p = b.paramsOf(d, at)
	b.logPlay(fs.fileName(key), key, p, why)
	sound.play(p)

# The log's lines as text, from `from` on.
pub fn logText(b Book, from i64) str[]:
	b.log[from..].map(
		"{.time:>7.2} s  {.what:<34} {fs.fileName(.key):<38} vol {.volume:.3}  {.placeText()}  {.why}"
	)

# where a logged sound was heard from
fn placeText(l LogLine):
	"2D" if l.distance < 0.0 else "at {l.distance:.0} gain {l.gain:.2}"

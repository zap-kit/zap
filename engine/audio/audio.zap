# Sound for a game: effects played by voices (volume, pan, pitch, looping, fades, placed in 3D
# around a listener) and music streamed from its files (the formats openStream reads) with
# crossfades, mixed on a thread of its own and played through WASAPI. Every function here is
# called from the game's thread; it queues a command the audio thread takes at its next period
# (every ~10 ms), so none waits on the sound card.
#
#     import engine.audio
#
#     audio.start()                                     // the device opens on the audio thread
#     hit = audio.loadSound("sfx/hit.wav") ?? fail("no hit.wav")
#     v = audio.play(hit, audio.PlayParams(volume = 0.8, pan = -0.3))
#     audio.playAt(hit, enemy.position)                 // gain and pan from the listener
#     audio.setListener(camera.position, camera.forward)
#     _ = audio.playMusic("bgm/01.mp3", fade = 2.0)     // a crossfade from the song playing
#     audio.stop(v, fade = 0.5)
#     audio.update()                                    // each frame: which voices ended
#
# A Sound is decoded once, here, and handed to the audio thread; a Voice names one playing of it.
# The audio thread runs as a background job (engine programs keep one of the job threads for it),
# talks to the game's thread through two channels only (the orders it takes, the reports it
# sends: it never waits on either), and survives a missing or lost device: it keeps mixing in
# time and opens the default device again when there is one.

import fs

extern "avrt.dll" fn AvSetMmThreadCharacteristicsA(task str, out index u32) i64
extern "avrt.dll" fn AvRevertMmThreadCharacteristics(task i64) bool

# A sound loaded for playing: its id with the audio thread, and what it is.
pub type Sound:
	id i64
	frames i64
	channels i64
	sampleRate i64

	fn seconds():
		f64(frames) / f64(sampleRate) if sampleRate > 0 else 0.0

# A stream of samples the program makes as it runs (push), played as they come.
pub type Feed:
	id i64

# One playing of a sound.
pub type Voice:
	id i64

# What the audio thread did, for a frame's report (stats()).
pub type Stats:
	deviceOpen bool = false
	rate i64 = 0   # the device's rate and channels
	channels i64 = 0
	bufferFrames i64 = 0   # the device's buffer
	periodFrames i64 = 0   # the engine's period when it was asked for (IAudioClient3), else 0
	periods i64 = 0   # times the device asked for more
	underruns i64 = 0   # times it had played all it had (a gap was heard)
	framesMixed i64 = 0
	mixSeconds f64 = 0.0   # time spent mixing and writing
	longestWaitMs f64 = 0.0   # the longest time between two of the device's requests
	reopened i64 = 0   # times the device was lost or changed and opened again
	voices i64 = 0
	songs i64 = 0

# ---------- the channels between the game's thread and the audio thread ----------

type AudioCommand:
	AddSound(id i64, samples f32[], channels i64, rate i64)
	RemoveSound(id i64)
	Play(voice i64, sound i64, params PlayParams)
	SetVolume(voice i64, volume f32, fade f32)
	SetPan(voice i64, pan f32)
	SetPitch(voice i64, pitch f32)
	SetPosition(voice i64, position Vec3)
	Stop(voice i64, fade f32)
	PlayMusic(stream Stream, looping bool, fade f32, volume f32)
	StopMusic(fade f32)
	PushFeed(feed i64, samples f32[], channels i64, rate i64)
	SetMusicVolume(volume f32)
	SetMasterVolume(volume f32)
	SetListener(listener Listener)
	Shutdown

# what the audio thread reports back: the voices that ended since its last report, its numbers,
# why the device failed
type AudioReport:
	ended i64[]
	stats Stats
	failure str

# the reports waiting for update() that make the audio thread hold the next one back (its ended
# voices kept for it), so a game that never calls update() keeps no more than these
reportsHeld = 4

# The game's side. The channels are made here once; the audio thread is given copies of them
# (the same queues) and touches no module variable. Orders sent before start() wait in them.
mut audioOrders = Channel<AudioCommand>()
mut audioReports = Channel<AudioReport>()
mut audioJobs Background<i64>[] = []   # the audio thread while it runs
mut audioNextId = 1
mut audioPlaying {i64: bool} = {}
mut audioLastStats = Stats()
mut audioLastFailure = ""
mut audioOffline Mixer[] = []   # the mixer a program renders itself (startOffline), held alone

fn send(move c AudioCommand):
	audioOrders.send(c)

fn nextId():
	id = audioNextId
	audioNextId += 1
	id

# ---------- the API ----------

fn audioWord():
	RunWord("audio", "off opens no audio device: sound runs, unheard")

# Starts the audio thread, which opens the default output device (or waits for one). Calls made
# before it are queued and play once it runs. With audio=off in ZAP_RUN no device is
# opened: the mixer runs in time, unheard, as it does when there is no device.
pub fn start():
	if not audioJobs.isEmpty: return
	off = (audioWord().value() ?? "").lower() == "off"
	orders = audioOrders
	reports = audioReports
	audioJobs.push(background((): audioThreadMain(orders, reports, off)))

# Starts the sound without a thread or a device: the orders wait until the program renders the
# mix itself (renderOffline), as a tool writing a WAV of a scene or a test does.
pub fn startOffline(rate i64):
	if not audioJobs.isEmpty or not audioOffline.isEmpty: return
	audioOffline.push(newMixer(rate))

# The next n frames of the offline mix (startOffline) as stereo floats, the orders sent before
# taken first; silence when it was not started.
pub fn renderOffline(n i64) f32[]:
	out f32[] = []
	if audioOffline.isEmpty:
		loop 2 * n:
			out.push(0.0)
		return out
	audioOffline[0].applyCommands(audioOrders)
	audioOffline[0].render(out, n)
	for id in audioOffline[0].takeEnded():
		audioPlaying.remove(id)
	audioLastStats.voices = audioOffline[0].voiceCount()
	audioLastStats.songs = audioOffline[0].musicCount()
	out

# Stops the audio thread and closes the device (waits for it, at most a second).
pub fn shutdown():
	if audioJobs.isEmpty: return
	send(.Shutdown)
	loop 1000:
		if audioJobs[0].isDone:
			audioJobs[0].tryReceive()
			break
		sleepMs(1)
	audioJobs.clear()

# A sound from a file's bytes in a format openStream reads, decoded whole (more than two
# channels are mixed down to stereo); none when the bytes are in none of them.
pub fn decodeSound(bytes ref u8[]) Sound?:
	own = []
	own.extend(bytes)
	pcm = try decodeAudio(move own)
	newSound(pcm.samples, pcm.channels, pcm.sampleRate)

# A sound from a file in a format openStream reads.
pub fn loadSound(path str) Sound?:
	text = fs.readFile(path) ?? return none
	decodeSound(text.bytes())

# A sound from samples made by the program (a tone, a recording): interleaved floats in -1..1,
# mono or stereo (more channels are mixed down to stereo).
pub fn newSound(move samples f32[], channels i64, sampleRate i64) Sound:
	id = nextId()
	pcm = samples
	ch = channels.max(1)
	if ch > 2:
		pcm = downmixToStereo(pcm, ch)
		ch = 2
	frames = pcm.len / ch
	send(.AddSound(id, pcm, ch, sampleRate))
	Sound(id, frames, channels = ch, sampleRate)

# many channels to two: the odd ones (front left, side left...) to the left, the even to the
# right, the third (center) to both
fn downmixToStereo(samples f32[], ch i64):
	heard = Grid(ch, samples.len / ch, cells = samples[..len / ch * ch].copy())
	out f32[] = []
	out.reserve(heard.height * 2)
	for f in 0..heard.height:
		l = f32(0.0)
		r = f32(0.0)
		for c in 0..heard.width:
			x = heard[c, f]
			if c == 2:
				l += x * 0.7071
				r += x * 0.7071
			elif c == 3:
				# the low frequencies: left out, as most downmixes do
				pass
			elif c % 2 == 0:
				l += x
			else:
				r += x
		out.push(l * 0.5)
		out.push(r * 0.5)
	out

# The audio thread forgets the sound; its voices end.
pub fn unloadSound(s Sound):
	send(.RemoveSound(s.id))

# A feed of samples to push as the program makes them (an emulator's sound).
pub fn newFeed() Feed:
	Feed(id = nextId())

# More samples of the feed: interleaved, 1 or 2 channels at `rate` frames a second, played after
# those pushed before.
pub fn push(f Feed, move samples f32[], channels i64, rate i64):
	send(.PushFeed(f.id, move samples, channels, rate))

# Plays a sound; the voice playing it.
pub fn play(s Sound, params PlayParams = PlayParams()) Voice:
	id = nextId()
	audioPlaying[id] = true
	send(.Play(id, s.id, params))
	Voice(id)

# Plays a sound placed at `position`: its gain and pan follow from the listener (setListener).
pub fn playAt(s Sound, position Vec3, params PlayParams = PlayParams()) Voice:
	p = params
	p.positional = true
	p.position = position
	s.play(p)

# A voice's volume, reached over `fade` seconds.
pub fn setVolume(v Voice, volume f32, fade f32 = 0.0):
	send(.SetVolume(v.id, volume, fade))

# -1 left .. 1 right (a stereo sound: the balance).
pub fn setPan(v Voice, pan f32):
	send(.SetPan(v.id, pan))

# The playback speed: 2.0 is an octave up.
pub fn setPitch(v Voice, pitch f32):
	send(.SetPitch(v.id, pitch))

# Moves a positional voice.
pub fn setPosition(v Voice, position Vec3):
	send(.SetPosition(v.id, position))

# Stops a voice: at once, or fading out over `fade` seconds.
pub fn stop(v Voice, fade f32 = 0.0):
	send(.Stop(v.id, fade))

# Whether a voice still plays (as of the last update()).
pub fn isPlaying(v Voice) bool:
	update()
	v.id in audioPlaying

# Plays a song from a file, streamed (its compressed bytes in memory, decoded as it plays):
# it fades in over `fade` seconds while the song playing fades out (0: a cut). False when the
# file is missing or in no format openStream reads.
pub fn playMusic(path str, looping bool = true, fade f32 = 1.0, volume f32 = 1.0) bool:
	text = fs.readFile(path) ?? return false
	bytes = []
	bytes.extend(text.bytes())
	playMusicBytes(move bytes, looping, fade, volume)

# Like playMusic; false when the bytes are in no format openStream reads.
pub fn playMusicBytes(
	move bytes u8[],
	looping bool = true,
	fade f32 = 1.0,
	volume f32 = 1.0
) bool:
	stream = openStream(move bytes) ?? return false
	send(.PlayMusic(stream, looping, fade, volume))
	true

# Fades the music out over `fade` seconds.
pub fn stopMusic(fade f32 = 1.0):
	send(.StopMusic(fade))

# Times each song's own volume.
pub fn setMusicVolume(volume f32):
	send(.SetMusicVolume(volume))

pub fn setMasterVolume(volume f32):
	send(.SetMasterVolume(volume))

# Where sounds are heard from: a position, the direction looked at, and up.
pub fn setListener(position Vec3, forward Vec3, up Vec3 = Vec3(0.0, 1.0, 0.0)):
	send(.SetListener(Listener(position, forward, up)))

# Takes the audio thread's report: the voices that ended, its numbers. Call it once a frame (the
# functions that answer about voices call it too).
pub fn update():
	while audioReports.tryReceive() is report:
		for id in report.ended:
			audioPlaying.remove(id)
		audioLastStats = report.stats
		if report.failure != audioLastFailure:
			audioLastFailure = report.failure

# The audio thread's numbers, as of the last update().
pub fn stats() Stats:
	audioLastStats

# Why the device could not be opened ("" while it is open or was never tried).
pub fn deviceFailure() str:
	audioLastFailure.copy()

# ---------- the audio thread ----------

# Applies the orders waiting to the mixer, without waiting for more; true when one asks the thread
# to end.
fn applyCommands(mut m Mixer, orders Channel<AudioCommand>):
	quit = false
	ins = orders
	loop:
		c = ins.tryReceive() ?? break
		match c:
			AddSound(id, mut samples, channels, rate):
				ch = channels
				hz = rate
				m.addSound(id, move samples, ch, hz)
			RemoveSound(id): m.removeSound(id)
			Play(voice, sound, params): m.play(voice, sound, params)
			SetVolume(voice, volume, fade): m.setVolume(voice, volume, fade)
			SetPan(voice, pan): m.setPan(voice, pan)
			SetPitch(voice, pitch): m.setPitch(voice, pitch)
			SetPosition(voice, position): m.setPosition(voice, position)
			Stop(voice, fade): m.stop(voice, fade)
			PlayMusic(mut stream, looping, fade, volume):
				repeat = looping
				seconds = fade
				gain = volume
				m.playMusic(move stream, repeat, seconds, gain)
			StopMusic(fade): m.stopMusic(fade)
			PushFeed(feed, samples, channels, rate): m.feed(feed, samples, channels, rate)
			SetMusicVolume(volume): m.setMusicVolume(volume)
			SetMasterVolume(volume): m.setMasterVolume(volume)
			SetListener(listener): m.setListener(listener)
			Shutdown: quit = true
	quit

# The audio thread made one of Windows' multimedia class "Pro Audio" (COM ready for the device):
# its task's handle, 0 when the class was refused
fn raiseAudioPriority():
	CoInitializeEx(0, 0)
	task = AvSetMmThreadCharacteristicsA("Pro Audio\0", out taskIndex)
	_ = taskIndex
	task

fn lowerAudioPriority(task i64):
	if task != 0:
		AvRevertMmThreadCharacteristics(task)
	CoUninitialize()

# the thread's life: mix what the device asks for, as it asks, until told to end
fn audioThreadMain(orders Channel<AudioCommand>, reports Channel<AudioReport>, off bool):
	ins = orders
	outs = reports
	task = raiseAudioPriority()
	m = newMixer(48_000)
	out f32[] = []
	out.reserve(2 * 4800)
	stats = Stats()
	ended = []
	dev = OutputDevice(failure = "audio is off (audio=off in ZAP_RUN)") if off else openOutput()
	failure = dev.failure.copy()
	lastWake = clockSeconds()
	nextTry = lastWake + 2.0
	nextCheck = lastWake + 2.0
	idleFrom = lastWake
	first = true
	loop:
		if m.applyCommands(ins): break
		if dev.isOpen():
			m.setRate(dev.rate)
			dev.waitForDevice(200)
			now = clockSeconds()
			waitMs = (now - lastWake) * 1000.0
			if not first:
				stats.longestWaitMs = stats.longestWaitMs.max(waitMs)
			lastWake = now
			free = dev.framesFree()
			if free < 0:
				dev.closeOutput()
				stats.reopened += 1
				failure = "the device was lost"
				nextTry = now
				idleFrom = now
				continue
			if free >= dev.bufferFrames and not first:
				stats.underruns += 1
			first = false
			stats.periods += 1
			if free > 0:
				m.render(out, free)
				if not dev.writeFrames(out, free):
					dev.closeOutput()
					stats.reopened += 1
					failure = "the device was lost"
					nextTry = now
					idleFrom = now
					continue
				stats.framesMixed += free
			stats.mixSeconds += clockSeconds() - now
			if now >= nextCheck:
				nextCheck = now + 2.0
				if dev.hasDefaultChanged():
					dev.closeOutput()
					stats.reopened += 1
					nextTry = now
					idleFrom = now
		else:
			# no device: the mix goes on in time, unheard, and a device is looked for now and then
			sleepMs(10)
			now = clockSeconds()
			due = i64((now - idleFrom) * m.rate)
			if due > 0:
				n = due.min(4800)
				m.render(out, n)
				idleFrom += f64(n) / f64(m.rate)
				stats.framesMixed += n
			if now >= nextTry and not off:
				dev = openOutput()
				if dev.isOpen():
					failure = ""
					first = true
					lastWake = clockSeconds()
				else:
					failure = dev.failure.copy()
					nextTry = now + 2.0
		stats.deviceOpen = dev.isOpen()
		stats.rate = dev.rate
		stats.channels = dev.channels
		stats.bufferFrames = dev.bufferFrames
		stats.periodFrames = dev.period
		stats.voices = m.voiceCount()
		stats.songs = m.musicCount()
		ended.extend(m.takeEnded())
		if outs.len < reportsHeld:
			outs.send(AudioReport(ended = move ended, stats, failure = failure.copy()))
			ended = []
	dev.closeOutput()
	lowerAudioPriority(task)
	0

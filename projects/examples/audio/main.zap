# The engine's audio, heard: a tone made here sweeping from left to right, a chord written as a
# WAV in memory and played at points that circle the listener, a short MP3 blip with its pitch
# changing, and music streamed from MP3 files with a crossfade from one song to the other. No
# window: a frame loop at 60 frames a second, `--frames N` to end after N of them (600, ten
# seconds, by default), the audio thread's numbers printed once a second. `--music a.mp3` and
# `--music2 b.mp3` play other songs (a Ragnarok Online BGM, say).
#
#     zap run projects/examples/audio/main.zap [--frames N]      (from the repository's root)
#
# The MP3 files beside it were made by ffmpeg from generated waves (`-f lavfi -i aevalsrc=...`
# encoded with libmp3lame): music-a 44.1 kHz stereo at 64 kbps, music-b 22.05 kHz at 48 kbps, blip
# 22.05 kHz mono.

import engine.audio
import tones
import engine.audio.wav

fn dir():
	"projects/examples/audio"

# a chord (a major triad) with a decay, stereo: the root left, the fifth right, the third in both
fn chordWav(rate i64):
	n = rate * 3 / 2
	samples = []
	for i in 0..n:
		t = f64(i) / f64(rate)
		decay = (-2.5 * t).exp()
		root = (t * 261.63 * tau).sin()
		third = (t * 329.63 * tau).sin()
		fifth = (t * 392.0 * tau).sin()
		samples.push(f32((root + third * 0.6) * decay * 0.25))
		samples.push(f32((fifth + third * 0.6) * decay * 0.25))
	wav.encodeWav(samples, 2, rate, 16)

frames = i64.parse(args.option("--frames") ?? "") ?? 600
musicA = args.option("--music") ?? "{dir()}/music-a.mp3"
musicB = args.option("--music2") ?? "{dir()}/music-b.mp3"
audio.start()

beep = audio.newSound(tones.tone(440.0, 48_000, 48_000, 0.3), 1, 48_000)
wavBytes = chordWav(44_100)
chord = audio.decodeSound(wavBytes) ?? fail("the chord WAV did not decode")
blip = audio.loadSound("{dir()}/blip.mp3") ?? fail("{dir()}/blip.mp3 did not decode")
print("sounds: tone {beep.seconds()} s, chord {chord.seconds()} s ({chord.channels} channels), blip {blip.seconds()} s at {blip.sampleRate} Hz")

if not audio.playMusic(musicA, fade = 1.0, volume = 0.6):
	eprint("cannot play {musicA}")
sweep = beep.play(audio.PlayParams(volume = 0.25, looping = true, fadeIn = 0.5))
audio.setListener(Vec3(0.0, 0.0, 0.0), Vec3(0.0, 0.0, -1.0))
mut lastReport = 0
for f in 0..frames:
	t = f32(f) / 60.0
	sweep.setPan((t * 1.5).sin())
	if f % 90 == 45:
		# the chord somewhere on a circle around the listener, 4 m away
		a = t * 1.3
		audio.playAt(
			chord,
			Vec3(a.sin() * 4.0, 0.0, -a.cos() * 4.0),
			audio.PlayParams(volume = 0.8)
		)
	if f % 40 == 20:
		audio.play(
			blip,
			audio.PlayParams(volume = 0.5, pitch = 0.75 + f32(f % 160) / 160.0, pan = -0.6)
		)
	if f == 240:
		if not audio.playMusic(musicB, fade = 2.0, volume = 0.6):
			eprint("cannot play {musicB}")
	if f == 360:
		sweep.stop(fade = 1.0)
	if f == frames - 90:
		audio.stopMusic(fade = 1.5)
	audio.update()
	if f - lastReport >= 60 or f == frames - 1:
		lastReport = f
		report()
	sleepMs(16)
audio.shutdown()

fn report():
	s = audio.stats()
	if not s.deviceOpen:
		print("no device ({audio.deviceFailure()}): {s.framesMixed} frames mixed unheard, {s.voices} voices, {s.songs} songs")
		return
	seconds = f64(s.framesMixed) / f64(s.rate.max(1))
	cpu = s.mixSeconds / seconds * 1000.0 if seconds > 0.0 else 0.0
	print("device {s.rate} Hz x{s.channels}, buffer {s.bufferFrames} frames (period {s.periodFrames}): {s.periods} periods, {s.underruns} underruns, longest wait {s.longestWaitMs:.1} ms, {s.voices} voices, {s.songs} songs, mixing {cpu:.2} ms per second of sound")

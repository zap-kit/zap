# What mixing costs: the mixer rendered offline (no device) at 48 kHz for ten seconds of sound,
# with 1, 8, 32 and 64 voices (each resampled from 44.1 kHz at its own pitch, panned, looping),
# 64 of which 56 are silent, a feed (an emulator's sound, given as it is mixed), then with a song
# streamed from MP3 or Ogg Vorbis and decoded as it plays. Prints the
# milliseconds of CPU time per second of sound (one core; 1000 would be all of it).
#
#     zap run projects/examples/audio/bench.zap [song.mp3|song.ogg]

import engine.audio
import tones
import fs

rate = 48_000
blocks = 1000   # of 480 frames: ten seconds

# ms of CPU per second of sound while the mixer renders ten seconds, `fed` (stereo frames of 44.1
# kHz) given to a feed before each block
fn measure(mut m audio.Mixer, fed f32[] = []):
	out = []
	t0 = clockSeconds()
	loop blocks:
		if not fed.isEmpty:
			m.feed(1, fed, 2, 44_100)
		m.render(out, 480)
	(clockSeconds() - t0) * 1000.0 / 10.0

# a mixer of `voices` voices, those from `heard` on at volume 0
fn mixerOf(voices i64, heard i64):
	m = audio.newMixer(rate)
	m.addSound(1, tones.tone(440.0, 44_100, 44_100, 0.05), 1, 44_100)
	m.addSound(2, tones.tone(330.0, 44_100 * 2, 44_100, 0.05), 2, 44_100)
	for v in 0..voices:
		m.play(
			v,
			1 + v % 2,
			audio.PlayParams(
				volume = 1.0 if v < heard else 0.0,
				pan = f32(v % 7) / 3.5 - 1.0,
				pitch = 0.8 + f32(v % 9) * 0.05,
				looping = true
			)
		)
	m

for voices in [1, 8, 32, 64]:
	m = mixerOf(voices, voices)
	print("{voices} voices: {m.measure():.2} ms per second of sound")
silent = mixerOf(64, 8)
print("64 voices, 56 silent: {silent.measure():.2} ms per second of sound")
fed = (0..441 * 2).map(f32(it % 50) * 0.01)
feeding = audio.newMixer(rate)
print("a feed: {feeding.measure(fed):.2} ms per second of sound")
a = args
if not a.isEmpty:
	text = fs.readFile(a[0]) ?? fail("cannot read {a[0]}")
	bytes = []
	bytes.extend(text.bytes())
	s = audio.openStream(move bytes) ?? fail("{a[0]} is not WAV, MP3 or Ogg Vorbis")
	desc = "{s.sampleRate} Hz x{s.channels}"
	m = audio.newMixer(rate)
	m.playMusic(s, true, 0.0, 1.0)
	print("a song streamed ({desc}): {m.measure():.2} ms per second of sound")

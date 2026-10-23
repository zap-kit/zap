# The engine's decoders against ffmpeg: each file named (or every file of a dir) is decoded
# by engine.audio and by ffmpeg (`ffmpeg -i file -f f32le`, which must be on the PATH), and the
# two are compared sample by sample: the signal-to-noise ratio of ours against ffmpeg's over the
# samples both have, the largest difference, the lengths, and the decoding speed. Exits with 1
# when a file's SNR is under the bar given with `--min dB` (default 60) or its length differs.
#
#     zap run projects/examples/audio/check.zap C:/Gravity/Ragnarok/BGM --min 60
#     zap run projects/examples/audio/check.zap a.wav b.mp3 c.ogg --min 90

import engine
import engine.audio
import fs

fn isAudioFile(name str):
	n = name.lower()
	n.endsWith(".mp3") or n.endsWith(".wav") or n.endsWith(".ogg")

# the floats of a raw little-endian f32 file
fn readFloats(path str):
	text = fs.readFile(path) ?? ""
	b = text.bytes()
	out f32[] = []
	out.reserve(b.len / 4)
	i = 0
	while i + 4 <= b.len:
		out.push(b.f32le(i))
		i += 4
	out

type Result:
	snr f64
	maxError f64
	ours i64   # frames
	theirs i64
	decodeSeconds f64
	audioSeconds f64

fn compare(path str) Result?:
	text = fs.readFile(path) ?? return none
	bytes = []
	bytes.extend(text.bytes())
	t0 = clockSeconds()
	pcm = try audio.decodeAudio(move bytes)
	t1 = clockSeconds()
	ch = pcm.channels
	raw = "{testDir()}check-ffmpeg.f32"
	_ = fs.deleteFile(raw)
	if Process.run("ffmpeg -v error -y -i \"{path}\" -f f32le -ac {ch} \"{raw}\"") != 0: return none
	theirs = readFloats(raw)
	n = pcm.samples.len.min(theirs.len)
	signal = 0.0
	noise = 0.0
	maxError = 0.0
	for i in 0..n:
		r = f64(theirs[i])
		e = f64(pcm.samples[i]) - r
		signal += r * r
		noise += e * e
		maxError = maxError.max(e.abs())
	snr = 999.0 if noise == 0.0 else 10.0 * (signal / noise).ln() / 10.0.ln()
	Result(
		snr,
		maxError,
		ours = pcm.samples.len / ch,
		theirs = theirs.len / ch,
		decodeSeconds = t1 - t0,
		audioSeconds = f64(pcm.frames()) / f64(pcm.sampleRate))

mut a = args.copy()
minSnr = f64.parse(args.option("--min") ?? "") ?? 60.0
mut files = []
mut i = 0
while i < a.len:
	if a[i] == "--min":
		i += 2
		continue
	if isAudioFile(a[i]):
		files.push(move a[i])
	else:
		files.extend((fs.list(a[i]) ?? []).filter(isAudioFile).map("{a[i]}/{it}"))
	i += 1
files.sort()
mut worst = 999.0
mut failures = 0
mut decodeTotal = 0.0
mut audioTotal = 0.0
for f in files:
	match compare(f):
		r:
			worst = worst.min(r.snr)
			decodeTotal += r.decodeSeconds
			audioTotal += r.audioSeconds
			mark = "  <-- below the bar" if r.snr < minSnr or r.ours != r.theirs else ""
			if mark != "":
				failures += 1
			print("{f}: SNR {r.snr:.1} dB, max error {r.maxError}, {r.ours} frames (ffmpeg {r.theirs}), decoded at {(r.audioSeconds / r.decodeSeconds):.0}x real time{mark}")
		none:
			failures += 1
			print("{f}: not decoded (by us or by ffmpeg)  <-- below the bar")
print("{files.len} files, worst SNR {worst:.1} dB, {failures} below {minSnr} dB or of another length; {audioTotal:.0} s of audio decoded in {decodeTotal:.2} s")
if failures > 0:
	exit(1)

# A compressed or long sound read a piece at a time: one interface over the decoders (MP3 frame
# by frame, WAV block by block, Ogg Vorbis and xWMA packet by packet), so music plays from its file's
# bytes without its samples all in memory. The format is found from the bytes, not the name.
# MP3's encoder delay and padding (LAME's Info frame) are cut as ffmpeg cuts them, so a song
# loops without a gap.

import engine.audio.wav
import engine.audio.mp3
import engine.audio.vorbis
import engine.audio.xwma

# An MP3 decoder with the samples to drop at the start and the count to give (gapless).
pub type Mp3Stream:
	decoder mp3.Decoder
	skipStart i64   # samples per channel dropped at the start (the encoder's delay)
	totalSamples i64   # samples per channel in the song, -1 when unknown
	skip i64 = 0   # still to drop
	remaining i64 = 0   # still to give (-1: until the frames end)

# the decoder a stream reads through
pub type StreamSource:
	Mp3(stream Mp3Stream)
	Wav(stream wav.Stream)
	Vorbis(stream vorbis.Stream)
	Xwma(stream xwma.Stream)

# A stream: its decoder, and its channels and rate, which do not change.
pub type Stream:
	source StreamSource
	channels i64
	sampleRate i64

# the decoder's gap: what ffmpeg drops (the delay plus the decoder's own 529 samples) and keeps
fn mp3Stream(move d mp3.Decoder):
	skipStart = 0
	total = -1
	if d.encoderDelay >= 0:
		skipStart = d.encoderDelay + 529
		if d.totalFrames > 0:
			spf = 1152 if d.sampleRate >= 32_000 else 576
			total = d.totalFrames * spf - d.encoderDelay - d.encoderPadding
	Mp3Stream(decoder = d, skipStart, totalSamples = total, skip = skipStart, remaining = total)

# A stream over a file's bytes (moved in): WAV, MP3, Ogg Vorbis or xWMA (WMA version 2); none
# when it is none of them.
pub fn openStream(move bytes u8[]) Stream?:
	if wav.isWav(bytes):
		w = try wav.openWav(move bytes)
		ch = w.format.channels
		rate = w.format.sampleRate
		return Stream(source = .Wav(w), channels = ch, sampleRate = rate)
	if xwma.isXwma(bytes):
		x = try xwma.openXwma(move bytes)
		ch = x.format.channels
		rate = x.format.sampleRate
		return Stream(source = .Xwma(x), channels = ch, sampleRate = rate)
	if vorbis.isOggVorbis(bytes):
		v = try vorbis.openVorbis(move bytes)
		ch = v.channels
		rate = v.sampleRate
		return Stream(source = .Vorbis(v), channels = ch, sampleRate = rate)
	d = try mp3.openMp3(move bytes)
	ch = d.channels
	rate = d.sampleRate
	Stream(source = .Mp3(mp3Stream(d)), channels = ch, sampleRate = rate)

# The seconds a file lasts as its header declares them, without decoding it: a WAV's data chunk
# over its blocks, an xWMA's dpds chunk; none for another format or a header that does not say.
pub fn declaredSeconds(bytes ref u8[]) f64?:
	if wav.isWav(bytes):
		f = try wav.readWavFormat(bytes)
		if f.blockAlign <= 0 or f.sampleRate <= 0: return none
		perBlock = f.samplesPerBlock if f.samplesPerBlock > 0 else 1
		return f64(f.dataBytes / f.blockAlign * perBlock) / f64(f.sampleRate)
	if xwma.isXwma(bytes):
		f = try xwma.readXwmaFormat(bytes)
		frames = f.declaredFrames()
		if frames < 0 or f.sampleRate <= 0: return none
		return f64(frames) / f64(f.sampleRate)
	none

# Appends the next piece of the stream to `out` (interleaved, the stream's channels): its frames,
# 0 at the end.
pub fn readStream(mut s Stream, mut out f32[]) i64:
	match s.source:
		Mp3(mut m): m.readMp3Stream(out)
		Wav(mut w): w.readWavBlock(out)
		Vorbis(mut v): v.readVorbis(out)
		Xwma(mut x): x.readXwma(out)

fn readMp3Stream(mut m Mp3Stream, mut out f32[]):
	ch = m.decoder.channels
	while m.remaining != 0:
		n = m.decoder.decodeMp3Frame()
		if n == 0: return 0
		drop = m.skip.min(n)
		m.skip -= drop
		give = n - drop
		if m.remaining > 0:
			give = give.min(m.remaining)
			m.remaining -= give
		if give > 0:
			out.extend(m.decoder.pcm[drop * ch..(drop + give) * ch])
			return give
	0

# Back to the start of the stream.
pub fn rewindStream(mut s Stream):
	match s.source:
		Mp3(mut m):
			m.decoder.rewindMp3()
			m.skip = m.skipStart
			m.remaining = m.totalSamples
		Wav(mut w): w.rewindWav()
		Vorbis(mut v): v.rewindVorbis()
		Xwma(mut x): x.rewindXwma()

# A whole file decoded (WAV, MP3, Ogg Vorbis or xWMA), as ffmpeg decodes it.
pub fn decodeAudio(move bytes u8[]) wav.Pcm?:
	s = try openStream(move bytes)
	out = []
	while s.readStream(out) > 0:
		pass
	wav.Pcm(samples = out, channels = s.channels, sampleRate = s.sampleRate)

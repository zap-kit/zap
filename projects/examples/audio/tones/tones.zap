# The tone the audio examples play: a sine wave as mono samples.

# `frames` samples at `rate` of a sine of `hz`, at `volume` (1 the full range)
pub fn tone(hz f64, frames i64, rate i64, volume f64) f32[]:
	out = []
	for i in 0..frames:
		t = f64(i) / f64(rate)
		out.push(f32((t * hz * tau).sin() * volume))
	out

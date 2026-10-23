# What moves an actor's face: the lip track of the line it says (game.sound's mouthOf) and its
# blinks, both eyes closing together every few seconds, at times of their own for each actor.

import skyrim

blinkCycle = 4.5   # seconds: one blink in each, somewhere in its first 3.8
blinkSeconds = 0.24

# where in the cycle the actor's blink starts, in seconds
fn blinkStart(npc i64, cycle i64):
	mixed = (npc * 7919 + cycle * 104_729 + 17) * 2_654_435_761 % 65_521
	0.3 + 3.5 * f64(mixed) / 65521.0

# how closed the actor's eyes are `now` (0 open, 1 shut): a quick close and a quick open
pub fn blinkWeight(npc i64, now f64) f32:
	cycle = i64((now / blinkCycle).floor())
	x = (now - cycle * blinkCycle - blinkStart(npc, cycle)) / blinkSeconds
	if x < 0.0 or x > 1.0: return 0.0
	f32(1.0 - (2.0 * x - 1.0).abs())

# The weights of the lip targets (skyrim.lipTarget's order) of the actor `npc` `now`: those of
# its line's lip track while it speaks (`mouth`), with its blinks.
pub fn faceWeights(npc i64, mouth f32[]?, now f64) f32[]:
	out = mouth ?? fill(skyrim.lipPhonemes.len + skyrim.lipModifiers.len, 0.0)
	blink = blinkWeight(npc, now)
	eyes = skyrim.lipPhonemes.len   # BlinkLeft and BlinkRight open the modifiers
	for k in eyes..(eyes + 2):
		out[k] = out[k].max(blink)
	out

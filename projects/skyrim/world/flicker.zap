# A flickering light as it is at a time, as SkyrimSE.exe's flicker (0x140274be0) runs it from the
# LIGH record's period (a rate), intensity amplitude and movement: three phases advance each frame
# by a random share of the rate (uniform in 1.1..13.1, 1.2..13.2 and 1.3..19.3 times it) and wrap at
# a turn; the light's dimmer is its fade times 1 - amplitude / 2 + amplitude / 2 x f, with
# f = (sin(1.3 y + 0.65) + 1)(sin(1.1 x + 1.87) + 1) / 12 + 0.2 sin(3 z + 0.9) clamped to -1..1
# (0.76 to 0.91 of the fade at amplitude 0.4; RenderDoc captures of the game show 0.78 and 0.87),
# and it moves by its movement times sines of the same phases. Here each phase advances at its mean
# rate (the frames' random draws average to it) from a start each light offsets by its index, so a
# time gives one state. From the phases on it is the executable's arithmetic, operation for
# operation: its sine table, its constants (each angle's scale to table steps folded into the
# factor and the offset, as single floats), its order of operations; x64diffs.zap checks it.

import world.shaders

# table steps a radian, a single float
stepsPerRadian = f32(512.0 / (2.0 * pi))

# the game's 1/12: the single float below the nearest one
twelfth = f32.fromBits(0x3DAA_AAAA)

# The game's sine table (0x14331c6f0, filled at start by 0x140ef2ca0): entry k is the sine of the
# angle that k additions of a turn / 512 reach in single precision.
fn sineTableOf():
	step = f32(2.0 * pi / 512.0)
	angle = 0.0
	out = []
	loop 512:
		out.push(angle.sin())
		angle += step
	out

pub mut sineTable = sineTableOf()

# the table's entry at a scaled angle, truncated toward zero as the game's conversion does
fn sineAt(scaled f32):
	sineTable[i64(scaled) & 511]

# the scale of a sine's argument folded in table steps: factor x steps and offset x steps
fn scaled(factor f64, offset f64, v f32):
	v * f32(factor * 512.0 / (2.0 * pi)) + f32(offset * 512.0 / (2.0 * pi))

# What the flicker makes of a light at phases (x, y, z): its dimmer (of its fade) and its offset
# along the game's x, y and z (z up), from the record's amplitude and movement.
pub fn flickerAt(x f32, y f32, z f32, amplitude f32, movement f32, fade f32) (f32, f32, f32, f32):
	sx = sineAt((x + 1.7) * stepsPerRadian)
	sy = sineAt((y + 0.5) * stepsPerRadian)
	moved = movement * sx * sy * 0.5
	if moved + movement <= 0.0: moved = 0.0
	f = (sineAt(scaled(1.3, 0.65, y)) + 1.0) * twelfth * (sineAt(scaled(1.1, 1.87, x)) + 1.0) +
		sineAt(scaled(3.0, 0.9, z)) * 0.2
	if 1.0 <= f: f = 1.0
	if f <= -1.0: f = -1.0
	half = amplitude * 0.5
	dimmer = (half * f + (1.0 - half)) * fade
	(dimmer, moved * sx, moved * sy, moved * sineAt((z + 0.3) * stepsPerRadian))

# phase k of light `index` at `t` seconds: its mean rate times the period field, from the light's
# own start, wrapped at a turn
fn phaseOf(rate f32, period f32, t f32, index i64, k i64):
	turn = 2.0 * pi
	start = f32((index * 3 + k) * 37 % 100) / 100.0 * turn
	(start + rate * period * t) % turn

# the light `l`, the k-th of the cell, `t` seconds after the cell opened; a `pinned` dimmer above 0
# stands in for the flicker's own (a capture's state to compare with, main.zap --dimmers)
pub fn flickered(l shaders.PointLight, t f32, k i64, pinned f32) shaders.PointLight:
	period = l.flicker.x
	if period <= 0.0: return l.copy()
	x = phaseOf(7.1, period, t, k, 0)
	y = phaseOf(7.2, period, t, k, 1)
	z = phaseOf(10.3, period, t, k, 2)
	dimmer, gx, gy, gz = flickerAt(x, y, z, l.flicker.y, l.flicker.z, 1.0)
	strength = pinned if pinned > 0.0 else dimmer
	out = l.copy()
	# the game's offset along its x, y and z (z up), here y up
	out.place = (l.place.xyz + Vec3(gx, gz, -gy)).withW(l.place.w)
	out.color = (l.color.rgb * strength).withW(l.color.w)
	out

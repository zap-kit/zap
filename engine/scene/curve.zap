# Animation curves as Gamebryo's controllers keep them: values at key times (a float's in x, a
# point's in xyz, a flag's in x) sampled at any time: held, straight, or along Hermite's curve
# between the tangents its keys give (quadratic keys store theirs; Kochanek-Bartels' tension,
# continuity and bias make them, tbcTangents); and the time a curve is played at (its frequency,
# phase and span, looped, played back and forth, or held at its ends).

# a curve's way between its keys (Gamebryo's codes): straight
pub curveLinear = 1
# along the tangents its keys store
pub curveQuadratic = 2
# along the tangents tbcTangents makes
pub curveTbc = 3
# held at each key's value
pub curveConstant = 5

# a curve: its keys' times and values, and each key's tangents into it and out of it when it has
# them
pub type Curve:
	interpolation i64 = curveLinear
	times f32[] = []
	values Vec4[] = []
	incoming Vec4[] = []
	outgoing Vec4[] = []

# how a curve's time follows the game's (NiTimeController's fields)
pub type CurveTiming:
	frequency f32 = 1.0
	phase f32 = 0.0
	start f32 = 0.0
	stop f32 = 0.0
	cycle i64 = 0   # 0 loops, 1 goes back and forth, 2 holds the ends

# Kochanek-Bartels' tangents of each key from its neighbors' values and its tension, continuity
# and bias (x, y, z of `tbc`)
pub fn tbcTangents(mut k Curve, tbc Vec3[]):
	n = k.values.len
	for i in 0..n:
		p = k.values[i]
		before = p - k.values[i - 1] if i > 0 else Vec4(0.0, 0.0, 0.0, 0.0)
		after = k.values[i + 1] - p if i + 1 < n else Vec4(0.0, 0.0, 0.0, 0.0)
		t, c, b = tbc[i].x, tbc[i].y, tbc[i].z
		k.outgoing.push(before * ((1.0 - t) * (1.0 - c) * (1.0 + b) / 2.0) +
				after * ((1.0 - t) * (1.0 + c) * (1.0 - b) / 2.0))
		k.incoming.push(before * ((1.0 - t) * (1.0 + c) * (1.0 + b) / 2.0) +
				after * ((1.0 - t) * (1.0 - c) * (1.0 - b) / 2.0))

# the time on a curve played by `m` at the game's time `t`
pub fn curveTime(m CurveTiming, t f32) f32:
	at = t * m.frequency + m.phase
	span = m.stop - m.start
	if span <= 0.0: return m.start
	if m.cycle == 2: return at.clamp(m.start, m.stop)
	f = (at - m.start) / span
	whole = f.floor()
	part = f - whole
	if m.cycle == 1 and i64(whole) % 2 != 0: part = 1.0 - part
	m.start + part * span

# the curve's value at time t (the first key's before them, the last's after)
pub fn sampleCurve(k Curve, t f32) Vec4:
	n = k.times.len
	if n == 0: return Vec4(0.0, 0.0, 0.0, 0.0)
	if t <= k.times[0] or n == 1: return k.values[0]
	if t >= k.times[n - 1]: return k.values[n - 1]
	i = 0
	while k.times[i + 1] < t:
		i += 1
	a = k.values[i]
	b = k.values[i + 1]
	if k.interpolation == curveConstant: return a
	f = (t - k.times[i]) / (k.times[i + 1] - k.times[i]).max(1.0e-6)
	if k.outgoing.len != n: return a.lerp(b, f)
	# Hermite's basis between the two keys, their tangents the first's out and the second's in
	f2 = f * f
	f3 = f2 * f
	a * (2.0 * f3 - 3.0 * f2 + 1.0) + b * (3.0 * f2 - 2.0 * f3) +
		k.outgoing[i] * (f3 - 2.0 * f2 + f) +
		k.incoming[i + 1] * (f3 - f2)

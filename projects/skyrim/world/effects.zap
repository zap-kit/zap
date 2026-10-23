# The effects of a cell as time runs: each one's values (nif.Effect's) with what its controllers
# animate replaced by their tracks' values at the time, made into what the pixel stage reads.

import skyrim.nif
import world.shaders

# the angle of a falloff track, in degrees, as the cosine the effect keeps
fn cosineOf(degrees f32):
	degrees.radians().cos()

# effect e at the game's time t
pub fn effectState(e nif.Effect, t f32) shaders.EffectState:
	color = e.baseColor
	scale = e.scale
	alpha = 1.0
	uv = Vec4(e.uvOffset.x, e.uvOffset.y, e.uvScale.x, e.uvScale.y)
	falloff = e.falloff
	for k in e.tracks:
		v = k.sampleTrack(t)
		which = k.variable
		if which == nif.effectEmissiveMultiple: scale = v.x
		if which == nif.effectFalloffStartAngle: falloff.x = cosineOf(v.x)
		if which == nif.effectFalloffStopAngle: falloff.y = cosineOf(v.x)
		if which == nif.effectFalloffStartOpacity: falloff.z = v.x
		if which == nif.effectFalloffStopOpacity: falloff.w = v.x
		if which == nif.effectAlpha: alpha = v.x
		if which == nif.effectUOffset: uv.x = v.x
		if which == nif.effectVOffset: uv.y = v.x
		if which == nif.effectUScale: uv.z = v.x
		if which == nif.effectVScale: uv.w = v.x
		if which == nif.effectColor: color = v.xyz.withW(color.w)
	paletted = not e.palette.isEmpty
	mode = (1.0 if paletted and e.paletteColor else 0.0) +
		(2.0 if paletted and e.paletteAlpha else 0.0)
	shaders.EffectState(
		uv,
		color = color.rgb.withW(color.a * alpha),
		falloff,
		palette = Vec4(mode, scale, 1.0 if e.vertexAlpha else 0.0, 1.0 if e.vertexColors else 0.0),
		lighting = Vec4(e.lighting, e.soft, f32(e.clamp), 1.0 if e.external else 0.0)
	)

# The controllers that animate a model as time runs: of a shader's value (BSEffectShaderProperty's
# and BSLightingShaderProperty's float and color controllers, NiTextureTransformController), of a
# particle system (its emitter's birth rate, a modifier turned on and off), each through an
# interpolator (a float, a point, a bool: a constant or the keys of a data block, the engine's curves: engine/scene/curve.zap).

import engine

# the shader controllers: a float (or color) they animate, its number after the controller's fields
shaderControllers = [
	"BSEffectShaderPropertyFloatController", "BSEffectShaderPropertyColorController",
	"BSLightingShaderPropertyFloatController", "BSLightingShaderPropertyColorController"
]
# the particle systems' controllers of a modifier named after the interpolator
modifierControllers = [
	"NiPSysEmitterCtlr",
	"BSPSysMultiTargetEmitterCtlr",
	"NiPSysModifierActiveCtlr",
	"NiPSysEmitterInitialRadiusCtlr",
	"NiPSysEmitterSpeedCtlr", "NiPSysEmitterLifeSpanCtlr", "NiPSysGravityStrengthCtlr",
	"NiPSysEmitterDeclinationCtlr", "NiPSysEmitterPlanarAngleCtlr"
]

# the controllers of an emitter's birth rate and of whether it runs (Skyrim's multi-target one
# drives the emitter of every place a master particle system is attached)
emitterControllers = ["NiPSysEmitterCtlr", "BSPSysMultiTargetEmitterCtlr"]

# BSEffectShaderPropertyFloatController's variables (nif.xml's EffectShaderControlledVariable)
pub effectEmissiveMultiple = 0
pub effectFalloffStartAngle = 1
pub effectFalloffStopAngle = 2
pub effectFalloffStartOpacity = 3
pub effectFalloffStopOpacity = 4
pub effectAlpha = 5
pub effectUOffset = 6
pub effectUScale = 7
pub effectVOffset = 8
pub effectVScale = 9
# a color controller's variable: the color is the effect's base color
pub effectColor = 100

# NiTextureTransformController's operations (translate u, v, rotate, scale u, v) as the effect's
textureOperations = [effectUOffset, effectVOffset, -1, effectUScale, effectVScale]

pub type Controller:
	kind str
	next i64
	timing engine.CurveTiming
	target i64
	interpolator i64 = -1
	variable i64 = -1   # a shader controller's (the color controllers' + effectColor)
	modifier str = ""   # a particle controller's modifier, by name
	visibility i64 = -1   # an emitter controller's: the bool interpolator that turns it on

pub type Interpolator:
	value Vec4   # without keys
	data i64

# what a controller plays: its variable, from its interpolator's keys (none: the value)
pub type Track:
	variable i64
	timing engine.CurveTiming
	keys engine.Curve
	value Vec4

fn readKeyValue(mut s Reader, size i64):
	match size:
		0: Vec4(s.u8(), 0.0, 0.0, 0.0)
		1: Vec4(s.f32(), 0.0, 0.0, 0.0)
		_: s.vec3().withW(0.0)

# A key group of values of `size` (0 a byte, 1 a float, 3 a point): its count, its interpolation
# when it has keys, then each key's time, value and what its interpolation adds.
fn readKeys(mut s Reader, size i64):
	k = engine.Curve()
	n = s.u32()
	if n == 0: return k
	k.interpolation = s.u32()
	tbc = []
	loop n:
		if s.short: return engine.Curve()
		k.times.push(s.f32())
		k.values.push(s.readKeyValue(size))
		if k.interpolation == engine.curveQuadratic:
			k.incoming.push(s.readKeyValue(size))
			k.outgoing.push(s.readKeyValue(size))
		if k.interpolation == engine.curveTbc: tbc.push(s.vec3())
	if k.interpolation == engine.curveTbc: k.tbcTangents(tbc)
	k

# NiTimeController's fields: the next controller, the flags (the cycle in bits 1-2), frequency,
# phase, start and stop, the target
fn readTiming(mut s Reader):
	next = s.i32()
	flags = s.u16()
	frequency = s.f32()
	phase = s.f32()
	start = s.f32()
	stop = s.f32()
	timing = engine.CurveTiming(frequency, phase, start, stop, cycle = (flags >> 1) & 3)
	(next, timing, s.i32())

fn readController(mut s Reader, names str[], kind str):
	next, timing, target = s.readTiming()
	c = Controller(kind = kind.copy(), next, timing, target)
	if kind == "NiPSysUpdateCtlr": return c
	c.interpolator = s.i32()
	if kind in shaderControllers:
		c.variable = s.u32() + (effectColor if kind.endsWith("ColorController") else 0)
	if kind == "NiTextureTransformController":
		s.skip(5)   # whether a shader map, the texture slot
		op = s.u32()
		c.variable = textureOperations[op] if op < textureOperations.len else -1
	if kind in modifierControllers: c.modifier = s.readName(names)
	if kind in emitterControllers: c.visibility = s.i32()
	c

fn isController(kind str):
	kind in shaderControllers or kind in modifierControllers or kind == "NiPSysUpdateCtlr" or
		kind == "NiTextureTransformController"

# the interpolator of this kind, none for one not read here
fn readInterpolator(mut s Reader, kind str) Interpolator?:
	value = match kind:
		"NiFloatInterpolator": Vec4(s.f32(), 0.0, 0.0, 0.0)
		"NiPoint3Interpolator": s.vec3().withW(0.0)
		"NiBoolInterpolator", "NiBoolTimelineInterpolator": Vec4(s.u8(), 0.0, 0.0, 0.0)
		_: return none
	Interpolator(value, data = s.i32())

# the keys of a data block of this kind, none for one not read here
fn readKeyData(mut s Reader, kind str) engine.Curve?:
	match kind:
		"NiFloatData": s.readKeys(1)
		"NiPosData": s.readKeys(3)
		"NiBoolData": s.readKeys(0)
		_: none

# the controllers from block i on, following each one's next
pub fn controllerChain(n Nif, first i64) Controller[]:
	out = []
	i = first
	while i >= 0 and i < n.blocks.len and out.len < 64:
		match n.blocks[i]:
			ControllerBlock(c):
				out.push(c.copy())
				i = c.next
			_: return out
	out

# what interpolator i plays, with a controller's timing and variable
pub fn trackOf(n Nif, interpolator i64, variable i64, timing engine.CurveTiming) Track?:
	if interpolator < 0 or interpolator >= n.blocks.len: return none
	match n.blocks[interpolator]:
		InterpolatorBlock(p):
			keys = engine.Curve()
			if p.data >= 0 and p.data < n.blocks.len:
				if n.blocks[p.data] is KeysBlock(k): keys = k.copy()
			Track(variable, timing, keys, value = p.value)
		_: none

# the value a track gives at the game's time t
pub fn sampleTrack(k Track, t f32) Vec4:
	if k.keys.times.isEmpty: return k.value
	k.keys.sampleCurve(k.timing.curveTime(t))

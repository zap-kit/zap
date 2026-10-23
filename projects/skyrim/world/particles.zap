# The particle systems of a cell as they run, on the engine's particles (engine/scene/particles.zap):
# each emitter's particles born as its birth rate says (in its volume about its object, or at its
# mesh's vertices), pulled by its gravity, slowed by its drag, their color, alpha and size over
# their life as its modifiers say; drawn as quads facing the camera.

import engine
import skyrim.nif
import world.shaders

# a particle system placed in the cell, and how it is drawn
pub type Emitter:
	system nif.Particles
	place Mat4   # the model's space to the cell's (y up)
	effect i64   # its effect, in the cell's
	diffuse i32
	palette i32
	added bool   # its light adds up

# how much the system is scaled where it is placed
fn sizeOf(e Emitter):
	e.place.applyDirection(Vec3(1.0, 0.0, 0.0)).length()

# one particle born of an emission at `at`, sent along `toCell`'s axes (the emitter object's
# placed in the cell), turned as the rotation modifiers say
fn bear(mut s engine.Swarm, e Emitter, emission engine.Emission, at Vec3, toCell Mat4):
	p = s.random.bornParticle(emission, at, toCell, e.sizeOf(), e.system.subtextures.len)
	for m in e.system.modifiers:
		if m.modifier.kind is Rotation(spinSpeed, spinVariation, angle, angleVariation, randomSign):
			s.random.spinParticle(p, spinSpeed, spinVariation, angle, angleVariation, randomSign)
	s.particles.push(p)

# whether a modifier runs at time t: active, and on if a controller turns it on and off
fn runs(m nif.PlacedModifier, t f32):
	if not m.modifier.active: return false
	match m.running:
		k: k.sampleTrack(t).x > 0.5
		none: true

# the particles an emitter modifier bears over dt at time t (those its rate makes due)
fn emit(mut s engine.Swarm, e Emitter, m nif.PlacedModifier, t f32, dt f32):
	if not m.runs(t): return
	rate = m.rate ?? return
	s.owed += rate.sampleTrack(t).x * dt
	toCell = e.place @ m.object
	room = e.system.maxCount if e.system.maxCount > 0 else 1000
	while s.owed >= 1.0:
		s.owed -= 1.0
		if s.particles.len >= room: continue
		match m.modifier.kind:
			VolumeEmitter(emission, _, shape, size):
				s.bear(e, emission, toCell.applyPoint(s.random.volumePoint(shape, size)), toCell)
			MeshEmitter(emission, _):
				if m.points.isEmpty: continue
				at = m.points[s.random.nextInt(0, len)]
				s.bear(e, emission, e.place.applyPoint(at), toCell)
			_: return

# what a modifier does to a particle's velocity over dt (gravity, with its turbulence shaking it
# along `shake`; drag)
fn pullBy(e Emitter, m nif.PlacedModifier, mut p engine.Particle, shake Vec3, dt f32):
	toCell = e.place @ m.object
	match m.modifier.kind:
		Gravity(_, axis, decay, strength, spherical, turbulence):
			force = toCell.applyDirection(axis).normalized()
			if spherical: force = p.pullToward(toCell.applyPoint(Vec3(0.0, 0.0, 0.0)), decay)
			p.pullParticle(force, strength, shake, turbulence, e.sizeOf(), dt)
		Drag(_, _, percentage): p.dragParticle(percentage, dt)
		_: return

# the swarm moved on by dt to time t: its particles aged, the dead gone, the rest pulled and
# moved, then those due born
pub fn runSwarm(mut s engine.Swarm, e Emitter, t f32, dt f32):
	shakes = s.ageSwarm(dt)
	for i, mut p in s.particles:
		for m in e.system.modifiers:
			if m.runs(t): e.pullBy(m, p, shakes[i], dt)
		p.moveParticle(dt)
	for m in e.system.modifiers:
		s.emit(e, m, t, dt)

# the color of a particle at f of its life: the color modifier's, else the emission's
fn colorAt(e Emitter, f f32):
	for m in e.system.modifiers:
		if m.modifier.kind is SimpleColor(fadeIn, fadeOut, times, colors):
			return engine.colorOverLife(fadeIn, fadeOut, times, colors, f)
	for m in e.system.modifiers:
		match m.modifier.kind:
			VolumeEmitter(emission, _, _, _): return emission.color
			MeshEmitter(emission, _): return emission.color
			_: continue
	Vec4(1.0, 1.0, 1.0, 1.0)

# a particle's size at f of its life, as the scale modifier says
fn scaleAt(e Emitter, f f32):
	for m in e.system.modifiers:
		if m.modifier.kind is Scale(scales): return engine.scaleOverLife(scales, f)
	1.0

# a particle's width over its height at this speed (in the model's units), as the system's aspect says
fn aspectAt(a nif.Aspect, speed f32) f32:
	if (a.flags & 0x1) == 0: return 1.0
	if (a.flags & 0x100) == 0 or a.speed2 <= a.speed1: return a.ratio
	t = ((speed - a.speed1) / (a.speed2 - a.speed1)).clamp(0.0, 1.0)
	a.ratio + (a.ratio2 - a.ratio) * t

# the swarm's particles as quads of two triangles facing the camera (its right and up)
pub fn swarmQuads(s engine.Swarm, e Emitter, right Vec3, up Vec3, mut out shaders.CellVertex[]):
	facing = right.cross(up)
	material = Vec4(f32(e.effect), 1.0, 0.0, 2.0 if e.added else 1.0)
	for p in s.particles:
		f = p.age / p.life
		color = e.colorAt(f)
		size = p.radius * e.scaleAt(f)
		ratio = e.system.aspect.aspectAt(p.velocity.length() / e.sizeOf())
		across, upward = p.quadAxes(size, right, up)
		# the ratio taken as the quad's height over its width shrinking: the candle's flame at
		# 0.42 stands 2.4 times as tall as wide, as the captures show it
		upward *= 1.0 / ratio
		cell = e.system.subtextures[p.cell] if p.cell >= 0 else Vec4(0.0, 1.0, 0.0, 1.0)
		for c in engine.particleCorners:
			out.push(shaders.CellVertex(
				position = p.position + across * c.x + upward * c.y,
				normal = facing,
				tangent = right.withW(1.0),
				uv = cell.atlasUv(c),
				color,
				material,
				diffuse = e.diffuse,
				normalMap = e.palette,
				billboard = -1))

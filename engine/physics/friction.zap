# A manifold's friction as Havok's contact constraint makes it (read from SkyrimSE.exe's contact
# jacobians and solver): one 2D friction at the center of the points, along two tangents made from
# a world axis kept from step to step while it stays off the normal, and about the normal when
# there are two points or more. Its two tangent rows are solved together (their 2x2 mass), and
# each pass's impulse (the turn's as a force at the points' farthest reach from the center) is cut
# to the friction times last step's normal impulses over the passes of a step: friction bounded
# by the load the manifold carried. An anchor holds what static friction holds: the slide (and
# turn) the friction let pass while it held, asked back at friction's tau (half the solver's), and
# shrunk by the share the bound let through when it slipped. A manifold that carried nothing last
# step has no friction this step.

# a manifold's friction: what is kept from step to step, and this step's rows
pub type Grip:
	axis i64 = -1   # the world axis the tangents are made from, none yet
	load f32 = 0.0   # the normal impulse the manifold gave last step
	anchor Vec3 = Vec3(0, 0, 0)   # the slide along both tangents and the turn about the normal held
	held f32 = 1.0   # the share of its impulse the bound let through on the last pass
	on bool = false
	tangent Vec3 = Vec3(0, 0, 0)
	bitangent Vec3 = Vec3(0, 0, 0)
	armA Vec3 = Vec3(0, 0, 0)   # the center's arms
	armB Vec3 = Vec3(0, 0, 0)
	mass Vec3 = Vec3(0, 0, 0)   # the damping times the inverse of the tangents' 2x2 K: 00, 01, 11
	turnMass f32 = 0.0   # about the normal, 0 with one point
	reach f32 = 0.0   # the farthest point from the center
	most f32 = 0.0   # the largest impulse of a pass
	rhs Vec3 = Vec3(0, 0, 0)   # the velocities asked for: along both tangents, about the normal

keepAxisSquared f32 = 0.1   # the tangents' axis is kept while |normal x axis|^2 is above this

# the world's axis farthest from n
fn offAxis(n Vec3):
	a = n.abs()
	if a.x <= a.y and a.x <= a.z: return 0
	1 if a.y <= a.z else 2

fn worldAxis(i i64):
	Vec3(1, 0, 0) if i == 0 else (Vec3(0, 1, 0) if i == 1 else Vec3(0, 0, 1))

# this step's friction rows of the manifold, none when it carried nothing last step
pub fn prepareGrip(mut m Manifold, bodies Body[], s StepInfo):
	g = mut ref m.grip
	g.on = g.load > 0.0 and m.friction > 0.0 and not m.contacts.isEmpty
	if not g.on:
		g.anchor = Vec3(0, 0, 0)
		return
	n = m.normal
	off = n.cross(worldAxis(g.axis.max(0)))
	if g.axis < 0 or off @ off <= keepAxisSquared:
		g.axis = n.offAxis()
		g.anchor = Vec3(0, 0, 0)
	g.tangent = worldAxis(g.axis).cross(n).normalized()
	g.bitangent = n.cross(g.tangent)
	center = Vec3(0, 0, 0)
	for c in m.contacts:
		center += c.point / f32(m.contacts.len)
	g.armA = center - bodies[m.a].position
	g.armB = center - bodies[m.b].position if m.b >= 0 else Vec3(0, 0, 0)
	t = g.tangent
	u = g.bitangent
	ktt = response(bodies, m.a, m.b, g.armA, g.armB, t, g.armA, g.armB, t)
	ktu = response(bodies, m.a, m.b, g.armA, g.armB, t, g.armA, g.armB, u)
	kuu = response(bodies, m.a, m.b, g.armA, g.armB, u, g.armA, g.armB, u)
	det = ktt * kuu - ktu * ktu
	g.mass = Vec3(kuu, -ktu, ktt) * (s.damping / det) if det > 0.0 else Vec3(0, 0, 0)
	g.reach = m.contacts.map((.point - center).length()).max() ?? 0.0
	g.turnMass = 0.0
	if m.contacts.len >= 2 and g.reach > 1.0e-3:
		k = turnResponse(bodies, m.a, n) + turnResponse(bodies, m.b, n)
		g.turnMass = s.damping / k if k > 0.0 else 0.0
	g.most = m.friction * g.load / f32(s.subSteps * s.microSteps)
	g.rhs = g.anchor * -s.frictionRhsFactor

# what a turning impulse about the unit axis does to body i's spin about it
fn turnResponse(bodies Body[], i i64, axis Vec3) f32:
	if i < 0 or bodies[i].asleep: return 0.0
	(bodies[i].invInertiaWorld @ axis) @ axis

# the relative spin of b against a
fn relativeSpin(bodies Body[], a i64, b i64):
	sb = bodies[b].spin if b >= 0 else Vec3(0, 0, 0)
	sb - bodies[a].spin

fn twist(mut bodies Body[], i i64, torque Vec3):
	if i < 0 or bodies[i].asleep: return
	bodies[i].spin += bodies[i].invInertiaWorld @ torque

# one pass of the manifold's friction
pub fn solveGrip(mut m Manifold, mut bodies Body[]):
	g = m.grip.copy()
	if not g.on: return
	v = relativeVelocity(bodies, m.a, m.b, g.armA, g.armB)
	et = g.rhs.x - v @ g.tangent
	eu = g.rhs.y - v @ g.bitangent
	jt = g.mass.x * et + g.mass.y * eu
	ju = g.mass.y * et + g.mass.z * eu
	jn = 0.0
	if g.turnMass > 0.0: jn = g.turnMass * (g.rhs.z - relativeSpin(bodies, m.a, m.b) @ m.normal)
	force = jn / g.reach if g.turnMass > 0.0 else 0.0
	size = (jt * jt + ju * ju + force * force).sqrt()
	held = g.most / size if size > g.most else 1.0
	apply(bodies, m.a, m.b, g.armA, g.armB, (g.tangent * jt + g.bitangent * ju) * held)
	if jn != 0.0:
		twist(bodies, m.a, m.normal * (-jn * held))
		twist(bodies, m.b, m.normal * (jn * held))
	m.grip.held = held

# the anchor after the step: the slide and turn of the step's mean motion added, shrunk by the
# share the bound let through
pub fn keepGrip(mut m Manifold, bodies Body[], dt f32):
	g = mut ref m.grip
	if not g.on: return
	slide = (meanAt(bodies, m.b, g.armB) - meanAt(bodies, m.a, g.armA)) * dt
	turned = 0.0
	if g.turnMass > 0.0:
		turned = ((meanSpinOf(bodies, m.b) - meanSpinOf(bodies, m.a)) @ m.normal) * dt
	g.anchor = (g.anchor + Vec3(slide @ g.tangent, slide @ g.bitangent, turned)) * g.held

# body i's mean spin this step, none for the scene or a sleeping body
fn meanSpinOf(bodies Body[], i i64):
	if i < 0 or bodies[i].asleep: return Vec3(0, 0, 0)
	bodies[i].meanSpin

# the mean velocity this step of body i's point at the arm
fn meanAt(bodies Body[], i i64, arm Vec3):
	if i < 0 or bodies[i].asleep: return Vec3(0, 0, 0)
	bodies[i].meanVelocity + bodies[i].meanSpin.cross(arm)

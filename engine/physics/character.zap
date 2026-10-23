# A character controller in the manner of Havok's character proxy: an upright capsule moved by the
# velocity it wants, pushed out of the scene's triangles (up off floors, aside from walls, down from
# ceilings), stepping up what is no higher than its step, kept on a floor it walks over (one no
# steeper than its slope; steeper is a wall), falling where there is none, and nudging the bodies
# in its way.

# an upright capsule walked through the scene: its feet, size, step and steepest floor
pub type Character:
	feet Vec3   # the capsule's lowest point
	radius f32
	height f32   # from the feet to the top
	stepHeight f32
	floorCosine f32   # the cosine of the steepest slope it walks
	pushShare f32 = 0.5   # the share of its speed it gives a body in its way
	layer i64 = -1   # its collision layer: it nudges only the bodies whose layer the world lets it meet
	falling f32 = 0.0   # its speed down
	onFloor bool = false

# a contact of the capsule: the direction out of the triangle, how deep it is in, and whether it
# holds the capsule up (a walkable triangle met below the capsule's lower center, its edge too)
type Overlap:
	normal Vec3
	depth f32
	holds bool

# a character standing at `feet`, walking slopes up to maxSlope radians
pub fn characterOf(feet Vec3, radius f32, height f32, stepHeight f32, maxSlope f32) Character:
	Character(feet, radius, height, stepHeight, floorCosine = maxSlope.cos())

holdFirst f32 = 0.05

fn axisAt(c Character, feet Vec3):
	(feet + Vec3(0, 0, c.radius), feet + Vec3(0, 0, c.height - c.radius))

# the scene's triangles the capsule standing at `feet` is in
fn overlapsAt(c Character, mut s Scene, feet Vec3):
	p0, p1 = c.axisAt(feet)
	r = Vec3(c.radius, c.radius, c.radius)
	out = []
	for t in s.trianglesNear(p0 - r, p1 + r):
		onAxis, onTriangle = closestOnSegmentTriangle(
			p0,
			p1,
			s.corner(t, 0),
			s.corner(t, 1),
			s.corner(t, 2)
		)
		apart = onAxis - onTriangle
		distance = apart.length()
		if distance >= c.radius: continue
		n = s.normals[t]
		normal = apart / distance if distance > 1.0e-4
			else (n if ((p0 + p1) * 0.5 - s.corner(t, 0)) @ n >= 0.0 else -n)
		holds = normal.z >= c.floorCosine or (n.z.abs() >= c.floorCosine and normal.z > 0.01)
		out.push(Overlap(normal, depth = c.radius - distance, holds))
	out

# the capsule at `feet` pushed out of the scene, the deepest overlap first (one that holds it up
# before a wall as deep): up off a floor, aside from a wall, along the normal from a ceiling;
# whether a floor held it
fn resolved(c Character, mut s Scene, feet Vec3):
	at = feet
	floor = false
	loop 8:
		hits = c.overlapsAt(s, at)
		if hits.isEmpty: break
		deepest = hits.maxBy(.depth + (holdFirst if .holds else 0.0)) ?? break
		n = deepest.normal
		lift = deepest.depth + 0.01
		if deepest.holds:
			at.z += lift / n.z
			floor = true
		elif n.z > -c.floorCosine and Vec2(n.x, n.y).length() > 1.0e-3:
			aside = Vec3(n.x, n.y, 0).normalized()
			at += aside * (lift / (aside @ n))
		else:
			at += n * lift
	(at, floor)

# the capsule let down from `feet` by up to `distance`, in steps of half its radius; where it
# stops and whether a floor stopped it
fn lowered(c Character, mut s Scene, feet Vec3, distance f32):
	at = feet
	left = distance
	while left > 0.0:
		down = left.min(c.radius * 0.5)
		left -= down
		pushed, floor = c.resolved(s, at - Vec3(0, 0, down))
		at = pushed
		if floor: return (at, true)
	(at, false)

fn across(from Vec3, to Vec3):
	Vec2(to.x - from.x, to.y - from.y).length()

# one move by `by` (no longer than half the radius) over dt: slid along the walls, stepped up
# where that goes farther, then kept on the floor or falling
fn moveOnce(mut c Character, mut s Scene, by Vec3, dt f32, gravity f32):
	start = c.feet
	best, _ = c.resolved(s, start + by)
	if c.onFloor and start.across(best) < 0.99 * start.across(start + by):
		raised, _ = c.resolved(s, start + Vec3(0, 0, c.stepHeight))
		over, _ = c.resolved(s, raised + by)
		landed, found = c.lowered(s, over, raised.z - start.z + 1.0)
		# the raised capsule's round bottom holds on an edge up to its radius higher: no step
		climbed = landed.z - start.z <= c.stepHeight + 0.5
		if found and climbed and start.across(landed) > start.across(best) + 0.01: best = landed
	if c.onFloor:
		kept, found = c.lowered(s, best, c.stepHeight)
		if found:
			c.feet = kept
			c.falling = 0.0
			return
		c.onFloor = false
	c.falling += gravity * dt
	fallen, landed = c.lowered(s, best, c.falling * dt)
	c.feet = fallen
	if landed:
		c.onFloor = true
		c.falling = 0.0

# the bodies whose bounds the capsule reaches given at least pushShare of its speed away from it
fn nudge(c Character, mut w World, wanted Vec3):
	p0, p1 = c.axisAt(c.feet)
	r = Vec3(c.radius, c.radius, c.radius)
	for i in 0..w.bodies.len:
		if not w.layersMeet(c.layer, w.bodies[i].layer): continue
		b = mut ref w.bodies[i]
		if not b.lo.boxesMeet(b.hi, p0 - r, p1 + r, 0.0): continue
		away = Vec3(b.position.x - c.feet.x, b.position.y - c.feet.y, 0)
		if away.length() < 1.0e-3: continue
		away = away.normalized()
		speed = (wanted @ away) * c.pushShare
		if speed <= b.velocity @ away: continue
		b.velocity += away * (speed - b.velocity @ away)
		b.wake()

# The character moved for dt seconds at the velocity it wants (its height left to the floor and
# gravity), in moves no longer than half its radius; where its feet are then.
pub fn walk(mut c Character, mut w World, wanted Vec3, dt f32) Vec3:
	by = Vec3(wanted.x, wanted.y, 0) * dt
	moves = i64((by.length() / (c.radius * 0.5)).ceil()).max(1)
	g = -w.gravity().z
	loop moves:
		c.moveOnce(w.scene, by / f32(moves), dt / f32(moves), g)
	c.nudge(w, wanted)
	c.feet

# The physics without the game: shapes made by hand, dropped, stacked, slid and walked against.

import math
import engine.physics

unitsPerMeter f32 = 70.0

# a floor of two triangles, size units square, at height z, tilted `slope` radians about x
fn floorWorld(size f32, slope f32, friction f32):
	w = physics.worldOf(unitsPerMeter)
	c = slope.cos()
	s = slope.sin()
	corners = [
		Vec3(-size, -size * c, -size * s),
		Vec3(size, -size * c, -size * s),
		Vec3(size, size * c, size * s),
		Vec3(-size, size * c, size * s)
	]
	w.addSurface(corners, [0, 1, 2, 0, 2, 3], friction, 1.0)
	w

fn boxPiece(at Vec3, half Vec3):
	positions, indices = half.boxTriangles()
	physics.Piece(positions = positions.map(it + at), indices)

fn ballPiece(at Vec3, radius f32):
	positions, indices = at.roundTriangles(at, radius)
	physics.Piece(round = .Ball(at, at, radius), positions, indices)

test "a sphere dropped on a floor of triangles comes to rest at its radius, asleep":
	w = floorWorld(500.0, 0.0, 0.5)
	i = w.addBody("ball", [ballPiece(Vec3(10, 20, 100), 10.0)], 1.0, 0.5, 0.0)
	w.step(3.0)
	b = w.bodies[i]
	print("{b.position} {b.asleep}")
	expect b.position.z.isClose(10.0, 0.5)
	expect b.asleep

# a box of half size 10 resting on the floor of floorWorld, turned with it, its travel after `seconds`
fn slideOnSlope(slope f32, friction f32, seconds f32):
	w = floorWorld(500.0, slope, friction)
	turn = Mat4.rotationX(slope)
	piece = boxPiece(Vec3(0, 0, 0), Vec3(10, 10, 10))
	placed = piece.positions.map(turn.applyPoint(it + Vec3(0, 0, 10.2)))
	i = w.addBody(
		"box",
		[physics.Piece(positions = placed, indices = piece.indices)],
		2.0,
		friction,
		0.0
	)
	start = w.bodies[i].position
	w.step(seconds)
	(w.bodies[i].position - start).length()

test "a box on a 30 degree slope slides with low friction and holds with high":
	slope = f32(30.0).radians()
	slid = slideOnSlope(slope, 0.1, 1.0)
	held = slideOnSlope(slope, 0.9, 1.0)
	print("{slid:.1} {held:.2}")
	expect slid > 100.0
	expect held < 1.0

test "two stacked boxes come to rest, one on the other, and sleep":
	w = floorWorld(500.0, 0.0, 0.6)
	low = w.addBody("low", [boxPiece(Vec3(0, 0, 10.5), Vec3(10, 10, 10))], 3.0, 0.6, 0.0)
	high = w.addBody("high", [boxPiece(Vec3(2, 1, 31.5), Vec3(10, 10, 10))], 3.0, 0.6, 0.0)
	w.step(4.0)
	print("{w.bodies[low].position} {w.bodies[high].position} {w.bodies[low].asleep} {w.bodies[high].asleep}")
	expect w.bodies[low].position.z.isClose(10.0, 0.5) and
		w.bodies[high].position.z.isClose(30.0, 1.0)
	expect w.bodies[low].asleep and w.bodies[high].asleep

# a ball of this restitution dropped from 200 units: where it rests after 5 s, and how many times
# it left the floor again
fn dropBall(restitution f32):
	w = floorWorld(500.0, 0.0, 0.5)
	i = w.addBody("ball", [ballPiece(Vec3(0, 0, 200), 10.0)], 1.0, 0.5, restitution)
	bounces = 0
	rising = false
	loop 300:
		w.step(1.0 / 60.0)
		up = w.bodies[i].velocity.z > 10.0
		if up and not rising: bounces += 1
		rising = up
	(w.bodies[i].position, bounces)

test "a bouncy ball bounces, then rests; the same drop gives the same frames":
	at, bounces = dropBall(0.5)
	again, twice = dropBall(0.5)
	dull, still = dropBall(0.0)
	print("{at} {bounces} {dull} {still}")
	expect at == again and twice == bounces
	expect at.z.isClose(10.0, 0.5) and dull.z.isClose(10.0, 0.5)
	expect bounces >= 3 and still == 0

# A player's capsule (Skyrim's size) standing at x = 0 on floorWorld's floor, a block of this
# height ahead of it from x = 100 on, walked toward +x at 200 units a second for `seconds`
fn walkToBlock(height f32, seconds f32):
	w = floorWorld(1000.0, 0.0, 0.5)
	block = boxPiece(Vec3(300, 0, height * 0.5), Vec3(200, 300, height * 0.5))
	w.addSurface(block.positions, block.indices, 0.5, 0.0)
	c = physics.characterOf(Vec3(0, 0, 2), 15.0, 128.0, 20.0, f32(45.0).radians())
	loop i64(seconds * 60.0):
		c.walk(w, Vec3(200, 0, 0), 1.0 / 60.0)
	c

test "the controller walks into a wall and stops against it, on the floor":
	c = walkToBlock(300.0, 2.0)
	print("{c.feet} {c.onFloor}")
	expect c.feet.x.isClose(85.0, 1.0) and c.feet.z.isClose(0.0, 0.5) and c.onFloor

test "the controller steps up a 15-unit step and not a 40-unit one":
	low = walkToBlock(15.0, 1.5)
	high = walkToBlock(40.0, 1.5)
	print("{low.feet} {high.feet}")
	expect low.feet.x.isClose(300.0, 2.0) and low.feet.z.isClose(15.0, 0.5) and low.onFloor
	expect high.feet.x.isClose(85.0, 1.0) and high.feet.z.isClose(0.0, 0.5) and high.onFloor

# The joints (constraints.zap) in a world without a floor: rods of boxes 50 units long, along x,
# swinging about y.
fn rodBody(mut w physics.World, center Vec3):
	i = w.addBody("rod", [center.boxPiece(Vec3(25, 3, 3))], 2.0, 0.5, 0.0)
	w.bodies[i].angularDamping = 0.5
	w.bodies[i].linearDamping = 0.5
	i

# the axes of a hinge about y: the axle, x (its zero) and their cross product
swingAxes = Mat3(Vec3(0, 1, 0), Vec3(1, 0, 0), Vec3(0, 0, -1))

# Havok's far deactivation check (0.08 m) puts the chain to sleep while it still swings a little.
test "a chain of two hinged rods let go level hangs down from its anchor and sleeps there":
	w = physics.worldOf(unitsPerMeter)
	top = w.rodBody(Vec3(25, 0, 0))
	low = w.rodBody(Vec3(75, 0, 0))
	w.addJoint(.Hinge, top, -1, physics.Frame(pivot = Vec3(0, 0, 0), axes = swingAxes),
		physics.Frame(pivot = Vec3(0, 0, 0), axes = swingAxes))
	w.addJoint(.Hinge, low, top, physics.Frame(pivot = Vec3(50, 0, 0), axes = swingAxes),
		physics.Frame(pivot = Vec3(50, 0, 0), axes = swingAxes))
	w.step(20.0)
	a = w.bodies[top].position
	b = w.bodies[low].position
	print("{a} {b}")
	expect a.x.abs() < 4.0 and a.z.isClose(-25.0, 1.0) and a.y.abs() < 0.1
	expect b.x.abs() < 4.0 and b.z.isClose(-75.0, 1.5)
	expect w.bodies[top].asleep and w.bodies[low].asleep

test "a limited hinge stops its rod at its limit":
	w = physics.worldOf(unitsPerMeter)
	rod = w.rodBody(Vec3(25, 0, 0))
	w.addJoint(
		.LimitedHinge(-0.5, 0.5),
		rod,
		-1,
		physics.Frame(pivot = Vec3(0, 0, 0), axes = swingAxes),
		physics.Frame(pivot = Vec3(0, 0, 0), axes = swingAxes))
	w.step(3.0)
	c = w.bodies[rod].position
	print("{c} {(-c.z).atan2(c.x)}")
	expect (-c.z).atan2(c.x).isClose(0.5, 0.03) and c.length().isClose(25.0, 0.5)

test "a ragdoll joint keeps its rod's twist axis within its cone":
	w = physics.worldOf(unitsPerMeter)
	rod = w.rodBody(Vec3(25, 0, 0))
	axes = Mat3(Vec3(1, 0, 0), Vec3(0, 0, 1), Vec3(0, -1, 0))
	w.addJoint(
		.Ragdoll(0.5, -1.5, 1.5, -1.0, 1.0),
		rod,
		-1,
		physics.Frame(pivot = Vec3(0, 0, 0), axes),
		physics.Frame(pivot = Vec3(0, 0, 0), axes))
	widest f32 = 0.0
	angle f32 = 0.0
	loop 180:
		w.step(1.0 / 60.0)
		d = w.bodies[rod].position.normalized()
		angle = d.x.clamp(-1.0, 1.0).acos()
		widest = widest.max(angle)
	print("{w.bodies[rod].position} {widest} {angle}")
	# Havok's limit row closes a share tau x 0.8 of the error a step (havok-solver.md), so the fall
	# overshoots the cone a little on impact and comes to rest on it
	expect angle.isClose(0.5, 0.03) and widest < 0.6

test "a stiff spring keeps its body at its length from the anchor":
	w = physics.worldOf(unitsPerMeter)
	ball = w.addBody("ball", [ballPiece(Vec3(50, 0, 0), 5.0)], 1.0, 0.5, 0.0)
	w.addJoint(.Spring(50.0), ball, -1, physics.Frame(pivot = Vec3(50, 0, 0), axes = Mat3(1.0)),
		physics.Frame(pivot = Vec3(0, 0, 0), axes = Mat3(1.0)))
	worst f32 = 0.0
	lowest f32 = 0.0
	loop 180:
		w.step(1.0 / 60.0)
		worst = worst.max((w.bodies[ball].position.length() - 50.0).abs())
		lowest = lowest.min(w.bodies[ball].position.z)
	print("{w.bodies[ball].position} {worst} {lowest}")
	expect worst < 1.0 and lowest < -49.0

test "a body's own speed cap holds it below the world's":
	w = physics.worldOf(unitsPerMeter)
	i = w.addBody("ball", [ballPiece(Vec3(0, 0, 0), 10.0)], 1.0, 0.5, 0.0)
	w.bodies[i].maxSpeed = 5.0 * unitsPerMeter
	w.step(2.0)
	expect w.bodies[i].velocity.length() <= 5.0 * unitsPerMeter + 0.01

test "a slow body in a deactivation class loses its velocity each sub-step, a crawling one all of it, a fast one none":
	w = physics.worldOf(unitsPerMeter)
	slow = physics.Slowing(0.1, 0.1, 0.9, 0.05)
	speeds f32[] = [0.05, 0.004, 1.0]
	kept f32[] = [0.045, 0.0, 1.0]
	for k, speed in speeds:
		i = w.addBody("ball", [ballPiece(Vec3(f32(k) * 500.0, 0, 0), 10.0)], 1.0, 0.5, 0.0)
		w.bodies[i].slow = slow
		w.bodies[i].velocity = Vec3(speed * unitsPerMeter, 0, 0)
		w.bodies[i].slowDown(unitsPerMeter)
		expect w.bodies[i].velocity.x.isClose(kept[k] * unitsPerMeter, 0.01)

# one solver step of the world's joints without gravity or contacts
fn solveOnce(mut w physics.World, dt f32):
	s = w.solver.stepOf(w.unitsPerMeter, Vec3(0, 0, 0), dt)
	physics.solve(w.bodies, w.manifolds, w.joints, s)

test "a ball and socket asks 144 times its gap and leaves (1 - tau) to the 4 of it after a step":
	w = physics.worldOf(unitsPerMeter)
	ball = w.addBody("ball", [ballPiece(Vec3(50, 0, 0), 5.0)], 1.0, 0.5, 0.0)
	w.addJoint(.Ball, ball, -1, physics.Frame(pivot = Vec3(50, 0, 0), axes = Mat3(1.0)),
		physics.Frame(pivot = Vec3(50, 3, 0), axes = Mat3(1.0)))
	w.solveOnce(1.0 / 60.0)
	rows = w.joints[0].rows
	expect rows.len == 3 and rows[0].rhs.abs() < 1.0e-3 and rows[1].rhs.isClose(-432.0, 0.01)
	expect rows[1].mass.isClose(1.0 / w.bodies[ball].invMass, 1.0e-3)
	closed = w.bodies[ball].meanVelocity.y / 60.0
	left f32 = 0.4 * 0.4 * 0.4 * 0.4
	whole f32 = 3.0
	print("{closed} {whole * (1.0 - left)}")
	expect closed.isClose(whole * (1.0 - left), 0.002)

# a world with a rod body and a joint of this kind from the origin frame to one turned `angle` about z
fn ragdollRod(angle f32, kind physics.JointKind):
	w = physics.worldOf(unitsPerMeter)
	rod = w.rodBody(Vec3(0, 0, 0))
	c = angle.cos()
	s = angle.sin()
	apart = Mat3(Vec3(c, s, 0), Vec3(-s, c, 0), Vec3(0, 0, 1))
	w.addJoint(kind, rod, -1,
		physics.Frame(pivot = Vec3(0, 0, 0), axes = Mat3(1.0)),
		physics.Frame(pivot = Vec3(0, 0, 0), axes = apart))
	(w, rod)

# the impulse of a ragdoll joint's cone row (slot 7) when b's twist axis is turned `angle` from a's
fn coneImpulse(angle f32):
	w, _ = ragdollRod(angle, .Ragdoll(0.5, -1.5, 1.5, -1.0, 1.0))
	w.solveOnce(1.0 / 60.0)
	w.joints[0].impulses[7]

test "a cone limit holds nothing inside its angle and pushes back past it":
	expect coneImpulse(0.3).abs() < 1.0e-6
	expect coneImpulse(0.8) < -1.0e-3

test "angular friction cuts each pass to its torque over the sub-step, 4 passes in a step":
	w = physics.worldOf(unitsPerMeter)
	rod = w.rodBody(Vec3(0, 0, 0))
	j = w.addJoint(.Hinge, rod, -1, physics.Frame(pivot = Vec3(0, 0, 0), axes = swingAxes),
		physics.Frame(pivot = Vec3(0, 0, 0), axes = swingAxes))
	w.joints[j].friction = 0.5
	w.bodies[rod].spin = Vec3(0, 200, 0)
	w.solveOnce(1.0 / 60.0)
	given = w.joints[j].impulses[9]
	print("{given} {w.bodies[rod].spin}")
	most f32 = -0.5 / 60.0
	expect given.isClose(most, 1.0e-5)

test "a twist limit holds its angle within a hair, whether its axes are swung apart or not":
	swings f32[] = [0.0, 0.5, 1.0]
	for swing in swings:
		w, rod = ragdollRod(swing, .Ragdoll(1.2, -1.5, 1.5, -0.17, 0.17))
		c = swing.cos()
		s = swing.sin()
		w.bodies[rod].spin = (Vec3(c, s, 0) + Vec3(1, 0, 0)).normalized() * 4.0
		widest f32 = 0.0
		loop 120:
			w.step(1.0 / 60.0)
			at = w.joints[0].jointPlace(w.bodies)
			widest = widest.max(at.xa.twistAngle(at.xb).abs())
		print("{swing} {widest}")
		expect widest > 0.16 and widest < 0.19

# a 9 x 9 grid 100 units apart rising 0.2 per unit along x, a 5-unit hump at its middle vertex
fn rampGrid():
	heights = []
	for r in 0..9:
		for c in 0..9:
			heights.push(f32(c) * 20.0 + (5.0 if r == 4 and c == 4 else 0.0))
	heights

test "the grid's height follows its triangles, and none outside":
	heights = rampGrid()
	expect (physics.gridHeight(heights, 9, 100.0, 0.0, 0.0) ?? -1.0).isClose(0.0, 0.001)
	expect (physics.gridHeight(heights, 9, 100.0, 450.0, 400.0) ?? 0.0).isClose(92.5, 0.001)
	expect (physics.gridHeight(heights, 9, 100.0, 350.0, 750.0) ?? 0.0).isClose(70.0, 0.001)
	expect (physics.gridHeight(heights, 9, 100.0, 800.0, 800.0) ?? 0.0).isClose(160.0, 0.001)
	expect physics.gridHeight(heights, 9, 100.0, -1.0, 0.0) == none
	expect physics.gridTriangles(9).len == 8 * 8 * 6

test "a body rests on the heightfield and the controller walks up its ramp":
	w = physics.worldOf(unitsPerMeter)
	w.addHeightfield(1, rampGrid(), 9, 100.0, Vec2(-400.0, -400.0), 0.5, 0.0)
	c = physics.characterOf(Vec3(-300, 0, 0), 15.0, 128.0, 20.0, f32(45.0).radians())
	loop 60:
		c.walk(w, Vec3(0, 0, 0), 1.0 / 60.0)
	expect c.onFloor and c.feet.z.isClose(20.0, 3.0)
	loop 180:
		c.walk(w, Vec3(100, 0, 0), 1.0 / 60.0)
	print("{c.feet}")
	expect c.onFloor and c.feet.x > -50.0
	ground = physics.gridHeight(rampGrid(), 9, 100.0, c.feet.x + 400.0, c.feet.y + 400.0) ?? -1.0
	expect c.feet.z.isClose(ground, 1.5)

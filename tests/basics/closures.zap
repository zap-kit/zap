# A lambda's own locals, and block lambdas in pipeline steps.

type Ground:
	width i64
	height i64
	heights f32[]
	types u8[]
type Field:
	name str
	gat Ground
fn groundAt(g Ground, p Point3):
	cx = 1
	-g.heights[cx] * p.x
fn pick(g Ground, sx i64) (i64, i64)?:
	q = march(
		Point3(x = 0.0, y = 5.0, z = 0.0),
		Point3(x = f32(sx) * 0.1, y = -1.0, z = 0.3),
		(x f32, z f32):
		g.groundAt(Point3(x, y = 0.0, z))
	) ??
		return none
	cx = i64(q.x.floor())
	cy = i64((-q.z).floor())
	if cx >= 0 and cy >= -100 and cx < g.width: return (cx, cy)
	none
test "a lambda's local named like a local of the function that makes it keeps its own register":
	z = Field(
		name = "p",
		gat = Ground(width = 4, height = 4, heights = fill(64, 1.0), types = [0])
	)
	for i in 0..3:
		print(z.gat.pick(i))
	prints """
		none
		none
		none
		"""
type Point3:
	x f32
	y f32
	z f32
fn march(start Point3, way Point3, heightAt fn(f32, f32) f32, reach f32 = 10.0) Point3?:
	s = 0.0
	while s < reach:
		s += 1.0
		p = Point3(x = start.x + way.x * s, y = start.y + way.y * s, z = start.z + way.z * s)
		if p.y <= heightAt(p.x, p.z):
			pass
	none

test "a pipeline's block lambda runs in place: its statements, then its value":
	print([1, 2, 3].map(v:
		w = v * 10
		w + 1
	))
	print([1, 2, 3].filter(v:
		twice = v * 2
		twice > 4
	))
	print((0..4).count(i:
		odd = i % 2 == 1
		odd or i == 2
	) * 2)
	prints """
		[11, 21, 31]
		[3]
		6
		"""

test "pipelines over ranges, negative and empty, with blocks that own":
	print((-3..2).map(it * 2))
	print((5..5).map(it + 1))
	words = (0..4).count(i:
		w = "w{i}"
		w.len == 2 and i % 2 == 0
	)
	some = (-2..3).any(i:
		text = "{i}"
		text == "2"
	)
	every = (0..3).all(i:
		text = "{i}{i}"
		text.len == 1
	)
	print("{words} {some} {every}")
	print((0..3).map(i:
		label = "x"
		"{label}{i}"
	))
	prints """
		[-6, -4, -2, 0, 2]
		[]
		2 true false
		[\"x0\", \"x1\", \"x2\"]
		"""

test "a map of scalars writes each width in place":
	xs = [1, 3, 5]
	print(xs.map(it / 2.0))
	print((1..4).map(u8(255 if it == 3 else it)))
	print(xs.map(i32(it - 3) / 2))
	print(xs.map(it != 3))
	print((3..1).map(it * 2))
	prints """
		[0.5, 1.5, 2.5]
		[1, 2, 255]
		[-1, 0, 1]
		[true, false, true]
		[]
		"""

test "flatMap with a block lambda":
	print((1..4).flatMap(n:
		upTo = n
		(0..upTo).map(it)
	))
	prints "[0, 0, 1, 0, 1, 2]"

# The lab's balls stepped without a window: `zap run projects/lab/bench/balls.zap <balls> <steps>` prints
# the sum of their places, so a table and a list of them can be raced and compared.
import physics

count = i64.parse(args[0]) ?? 5000
steps = i64.parse(args[1]) ?? 2000
mut balls Table<physics.Ball> = []
mut rng = Random(7)
loop count:
	balls.push(
		physics.Ball(
			x = f32(rng.next(0..=1500)),
			y = f32(rng.next(0..=800)),
			vx = f32(rng.next(0.0..1.0) * 400.0 - 200.0),
			vy = f32(rng.next(0.0..1.0) * 400.0 - 200.0),
			size = f32(rng.next(8..=28)),
			tint = Vec4(1.0, 1.0, 1.0, 1.0)
		)
	)
loop steps:
	physics.bounce(balls, 0.016, 1600.0, 900.0)
print("{balls.sum(.x)} {balls.sum(.y)}")

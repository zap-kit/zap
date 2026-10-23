# The lab's bouncing balls: a table of them stepped under gravity, bouncing off the edges of the
# screen. projects/lab/bench/suite.zap races this against the same code over a list.

pub type Ball:
	x f32
	y f32
	vx f32
	vy f32
	size f32
	tint Vec4

# the balls moved by dt, in a width x height screen
pub fn bounce(mut balls Table<Ball>, dt f32, width f32, height f32):
	for i in 0..balls.len:
		b = mut ref balls[i]
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.vy += 300.0 * dt   # gravity
		if b.x < 0.0 or b.x + b.size > width:
			b.vx = -b.vx
			b.x = b.x.clamp(0.0, width - b.size)
		if b.y + b.size > height:
			b.vy = -b.vy * 0.98
			b.y = height - b.size
		if b.y < 0.0:
			b.vy = -b.vy
			b.y = 0.0

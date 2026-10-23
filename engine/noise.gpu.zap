# Noise for shaders, GPU code of this module (a project's stage calls engine.hash12 and
# engine.noise2): a hash of a point and value noise blended smoothly between whole points.

# a number 0 .. 1 that looks random, the same for the same point (Dave Hoskins' hash without sine)
pub fn hash12(at Vec2) f32:
	q = (at.xyx * 0.1031).fract()
	q += q @ (q.yzx + 33.33)
	((q.x + q.y) * q.z).fract()

# value noise 0 .. 1: the hashes of the four whole points around `at`, blended by smoothstep
pub fn noise2(at Vec2) f32:
	i = at.floor()
	f = at.fract()
	u = f * f * (3.0 - 2.0 * f)
	hash12(i)
		.lerp(hash12(i + Vec2(1.0, 0.0)), u.x)
		.lerp(hash12(i + Vec2(0.0, 1.0)).lerp(hash12(i + Vec2(1.0, 1.0)), u.x), u.y)

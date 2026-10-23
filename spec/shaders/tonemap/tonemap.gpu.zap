# GPU functions another module's shaders call as tonemap.name: a curve and the constant it uses.

whitePoint = 11.2

fn curve(x f32) f32:
	(x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)

pub fn aces(c Vec3) Vec3:
	scale = curve(whitePoint)
	Vec3(curve(c.x), curve(c.y), curve(c.z)) / scale

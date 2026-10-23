# What the sky, the world and the water share: the sun, the sky's light in every direction (the
# sky view skyview.gpu.zap draws), noise.

import engine

# how much it is day: 0 night .. 1 the sun well up
fn daylight(sunDirection Vec3) f32:
	(sunDirection.y * 3.0 + 0.3).clamp(0.0, 1.0)

# the light of the sky seen along d, read from the sky view
fn skyColor(d Vec3, skyView engine.Texture) Vec3:
	uv = Vec2(d.z.atan2(d.x) / tau + 0.5, d.y.clamp(-1.0, 1.0).asin() / pi + 0.5)
	skyView.sample(uv).rgb

fn fbm(start Vec2) f32:
	at = start
	sum f32 = 0.0
	a f32 = 0.5
	loop 5:
		sum += engine.noise2(at) * a
		at = at * 2.03 + Vec2(17.0, 9.0)
		a *= 0.5
	sum

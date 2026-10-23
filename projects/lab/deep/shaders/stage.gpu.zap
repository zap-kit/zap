# The passes of the stage: the sky behind a scene and the picture (the bloom is the engine's).

import engine

# The sky behind a scene: the direction each pixel looks along, from the camera's axes.
pub type Sky:
	forward Vec3
	right Vec3
	up Vec3
	spread Vec2   # tan of half the view, across and up
	sun Vec3
	night f32

pub fn skyPixel(uv Vec2, p Sky) Vec4:
	at = uv * 2.0 - 1.0
	d = (p.forward + p.right * at.x * p.spread.x + p.up * at.y * p.spread.y).normalized()
	skyColor(d, p.sun, p.night).withW(1.0)

# The picture: the scene and its bloom, the exposure, ACES tone mapping, darker corners, gamma.
pub type Picture:
	scene engine.Texture
	bloom engine.Texture
	exposure f32
	glow f32

pub fn picturePixel(uv Vec2, p Picture) Vec4:
	c = p.scene.sample(uv).rgb + p.bloom.sample(uv).rgb * p.glow
	c = engine.aces(c * p.exposure)
	q = uv - 0.5
	c *= 1.0 - q @ q * 0.45
	c.pow(1.0 / 2.2).withW(1.0)

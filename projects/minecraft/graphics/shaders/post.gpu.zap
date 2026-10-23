# The game's composite: the scene and its bloom (the engine's post passes make the bloom and
# smooth the edges after) as the picture on the screen.

import engine

# The scene and its bloom as a picture: exposure, a filmic curve, under water a blue sway, darker
# corners, the screen's gamma; the luma goes in alpha for the smoothing of edges after it.
pub type Final:
	scene engine.Texture
	bloom engine.Texture
	time f32
	underwater bool
	exposure f32

pub fn finalPixel(uv Vec2, p Final) Vec4:
	at = uv
	if p.underwater:
		at += Vec2((p.time * 2.0 + uv.y * 25.0).sin(), (p.time * 1.7 + uv.x * 21.0).cos()) * 0.003
	c = p.scene.sample(at).rgb + p.bloom.sample(at).rgb * 0.25
	if p.underwater:
		c = c * Vec3(0.25, 0.5, 0.75) + Vec3(0.005, 0.02, 0.04)
	c = engine.aces(c * p.exposure)
	# a touch more color, as film gives it
	grey = c @ Vec3(0.2126, 0.7152, 0.0722)
	c = Vec3(grey, grey, grey).lerp(c, 1.12).clamp(0.0, 1.0)
	q = uv - 0.5
	c *= 1.0 - q @ q * 0.45
	c = c.pow(1.0 / 2.2)
	c.withW(c @ Vec3(0.299, 0.587, 0.114))

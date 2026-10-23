# Skyrim's image space over the HDR picture of a cell, in the textures' gamma as the game lights:
# the vanilla ISHDR blend pass (its DXBC in Skyrim - Shaders.bsa, read through Community Shaders'
# ISHDR.hlsl), formula by formula. The picture scaled by the eye's adaptation (the ratio of the
# two adapted luminances), its luminance through Reinhard's curve toward the white, the bloom
# added where the curve is under where bloom is received; then the cinematic grading: saturation,
# the tint by its amount, brightness, and contrast about the adapted luminance.

import engine

pub type Grade:
	scene engine.Texture
	bloom engine.Texture
	adapted engine.Texture   # the luminances the eye has adapted to: red the scene's, green the target
	hdr Vec4   # 1 / white², where bloom is received, the bloom's scale, 0
	cinematic Vec4   # saturation, brightness, contrast, 0
	tint Vec4   # its color, how much

fn lumaOf(c Vec3) f32:
	c @ Vec3(0.2125, 0.7154, 0.0721)

pub fn gradePixel(uv Vec2, p Grade) Vec4:
	c = p.scene.sample(uv).rgb
	avg = p.adapted.sample(uv).rg
	luma = lumaOf(c).max(1.0e-5)
	exposed = luma * avg.y / avg.x.max(1.0e-5)
	curved = exposed * (exposed * p.hdr.x + 1.0) / (exposed + 1.0)
	c = c * (curved / luma) + p.bloom.sample(uv).rgb * (p.hdr.y - curved).clamp(0.0, 1.0)
	grey = lumaOf(c)
	c = Vec3(grey, grey, grey).lerp(c, p.cinematic.x)
	c = c.lerp(p.tint.rgb * grey, p.tint.w)
	middle = Vec3(avg.x, avg.x, avg.x)
	middle.lerp(c * p.cinematic.y, p.cinematic.z).clamp(0.0, 1.0).withW(1.0)

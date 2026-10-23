# A skinned figure from a glTF file (the engine's skinned vertex stage bends it), lit as the
# skater is: its base color texture times its color, then the haze of distance.

import engine

pub type FigureParams:
	sun Vec3
	exposure f32
	eye Vec3
	haze Haze
	picture engine.Texture

pub fn figurePixel(b engine.Skinned, p FigureParams) Vec4:
	albedo = b.color.rgb
	if b.uv.z > 0.5:
		albedo = p.picture.sample(b.uv.xy).rgb * b.color.rgb
	rgb = characterLight(albedo, b.normal.normalized(), p.sun) * p.exposure
	hazed(rgb, (b.position - p.eye).length(), p.haze).withW(1.0)

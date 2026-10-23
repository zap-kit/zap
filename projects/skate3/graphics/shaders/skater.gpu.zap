# The skater, simplified from the game's character shaders: the diffuse texture times its tint
# (skin and hair are grey in their textures), lit by the sun and the sky from the normal, then the
# haze of distance.

import engine

# a vertex of the skater as his prepared file holds it
pub type SkaterVertex:
	position Vec3
	normal Vec3
	uv Vec3
	spare f32

pub type SkaterParams:
	projection Mat4
	view Mat4
	model Mat4
	tint Vec4
	alphaTest bool   # texels with little alpha are dropped
	sun Vec3   # the sun's direction
	exposure f32
	eye Vec3
	haze Haze
	picture engine.Texture

pub type SkaterPoint:
	uv Vec2
	normal Vec3
	world Vec3

pub fn skaterVertex(v SkaterVertex, p SkaterParams) (Vec4, SkaterPoint):
	world = p.model @ v.position.withW(1.0)
	(
		p.projection @ p.view @ world,
		SkaterPoint(uv = v.uv.xy, normal = (p.model @ v.normal.withW(0.0)).xyz, world = world.xyz)
	)

pub fn skaterPixel(b SkaterPoint, p SkaterParams) Vec4:
	t = p.picture.sample(b.uv)
	if p.alphaTest and t.a < 0.5:
		discard()
	rgb = characterLight(t.rgb * p.tint.rgb, b.normal.normalized(), p.sun) * p.exposure
	hazed(rgb, (b.world - p.eye).length(), p.haze).withW(1.0)

# a figure's color lit by the sun and the sky from its normal
fn characterLight(albedo Vec3, n Vec3, sun Vec3) Vec3:
	lit = (n @ sun).max(0.0)
	sky = 0.55 + 0.25 * n.y
	albedo * (Vec3(0.62, 0.68, 0.78) * sky + Vec3(1.0, 0.94, 0.82) * lit * 0.75)

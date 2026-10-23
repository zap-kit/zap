# A model as the client draws it: the texture times the sun's light baked into each vertex. A
# cut-out texture drops its see-through texels; a blended one keeps its alpha. Far from the eye
# it fades into the sky's haze. Each vertex names its texture, read by index from the map's
# (bindless): the still models are a draw for each run of one sidedness.

import engine

# a vertex of a model as the prepared map holds it
pub type ModelVertex:
	position Vec3
	uvAlpha Vec3
	light Vec3
	texture i32   # the map's texture

pub type ModelParams:
	projection Mat4
	view Mat4
	cutout f32   # the alpha under which a texel is dropped
	haze Haze
	textures engine.Texture[]   # the map's, read by index

pub type ModelPoint:
	uv Vec2
	shade Vec4
	distance f32
	texture i32

pub fn modelVertex(v ModelVertex, p ModelParams) (Vec4, ModelPoint):
	seen = p.view @ v.position.withW(1.0)
	(p.projection @ seen, ModelPoint(
		uv = v.uvAlpha.xy,
		shade = v.light.withW(v.uvAlpha.z),
		distance = seen.xyz.length(),
		texture = v.texture))

pub fn modelPixel(b ModelPoint, p ModelParams) Vec4:
	t = p.textures[b.texture].sample(b.uv)
	if t.a < p.cutout:
		discard()
	hazed(t.rgb * b.shade.rgb, b.distance, p.haze).withW(t.a * b.shade.a)

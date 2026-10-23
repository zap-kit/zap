# The sky objects as Skyrim's sky shader draws them (Community Shaders' Sky.hlsl): each object a mesh
# placed about the eye, its vertices pushed to the far plane (xyww), its color the vertex color's
# blend of the three colors the sky gives it (the dome: horizon, lower, upper) or one tint, times
# its texture. The dome, the clouds, the stars and the sun are drawn one after the other with
# their own parameters.

import engine

# a vertex of a sky mesh (y up, about the eye): the vertex color's x, y, z weigh the dome's three
# colors and its w is the alpha
pub type SkyVertex:
	position Vec3
	uv Vec2
	color Vec4

pub type SkyParams:
	viewProjection Mat4   # the view without its translation, times the projection
	horizon Vec4   # the dome's three colors
	lower Vec4
	upper Vec4
	tint Vec4   # a textured object's color and alpha
	offset Vec2 = Vec2(0.0, 0.0)   # the texture coordinates' scroll
	# 0 the dome, 1 a textured object whose vertex alpha counts, 2 one whose does not, 3 one whose
	# color (with the image space's glow) is weighed by its alpha for an addition
	kind f32 = 0.0
	glow f32 = 0.0   # added to every color: the image space's sky scale
	texture engine.Texture = engine.Texture(id = -1, width = 1, height = 1)

pub type SkyPoint:
	uv Vec2
	color Vec4

pub fn skyVertex(v SkyVertex, p SkyParams) (Vec4, SkyPoint):
	c = p.viewProjection @ v.position.withW(1.0)
	(Vec4(c.x, c.y, c.w, c.w), SkyPoint(uv = v.uv + p.offset, color = v.color))

pub fn skyPixel(b SkyPoint, p SkyParams) Vec4:
	if p.kind < 0.5:
		gradient = p.horizon.rgb * b.color.x + p.lower.rgb * b.color.y + p.upper.rgb * b.color.z
		return (gradient + Vec3(p.glow, p.glow, p.glow)).withW(b.color.w)
	texel = p.texture.sample(b.uv)
	alpha = p.tint.w * texel.a
	if p.kind < 1.5:
		alpha *= b.color.w
	if p.kind > 2.5:
		return ((p.tint.rgb * texel.rgb + Vec3(p.glow, p.glow, p.glow)) * alpha).withW(1.0)
	(p.tint.rgb * texel.rgb + Vec3(p.glow, p.glow, p.glow)).withW(alpha)

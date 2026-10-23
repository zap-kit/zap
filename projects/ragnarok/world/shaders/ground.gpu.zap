# The ground as the client draws it: the tile's texture, times its color lit by the sun, darkened
# by the lightmap's baked shadow, plus the lightmap's baked light. A texel whose alpha is nearly
# none is a hole. Far from the eye it fades into the sky's haze. Each vertex names its tile's
# texture, read by index from the map's (bindless): the whole ground is one draw.

import engine

# a vertex of the ground as the prepared map holds it
pub type GroundVertex:
	position Vec3
	texturePlace Vec3   # u, v, the lightmap's u
	lightmapAndColor Vec3   # the lightmap's v, red, green
	blue f32
	texture i32   # the map's texture

# the haze far things fade into: its color, from `start` cells from the eye, hiding all at `end`
pub type Haze:
	color Vec4
	start f32
	end f32

pub type GroundParams:
	projection Mat4
	view Mat4
	haze Haze
	lightmap engine.Texture
	textures engine.Texture[]   # the map's, read by index

pub type GroundPoint:
	uv Vec2
	lightmap Vec2
	color Vec3
	distance f32
	texture i32

pub fn groundVertex(v GroundVertex, p GroundParams) (Vec4, GroundPoint):
	seen = p.view @ v.position.withW(1.0)
	t = v.texturePlace
	l = v.lightmapAndColor
	(p.projection @ seen, GroundPoint(
		uv = t.xy,
		lightmap = Vec2(t.z, l.x),
		color = Vec3(l.y, l.z, v.blue),
		distance = seen.xyz.length(),
		texture = v.texture))

pub fn groundPixel(b GroundPoint, p GroundParams) Vec4:
	t = p.textures[b.texture].sample(b.uv)
	if t.a < 0.1:
		discard()
	light = p.lightmap.sample(b.lightmap)
	lit = t.rgb * b.color * light.a + light.rgb.clamp(0.0, 1.0)
	hazed(lit, b.distance, p.haze).withW(1.0)

# a color faded into the haze as far as `distance` puts it
fn hazed(c Vec3, distance f32, h Haze) Vec3:
	c.lerp(h.color.rgb, distance.smoothstep(h.start, h.end))

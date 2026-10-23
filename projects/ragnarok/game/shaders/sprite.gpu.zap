# A figure of sprites standing in the world as the client draws one: a quad facing the camera
# whose feet are at `anchor`, a cell 35 texels wide, so it grows and shrinks with the zoom like
# anything in the world. Its depth is taken a little toward the camera, as the client does, so
# the ground never cuts the feet. Sampled sharp: each texel's inside stays one solid color and
# only its edges blend, over one screen pixel (the filtered texture read at the texel's centre,
# moved toward its edge only within the pixel that straddles it), so the sprite is crisp at any
# size and does not shimmer as it moves by fractions of a pixel; at one texel a pixel, aligned,
# it is the nearest texel. The texture's see-through texels are black and clear, so the filtered
# color is premultiplied and divided back. Its color is shaded by the ground's shadow where it
# stands. It is drawn twice: faint over everything first, so it shows through what hides it,
# then as it is.

import engine

pub type FigureVertex:
	anchor Vec3
	corner Vec3   # x right, y up from the feet, in cells
	uvShade Vec3   # u, v, the shade

pub type FigureParams:
	projection Mat4
	view Mat4
	lift f32   # how far toward the camera its depth is taken (cells)
	opacity f32
	picture engine.Texture

pub type FigurePoint:
	uv Vec2
	shade f32

pub fn figureVertex(v FigureVertex, p FigureParams) (Vec4, FigurePoint):
	seen = p.view @ v.anchor.withW(1.0) + Vec4(v.corner.x, v.corner.y, 0.0, 0.0)
	at = p.projection @ seen
	lifted = p.projection @ Vec4(seen.x, seen.y, seen.z + p.lift, 1.0)
	(
		Vec4(at.x, at.y, lifted.z / lifted.w * at.w, at.w),
		FigurePoint(uv = v.uvShade.xy, shade = v.uvShade.z)
	)

pub fn figurePixel(b FigurePoint, p FigureParams) Vec4:
	size = p.picture.size()
	texels = Vec2(f32(size.x), f32(size.y))
	t = b.uv * texels
	seam = (t + 0.5).floor()
	across = t.fwidth().max(0.0001)
	sharp = seam + ((t - seam) / across).clamp(-0.5, 0.5)
	c = p.picture.sample(sharp / texels)
	# the faint pass keeps only the solid texels (not the shadow, not the edges), so where the
	# figure is seen the pass over it covers it exactly
	if c.a < 0.02 or (p.opacity < 1.0 and c.a < 0.9):
		discard()
	(c.rgb / c.a * b.shade).withW(c.a * p.opacity)

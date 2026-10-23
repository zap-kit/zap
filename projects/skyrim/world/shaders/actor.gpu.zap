# An actor's part (bent by the engine's skinned vertex stage) lit as the cell is (cell.gpu.zap):
# its diffuse texture times its vertex color, cut out under the part's alpha; its normal bent by
# a normal map of the surface's bends along the ways its u and v run (found from how the place and
# the uv change across the pixels, since a skinned vertex carries no tangent), the map's alpha
# masking its highlight, as Skyrim's skin does; then the cell's fog. The skin's color is toned as
# Lighting.hlsl's vanilla path does: a face (FACEGEN) by its FaceGen tint texture and its detail
# map, a body (FACEGEN_RGB_TINT) by the actor's skin tone, the hair (HAIR) by its color where the
# vertices' green says. The part's material and textures are CellParams' part fields, set for
# each part drawn.

import engine

# the way the place p moves as u and as v grow, from their changes across the pixels
fn uvWays(p Vec3, uv Vec2) (Vec3, Vec3):
	dp1 = p.ddx()
	dp2 = p.ddy()
	duv1 = uv.ddx()
	duv2 = uv.ddy()
	det = duv1.x * duv2.y - duv2.x * duv1.y
	s f32 = 1.0 if det >= 0.0 else -1.0
	((dp1 * duv2.y - dp2 * duv1.y) * s, (dp2 * duv1.x - dp1 * duv2.x) * s)

fn partNormal(b engine.Skinned, map Vec4) Vec3:
	n = b.normal.normalized()
	u, v = uvWays(b.position, b.uv.xy)
	t = u - n * (n @ u)
	if (t @ t) < 1.0e-12:
		return n
	t = t.normalized()
	sign f32 = 1.0 if n.cross(t) @ v >= 0.0 else -1.0
	bentBy(n, t, n.cross(t) * sign, map)

# the texture's color c toned by `tint`: c² + 2 tint c (1 - c), a tint of a half leaving it
fn toned(c Vec3, tint Vec3) Vec3:
	c * c + tint * c * (Vec3(1.0, 1.0, 1.0) - c) * 2.0

# the part's color and the vertex color it is multiplied by, toned as its shader type says
fn skinColors(t Vec3, b engine.Skinned, p CellParams) (Vec3, Vec3):
	tone = p.partTone.x
	if tone > 3.5 and tone < 4.5:
		tint = p.textures[i32(p.partTone.y)].sample(b.uv.xy).rgb
		detail = p.textures[i32(p.partTone.z)].sample(b.uv.xy).rgb
		detail = (detail + Vec3(0.00392156886, 0.0, 0.00392156886)) * 3.984375
		return (toned(t, tint) * detail, b.color.rgb)
	if tone > 4.5 and tone < 5.5:
		return (
			toned(t, p.partToneColor.rgb) * Vec3(1.01171875, 0.99609375, 1.01171875),
			b.color.rgb
		)
	if tone > 5.5:
		return (t, Vec3(1.0, 1.0, 1.0).lerp(p.partToneColor.rgb, b.color.g))
	(t, b.color.rgb)

pub fn actorPixel(b engine.Skinned, p CellParams) Vec4:
	t = p.textures[p.partDiffuse].sample(b.uv.xy)
	if t.a * b.color.a < p.partCutout:
		discard()
	map = p.textures[p.partNormalMap].sample(b.uv.xy)
	n = partNormal(b, map)
	base, tint = skinColors(t.rgb, b, p)
	unshadowed = Vec4(1.0, 1.0, 1.0, 1.0)
	shaded(base, tint, n, b.position, b.uv.xy, map.a, p.part, unshadowed, p).withW(1.0)

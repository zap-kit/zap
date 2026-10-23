# The static world as Skate 3's environment shaders draw it, simplified: the color texture times
# the baked lightmap (its pages hold the sun and the shadows) and the exposure, a decal's texture
# laid over the color by its own coordinates, texels cut out or blended by their alpha, then the
# haze of distance; the brightest light rolls off rather than clipping. Meshes with no lightmap
# are lit by the sun from their normals. Each kind of batch is one draw of every batch of it:
# a vertex names its batch's material, whose textures are read by index from the district's
# table (bindless).

import engine

# a vertex of the world as the prepared district holds it
pub type WorldVertex:
	position Vec3
	uvAndLightU Vec3   # u, v, the lightmap's u
	lightVAndDecal Vec3   # the lightmap's v, the decal's u, v
	packedNormal f32   # see skate.packNormal

# a vertex as the GPU draws it: the prepared vertex and its batch's material
pub type PlacedVertex:
	position Vec3
	uvAndLightU Vec3
	lightVAndDecal Vec3
	packedNormal f32
	material i32

# a batch's material: its textures (indices of the table) and how they are read
pub type Material:
	color i32
	lightmap i32
	extra i32
	lightmapScale f32   # negative: no lightmap, lit by the sun
	extraAlpha i32   # 1: the alpha comes from the extra texture's

# how a batch is drawn (skate's kinds, in their order)
pub type Mode:
	Opaque
	CutOut
	Blended
	Decal

# what is shown, for checking the decoding: all of it, the lightmap alone, the color alone, the kind
pub type Show:
	Everything
	Lightmap
	Color
	Kind

# the haze of distance: its color, and how far it is half thick
pub type Haze:
	color Vec3
	halfway f32

pub type WorldParams:
	projection Mat4
	view Mat4
	mode Mode
	eye Vec3
	haze Haze
	sun Vec3
	show Show
	textures engine.Texture[]   # the district's, read by index
	materials Material[]

pub type WorldPoint:
	uv Vec2
	lightUv Vec2
	decalUv Vec2
	normal Vec3
	world Vec3
	material i32

pub fn worldVertex(v PlacedVertex, p WorldParams) (Vec4, WorldPoint):
	packed = v.packedNormal
	a = packed.abs() - 1.0
	qx = (a / 2048.0).floor()
	qy = a - qx * 2048.0
	nx = qx / 1000.0 - 1.0
	ny = qy / 1000.0 - 1.0
	nz = (1.0 - nx * nx - ny * ny).max(0.0).sqrt()
	normal = Vec3(nx, ny, -nz if packed < 0.0 else nz)
	l = v.lightVAndDecal
	(p.projection @ p.view @ v.position.withW(1.0), WorldPoint(
		uv = v.uvAndLightU.xy,
		lightUv = Vec2(v.uvAndLightU.z, l.x),
		decalUv = l.yz,
		normal = normal,
		world = v.position, material = v.material))

# light past 0.8 rolled off toward 1 instead of clipped (the sun on white concrete)
fn shoulder(x Vec3) Vec3:
	Vec3(roll(x.r), roll(x.g), roll(x.b))

fn roll(v f32) f32:
	v if v < 0.8 else 0.8 + 0.2 * (1.0 - ((0.8 - v) / 0.2).exp())

# a color in the haze `far` from the eye
fn hazed(rgb Vec3, far f32, h Haze) Vec3:
	thick = 1.0 - (-far / h.halfway * 0.693).exp()
	rgb.lerp(h.color, thick * 0.85)

pub fn worldPixel(b WorldPoint, p WorldParams) Vec4:
	m = p.materials[b.material]
	c = p.textures[m.color].sample(b.uv)
	if p.mode == Mode.Decal:
		d = p.textures[m.extra].sample(b.decalUv)
		c = c.rgb.lerp(d.rgb, d.a).withW(c.a)
	if m.extraAlpha != 0:
		c = c.rgb.withW(p.textures[m.extra].sample(b.uv).a)
	if p.mode == Mode.CutOut and c.a < 0.5:
		discard()
	light = p.textures[m.lightmap].sample(b.lightUv).rgb * m.lightmapScale
	if m.lightmapScale < 0.0:
		sun = (b.normal.normalized() @ p.sun).max(0.0)
		light = Vec3(0.45, 0.5, 0.6) + Vec3(1.0, 0.95, 0.85) * sun
	rgb = shoulder(c.rgb * light)
	if p.show == Show.Lightmap:
		rgb = light
	elif p.show == Show.Color:
		rgb = c.rgb
	elif p.show == Show.Kind:
		rgb = Vec3(
			1.0 if p.mode == Mode.CutOut else 0.0,
			1.0 if p.mode == Mode.Blended else 0.0,
			1.0 if p.mode == Mode.Decal else 0.5 if m.lightmapScale < 0.0 else 0.0
		)
	alpha = c.a if p.mode == Mode.Blended else 1.0
	hazed(rgb, (b.world - p.eye).length(), p.haze).withW(alpha)

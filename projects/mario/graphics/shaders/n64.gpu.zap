# The game's models as the console draws them.
#
# A vertex: its place, its color (or, lit, its normal), its texture coordinates and alpha, moved
# by its instance's matrix. A billboard turns to face the camera: its anchor is placed, and its
# vertices are laid out about it in view space. Lit, its color is the console's: the ambient light
# plus the directional one as the normal faces it, the light's direction given in view space.
#
# A pixel, as the console's color combiner makes it: (a - b) * c + d for color and for alpha,
# each input one of the texel, the primitive and environment colors, the vertex shade, one or
# zero. The texture repeats, mirrors or clamps per axis as its tile says; a cut-out layer drops
# what is mostly see-through.
#
# What does not move is drawn by the still stages: every batch of a layer laid one after the
# other in one model, each vertex naming its batch's material (a record of a storage buffer, its
# texture read by index from the stage's: bindless), so a layer is a draw for each run of one
# culling. Its vertices are placed and shaded by the same math as an instance's.

import engine

pub type N64Vertex:
	position Vec3
	colorOrNormal Vec3
	uvAlpha Vec3

# a billboard drawn at many places: this one (x, y, z; w and scale unused)
pub type N64Copy:
	place Vec4
	scale f32

# how a texture's coordinate goes on past its edge, as its tile says
pub type Wrap:
	Repeat
	Mirror
	Clamp

# how a vertex is placed: as the model's, turned to the camera about the material's anchor, or
# about the copy's place
pub type Billboard:
	None
	AboutAnchor
	AboutCopy

# the inputs of the color combiner (f3d.zap's codes, 0 zero)
fromTexel = 1
fromPrim = 2
fromShade = 3
fromEnv = 4
fromOne = 5
fromTexelAlpha = 6
fromPrimAlpha = 7
fromShadeAlpha = 8
fromEnvAlpha = 9

# the combiner's formula, (a - b) * c + d, of four inputs (their codes)
pub type Combiner:
	a i32
	b i32
	c i32
	d i32

pub type N64Params:
	projection Mat4
	view Mat4
	model Mat4
	lit bool
	alphaCut f32   # a pixel less opaque than this is dropped (0: none)
	wrapS i32   # Wrap's number
	wrapT i32
	color Combiner
	alpha Combiner
	prim Vec4
	env Vec4
	ambient Vec3
	diffuse Vec3
	lightDirection Vec3   # in view space
	texelSize Vec2   # 1 / the texture's size
	billboard Billboard
	anchor Vec3
	texel engine.Texture

pub type Shaded:
	shade Vec4
	uv Vec2

# a still batch's vertex, laid with the others of its layer: the vertex and its batch's material
pub type StillVertex:
	position Vec3
	colorOrNormal Vec3
	uvAlpha Vec3
	material i32

# a still batch's material: what N64Params holds of it, its texture an index of the stage's
# (Vec4s first, then the Vec2, then the numbers, as a storage buffer's record wants them)
pub type StillMaterial:
	prim Vec4
	env Vec4
	ambient Vec4   # xyz
	diffuse Vec4   # xyz
	lightDirection Vec4   # xyz, in view space
	texelSize Vec2
	texture i32
	lit i32
	alphaCut f32
	wrapS i32   # Wrap's number
	wrapT i32
	colorA i32
	colorB i32
	colorC i32
	colorD i32
	alphaA i32
	alphaB i32
	alphaC i32
	alphaD i32
	unused i32

pub type StillParams:
	projection Mat4
	view Mat4
	model Mat4   # the identity: still vertices are in the world's space
	textures engine.Texture[]
	materials StillMaterial[]

pub type StillShaded:
	shade Vec4
	uv Vec2
	material i32

pub fn n64Vertex(v N64Vertex, copy N64Copy, p N64Params) (Vec4, Shaded):
	seen = p.view @ p.model @ v.position.withW(1.0)
	if p.billboard == Billboard.AboutCopy:
		seen = p.view @ copy.place.xyz.withW(1.0) + v.position.withW(0.0)
	elif p.billboard == Billboard.AboutAnchor:
		seen = p.view @ p.model @ p.anchor.withW(1.0) + v.position.withW(0.0)
	shade = v.colorOrNormal
	if p.lit:
		n = (p.view @ p.model @ v.colorOrNormal.withW(0.0)).xyz.normalized()
		shade = (p.ambient + (n @ p.lightDirection).max(0.0) * p.diffuse).min(1.0)
	(p.projection @ seen, Shaded(shade = shade.withW(v.uvAlpha.z), uv = v.uvAlpha.xy))

pub fn stillVertex(v StillVertex, p StillParams) (Vec4, StillShaded):
	m = p.materials[v.material]
	seen = p.view @ p.model @ v.position.withW(1.0)
	shade = v.colorOrNormal
	if m.lit != 0:
		n = (p.view @ p.model @ v.colorOrNormal.withW(0.0)).xyz.normalized()
		shade = (m.ambient.xyz + (n @ m.lightDirection.xyz).max(0.0) * m.diffuse.xyz).min(1.0)
	(
		p.projection @ seen,
		StillShaded(shade = shade.withW(v.uvAlpha.z), uv = v.uvAlpha.xy, material = v.material)
	)

# a coordinate past the edge: repeated, mirrored or held at the edge's texel (Wrap's number)
fn wrapped(u f32, mode i32, halfTexel f32) f32:
	if mode == 2:
		return u.clamp(halfTexel, 1.0 - halfTexel)
	if mode == 1:
		m = u - (u / 2.0).floor() * 2.0
		return 2.0 - m if m > 1.0 else m
	u

# a combiner's input: the texel, the primitive or environment color, the shade, one, an alpha, zero
fn source(s i32, tex Vec4, shade Vec4, prim Vec4, env Vec4) Vec4:
	if s == fromTexel:
		return tex
	if s == fromPrim:
		return prim
	if s == fromShade:
		return shade
	if s == fromEnv:
		return env
	if s == fromOne:
		return Vec4(1.0, 1.0, 1.0, 1.0)
	if s == fromTexelAlpha:
		return Vec4(tex.a, tex.a, tex.a, tex.a)
	if s == fromPrimAlpha:
		return Vec4(prim.a, prim.a, prim.a, prim.a)
	if s == fromShadeAlpha:
		return Vec4(shade.a, shade.a, shade.a, shade.a)
	if s == fromEnvAlpha:
		return Vec4(env.a, env.a, env.a, env.a)
	Vec4(0.0, 0.0, 0.0, 0.0)

# the combiner's color and alpha, (a - b) * c + d each, before they are clamped
fn combined(tex Vec4, shade Vec4, prim Vec4, env Vec4, color Combiner, alpha Combiner) Vec4:
	rgb = (
		source(color.a, tex, shade, prim, env).rgb - source(color.b, tex, shade, prim, env).rgb
	) *
		source(color.c, tex, shade, prim, env).rgb +
		source(color.d, tex, shade, prim, env).rgb
	a = (source(alpha.a, tex, shade, prim, env).a - source(alpha.b, tex, shade, prim, env).a) *
		source(alpha.c, tex, shade, prim, env).a +
		source(alpha.d, tex, shade, prim, env).a
	rgb.withW(a)

pub fn n64Pixel(b Shaded, p N64Params) Vec4:
	uv = Vec2(
		wrapped(b.uv.x, p.wrapS, p.texelSize.x * 0.5),
		wrapped(b.uv.y, p.wrapT, p.texelSize.y * 0.5)
	)
	tex = p.texel.sample(uv)
	c = combined(tex, b.shade, p.prim, p.env, p.color, p.alpha)
	if p.alphaCut > 0.0 and c.a < p.alphaCut:
		discard()
	c.rgb.clamp(0.0, 1.0).withW(c.a.clamp(0.0, 1.0))

pub fn stillPixel(b StillShaded, p StillParams) Vec4:
	m = p.materials[b.material]
	uv = Vec2(
		wrapped(b.uv.x, m.wrapS, m.texelSize.x * 0.5),
		wrapped(b.uv.y, m.wrapT, m.texelSize.y * 0.5)
	)
	tex = p.textures[m.texture].sample(uv)
	c = combined(tex, b.shade, m.prim, m.env, Combiner(a = m.colorA, b = m.colorB, c = m.colorC, d = m.colorD), Combiner(
		a = m.alphaA,
		b = m.alphaB,
		c = m.alphaC,
		d = m.alphaD))
	if m.alphaCut > 0.0 and c.a < m.alphaCut:
		discard()
	c.rgb.clamp(0.0, 1.0).withW(c.a.clamp(0.0, 1.0))

# The world's vertex: where it lands on the screen and in the light's two shadow maps.
#
# The world's pixel, lit as light behaves: the photographed material's color, its relief (a
# normal map), how rough it is and how shut in its texels are; the sun or the moon through the
# shadow maps, diffuse and as a highlight as broad as the surface is rough; the sky around,
# from above and bounced from the ground below, dimmed in shut-in corners; leaves and grass lit
# through from behind; water mirroring the sky. Far away it melts into the haze, brighter
# toward the sun. A block's texture is turned or mirrored by where it is, so a field shows no
# grid.

import engine

pub type World:
	viewProjection Mat4
	lightViewProjection Mat4
	lightViewProjectionB Mat4
	time f32   # seconds, for what moves
	chunkOrigin Vec3   # the chunk's corner in the world
	sunDirection Vec3   # toward the sun, below the horizon at night
	eye Vec3
	lightDirection Vec3   # toward the sun, or the moon at night
	lightColor Vec3
	fogDensity f32
	alphaCut f32
	shadowTexel f32
	shadowBlend f32   # 0 the first map .. 1 the second
	underwater bool
	tiles engine.TextureArray
	shadowMap engine.ShadowMap
	shadowMapB engine.ShadowMap
	surfaces engine.TextureArray   # normal x and y, roughness, occlusion
	skyView engine.Texture

pub type Seen:
	uvLayer Vec3
	light f32
	world Vec3
	shadow Vec4
	shadowB Vec4
	face i32
	material i32

pub fn worldVertex(v CornerWord, p World) (Vec4, Seen):
	c = unpack(v.word, p.chunkOrigin, p.time)
	at = c.position
	if c.material == materialLine:
		at += (p.eye - at).normalized() * 0.02   # an outline sits before the faces it runs along
	# read a little off the surface, along its normal: no face shadows itself
	off = (at + normals[c.face] * 0.06).withW(1.0)
	(p.viewProjection @ at.withW(1.0), Seen(
		uvLayer = c.uvLayer,
		light = c.light,
		world = at,
		shadow = p.lightViewProjection @ off,
		shadowB = p.lightViewProjectionB @ off, face = c.face, material = c.material))

faceNormals Vec3[7] = [
	Vec3(1, 0, 0),
	Vec3(-1, 0, 0),
	Vec3(0, 1, 0),
	Vec3(0, -1, 0),
	Vec3(0, 0, 1),
	Vec3(0, 0, -1),
	Vec3(0, 1, 0)
]

# along each face: where the texture's u grows, and its up (v falling)
faceAcross Vec3[7] = [
	Vec3(0, 0, -1),
	Vec3(0, 0, 1),
	Vec3(1, 0, 0),
	Vec3(1, 0, 0),
	Vec3(1, 0, 0),
	Vec3(-1, 0, 0),
	Vec3(1, 0, 0)
]
faceUp Vec3[7] = [
	Vec3(0, 1, 0),
	Vec3(0, 1, 0),
	Vec3(0, 0, -1),
	Vec3(0, 0, 1),
	Vec3(0, 1, 0),
	Vec3(0, 1, 0),
	Vec3(0, 1, 0)
]

# how much of the light reaches the point: a shadow map read at 9 points around it, each read
# itself smoothed between texels
fn lightReaching(map engine.ShadowMap, s Vec4, texel f32) f32:
	at = s.xyz / s.w * 0.5 + 0.5
	if at.z > 1.0 or at.x < 0.0 or at.x > 1.0 or at.y < 0.0 or at.y > 1.0:
		return 1.0
	sum f32 = 0.0
	for y in -1..1 + 1:
		for x in -1..1 + 1:
			sum += map.compare(at.xy + Vec2(f32(x), f32(y)) * texel, at.z)
	sum / 9.0

# The turn of a block face's texture, by the block: a top or a bottom a quarter turn 0 to 3 times
# and mirrored or not, a side mirrored or not (its top stays up: grass grows on it).
fn blockTurn(face i32, world Vec3) Mat2:
	block = (world - faceNormals[face] * 0.01).floor()
	h = engine.hash12(block.xz * 1.37 + block.y * 7.91)
	mirror = -1.0 if h < 0.5 else 1.0
	if face != 2 and face != 3:
		return Mat2(mirror, 0.0, 0.0, 1.0)
	k = ((h * 7.0).fract() * 4.0).floor()
	c = 1.0 if k == 0.0 else (-1.0 if k == 2.0 else 0.0)
	s = 1.0 if k == 1.0 else (-1.0 if k == 3.0 else 0.0)
	Mat2(c, s, -s, c) @ Mat2(mirror, 0.0, 0.0, 1.0)

# the GGX highlight of a light from l seen from v, the surface's normal n, its roughness
fn highlight(n Vec3, v Vec3, l Vec3, rough f32) f32:
	h = (l + v).normalized()
	a = (rough * rough).max(0.02)
	a2 = a * a
	nh = (n @ h).max(0.0)
	d = a2 / (3.14159 * (nh * nh * (a2 - 1.0) + 1.0).pow(2.0))
	k = a * 0.5
	nl = (n @ l).max(0.0)
	nv = (n @ v).max(0.001)
	g = nl / (nl * (1.0 - k) + k) * nv / (nv * (1.0 - k) + k)
	f = 0.04 + 0.96 * (1.0 - (h @ v).max(0.0)).pow(5.0)
	d * g * f / (4.0 * nv)

pub fn worldPixel(b Seen, p World) Vec4:
	if b.material == 3:
		return Vec4(0.01, 0.01, 0.01, 1.0)   # an outline
	water = b.material == 2
	foliage = b.material == 1
	plant = b.face == 6
	turn = Mat2(1.0) if (water or plant) else blockTurn(b.face, b.world)
	uv = turn @ (b.uvLayer.xy - 0.5) + 0.5
	t = p.tiles.sample(uv, b.uvLayer.z)
	if t.a < p.alphaCut:
		discard()
	surface = p.surfaces.sample(uv, b.uvLayer.z)
	albedo = t.rgb.pow(2.2)
	flatNormal = faceNormals[b.face]
	toEye = p.eye - b.world
	dist = toEye.length()
	v = toEye / dist
	# the relief: the normal map's tilt, turned back from the texture to the face
	tilt = surface.xy * 2.0 - 1.0
	faceTilt = turn.transpose() @ Vec2(tilt.x, -tilt.y)
	upright = (1.0 - tilt @ tilt).max(0.0).sqrt()
	n = flatNormal if plant
		else (
			faceAcross[b.face] * faceTilt.x - faceUp[b.face] * faceTilt.y + flatNormal * upright
		).normalized()
	rough = 0.05 if water else surface.b
	occlusion = surface.a * b.light
	time = p.time
	if water and n.y > 0.5:
		# the water's surface: a normal that ripples
		q = b.world.xz
		dx = (time * 1.6 + q.x * 0.8).cos() * 0.04 +
			(time * 2.3 + q.x * 2.1 + q.y * 1.3).cos() * 0.03
		dz = -(time * 1.2 + q.y * 0.9).sin() * 0.045 +
			(time * 2.7 + q.y * 2.4 - q.x * 0.7).cos() * 0.03
		n = Vec3(-dx, 1.0, -dz).normalized()
	if (water or foliage) and flatNormal @ v < 0.0:
		n = -n   # seen from behind
		flatNormal = -flatNormal
	l = p.lightDirection
	# the light's two shadow maps, a moment apart, blended: the shadows glide as the sun moves
	reaching = lightReaching(p.shadowMap, b.shadow, p.shadowTexel).lerp(
		lightReaching(p.shadowMapB, b.shadowB, p.shadowTexel),
		p.shadowBlend
	)
	facesLight = 1.0 if foliage else (flatNormal @ l).step(0.0)
	nl = (n @ l).max(0.0)
	if foliage:
		nl = nl * 0.6 + 0.25
	# thin leaves and blades take light on both sides
	sun = p.lightColor * reaching * facesLight
	# the sky above and the ground's bounce below
	skyAbove = skyColor(Vec3(0.0, 1.0, 0.0), p.skyView)
	bounce = Vec3(0.30, 0.27, 0.22) * (p.lightColor * l.y.max(0.0) * 0.12 + skyAbove * 0.3)
	ambient = bounce.lerp(
		skyAbove * 2.0 + skyColor(Vec3(n.x, 0.15, n.z).normalized(), p.skyView) * 0.8,
		n.y * 0.5 + 0.5
	) *
		occlusion
	if foliage:
		ambient = ambient.max(skyAbove * 0.9)
	# light comes through a canopy from every side
	c = albedo * (ambient + sun * nl)
	c += sun * highlight(n, v, l, rough) * (0.4 if foliage else 1.0)
	if foliage:
		# light through the leaf, from a sun behind it
		c += albedo * sun * ((-v) @ l).max(0.0).pow(4.0) * 0.8
	# the sky mirrored by smooth surfaces, more at a glancing look; a rough one scatters it, so
	# even glancing it mirrors little
	r = (-v).reflect(n)
	glancing = (1.0 - (n @ v).max(0.0)).pow(5.0)
	fresnel = 0.04 + ((1.0 - rough).max(0.04) - 0.04) * glancing
	mirrored = skyColor(r, p.skyView) * r.y.smoothstep(-0.2, 0.15)
	c += mirrored * fresnel * (1.0 - rough) * occlusion
	alpha f32 = 1.0
	if water:
		fresnel = 0.02 + 0.98 * glancing
		c = (albedo * (ambient + sun * nl * 0.3)).lerp(skyColor(r, p.skyView), fresnel) +
			sun * highlight(n, v, l, 0.06) * 2.0
		alpha = 0.82.lerp(1.0, fresnel)
	if p.underwater:
		# under water the murk closes in fast, lit by the day above
		c = c.lerp(
			Vec3(0.01, 0.05, 0.09) * (0.15 + daylight(p.sunDirection)),
			1.0 - (-dist * 0.09).exp()
		)
	else:
		# the haze: thicker low down, the sky's color, brighter toward the sun
		haze = 1.0 -
			(-(dist * p.fogDensity).pow(1.6) * (-(b.world.y - 20.0).max(0.0) * 0.015).exp()).exp()
		hazeColor = skyColor(Vec3(-v.x, (-v.y).max(0.02), -v.z).normalized(), p.skyView) +
			p.lightColor * ((-v) @ l).max(0.0).pow(8.0) * 0.25
		c = c.lerp(hazeColor, haze)
	c.withW(alpha)

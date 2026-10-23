# Water as Skyrim's water shader draws it (Community Shaders' Water.hlsl read against the vanilla
# permutations: the flow map and the normal maps, the refraction of what lies under the surface by
# the water's depth, the reflection, the sun's glint and the fog), one program for every body of
# water of the scene. The pass reads what the scene drew into a copy of its color (the refraction),
# of its depths (the water's depth) and a reflected view of the sky and the far land.
#
# The shader works in the game's axes (z up, relative to the eye) as the original does, the
# engine's y-up world turned at the entry; a vertex carries its material's index, a flow map's
# texture index and whether it is a distant (LOD) plane.

import engine

# One water type's constants as the pixel stage reads them (BSWaterShader::SetupMaterial 0x14154d700):
# see esm/water.zap for the record they come from.
pub type WaterMaterial:
	shallow Vec4   # the shallow water's color (times the weather's water multiplier)
	deep Vec4   # the deep color; w the sun's share through the water (the sun specular magnitude)
	fresnel Vec4   # the fresnel amount
	amounts Vec4   # the sun specular power, the reflection amount, the opacity, the refraction magnitude
	amplitude Vec4   # the three normal layers' amplitudes
	params Vec4   # the noise falloff, the reflection magnitude
	fog Vec4   # the above water fog's far distance and range, its amount
	depth Vec4   # how the depth fades the reflection, the refraction, the normals, the highlight
	scale Vec4   # the three layers' sizes in units
	scroll Vec4   # the first and second layers' offsets this frame
	scrollThird Vec4   # the third's
	maps Vec4   # the three normal maps' and the flow normals' texture indices

pub type WaterVertex:
	position Vec3   # y up
	uv Vec2   # across the plane, 0 to 1 a cell
	# the material's index, the flow map's texture index (-1 for none), 1 for a distant plane
	data Vec4

pub type WaterPoint:
	world Vec3
	uv Vec2
	data Vec4

pub type WaterParams:
	# the cell's view, sun and fog (its CellParams', which a parameter struct cannot nest) and textures
	projection Mat4
	view Mat4
	eye Vec4
	sunToward Vec4
	sunColor Vec4
	fogNearColor Vec4
	fogFarColor Vec4
	fog Vec4
	textures engine.Texture[]
	materials WaterMaterial[]
	refraction engine.Texture   # the scene's color before the water
	depth engine.Texture   # the scene's view depth in red (60000 where nothing is drawn)
	reflection engine.Texture   # the sky and far land seen from the eye mirrored in the water
	mirror Mat4   # that view's projection times its view
	toWorld Mat4   # the main view's inverse
	unproject Vec4   # the main projection's 1 / m[0] and 1 / m[5]
	seconds f32   # the flow's clock
	fade f32 = 0.8333333   # the fog's fade (the frame buffer range's inverse)
	debug f32 = 0.0   # diagnostics: 1 the normal, 2 the reflection, 3 the refraction, 4 the depths

pub type WaterCopy:
	scene engine.Texture

pub type WaterDepth:
	depth engine.Texture
	unproject Vec4   # the projection's 1 / m[0], 1 / m[5], m[10] and m[14]

# the picture as it was, for the water to refract
pub fn waterCopyPixel(uv Vec2, p WaterCopy) Vec4:
	p.scene.sampleLevel(uv, 0.0)

# the view depth of the surface the depth buffer holds at uv (60000 where nothing is drawn)
pub fn waterDepthPixel(uv Vec2, p WaterDepth) Vec4:
	raw = p.depth.sampleLevel(uv, 0.0).r
	if raw >= 1.0:
		return Vec4(60000.0, 0.0, 0.0, 1.0)
	d = raw * 2.0 - 1.0
	linear = p.unproject.w / (d + p.unproject.z)
	Vec4(linear.min(59990.0), 0.0, 0.0, 1.0)

pub fn waterVertex(v WaterVertex, p WaterParams) (Vec4, WaterPoint):
	c = p.projection @ p.view @ v.position.withW(1.0)
	push = (0.0001 * (c.w - 70000.0).max(0.0)).min(1.0) * 0.5
	(Vec4(c.x, c.y, c.z + push, c.w), WaterPoint(world = v.position, uv = v.uv, data = v.data))

# where the main view puts a world point on its target (uv; its first row is the clip space's -1)
fn screenOf(world Vec3, p WaterParams) Vec2:
	c = p.projection @ p.view @ world.withW(1.0)
	Vec2(c.x / c.w * 0.5 + 0.5, c.y / c.w * 0.5 + 0.5)

# the scene point seen at uv: its place in the world (y up) and its view depth
fn sceneAt(uv Vec2, p WaterParams) (Vec3, f32):
	d = p.depth.sampleLevel(uv, 0.0).r
	view = Vec3(
		(uv.x * 2.0 - 1.0) * d * p.unproject.x,
		(uv.y * 2.0 - 1.0) * d * p.unproject.y,
		-d
	)
	((p.toWorld @ view.withW(1.0)).xyz, d)

# What the water above a scene point gives, as the shader's depth block does: the length of the
# view ray under the surface over the fog's far distance (x and y) and the vertical depth over it (z
# and w), each 0 to 1; w of the result's fifth value is the share of the ray under the surface,
# negative when the point lies above the surface.
fn underWater(scene Vec3, eye Vec3, height f32, reach f32) Vec4:
	above = eye.y - scene.y
	if above <= 0.0001:
		return Vec4(0.0, 0.0, 0.0, 0.0)
	share = 1.0 - (eye.y - height) / above
	along = (eye - scene).length()
	path = (share * along / reach).clamp(0.0, 1.0)
	down = (share * above / reach).clamp(0.0, 1.0)
	Vec4(path, path, down, down)

# whether a scene point lies under the surface
fn isUnder(scene Vec3, eye Vec3, height f32) bool:
	above = eye.y - scene.y
	above > 0.0001 and 1.0 - (eye.y - height) / above >= 0.0

# a normal map's texel as a vector: the shader's xyz * 2 - 1
fn mapNormal(slot f32, uv Vec2, p WaterParams) Vec3:
	t = p.textures[engine.tileSlot(slot)].sample(uv)
	Vec3(t.x * 2.0 - 1.0, t.y * 2.0 - 1.0, t.z * 2.0 - 1.0)

# One of the four flow normals GetFlowmapNormal takes: the flow map's texel turns the cell's
# coordinates (its red and green the sine and cosine, mapped to -1..1) and carries them along by its
# speed (alpha) times the clock; the map's xy at the result and the flow's strength (blue).
fn flowNormal(
	m WaterMaterial,
	flowSlot f32,
	across Vec2,
	shift Vec2,
	multiplier f32,
	offset f32,
	level f32,
	p WaterParams
) Vec3:
	# the flow map is read texel by texel (64 across a cell), the half texel shift picking the
	# neighbour past the middle
	at = ((across + shift) * 64.0).floor().min(Vec2(63.0, 63.0)).max(Vec2(0.0, 0.0))
	texel = p.textures[engine.tileSlot(flowSlot)].sampleLevel((at + Vec2(0.5, 0.5)) / 64.0, 0.0)
	turn = Vec2(texel.x * 2.0 - 1.0, texel.y * 2.0 - 1.0)
	strength = (1.01 - texel.z).sqrt()
	spread = across * 64.0 * strength
	rotated = Vec2(
		turn.x * spread.x - turn.y * spread.y,
		turn.y * spread.x + turn.x * spread.y
	)
	uv = Vec2(rotated.x - multiplier * p.seconds * texel.w + offset, rotated.y + offset)
	# the level the unrotated coordinates choose, as the flow's own jump from texel to texel would
	# pick the smallest
	n = p.textures[engine.tileSlot(m.maps.w)].sampleLevel(uv, (level + strength.log2()).max(0.0))
	Vec3(n.x, n.y, texel.z)

# GetWaterNormal: the normal in the game's axes. A flow map's water blends the flow normals into
# the first layer's by the distance; the rest blends its three layers by their amplitudes and fades
# them to the flat surface by the depth.
fn waterNormal(
	m WaterMaterial,
	b WaterPoint,
	game Vec3,
	distanceFactor f32,
	normalsDepth f32,
	p WaterParams
) Vec3:
	uv1 = m.scroll.xy + game.xy / m.scale.x
	n1 = mapNormal(m.maps.x, uv1, p)
	base = Vec3(n1.x, n1.y, n1.z - 1.0)
	if b.data.z > 0.5:
		return (Vec3(0.0, 0.0, 1.0) + base * m.amplitude.x).normalized()
	flowSlot = b.data.y
	if flowSlot >= 0.0:
		across = b.uv
		shift = 1.0 / 128.0
		fraction = (across * 64.0).fract() * 2.0 - Vec2(1.0, 1.0)
		weight = Vec2(1.0 - fraction.x.abs(), 1.0 - fraction.y.abs())
		slope = (across * 64.0).ddx()
		cross = (across * 64.0).ddy()
		footprint = (slope @ slope).max(cross @ cross)
		level = (0.5 * (footprint * 2048.0 * 2048.0).log2()).max(0.0)
		f0 = flowNormal(m, flowSlot, across, Vec2(shift, shift), 9.92, 0.0, level, p)
		f1 = flowNormal(m, flowSlot, across, Vec2(0.0, shift), 10.64, 0.27, level, p)
		f2 = flowNormal(m, flowSlot, across, Vec2(0.0, 0.0), 8.0, 0.0, level, p)
		f3 = flowNormal(m, flowSlot, across, Vec2(shift, 0.0), 8.48, 0.62, level, p)
		weighted = (f2.xy * weight.x + f3.xy * (1.0 - weight.x)) * weight.y +
			(f1.xy * weight.x + f0.xy * (1.0 - weight.x)) * (1.0 - weight.y)
		scaleX = (weight.x * weight.x + (1.0 - weight.x) * (1.0 - weight.x)).sqrt()
		scaleY = (weight.y * weight.y + (1.0 - weight.y) * (1.0 - weight.y)).sqrt()
		xy = (weighted - Vec2(0.5, 0.5)) / (scaleX * scaleY) * normalsDepth.max(0.4)
		flow = Vec3(xy.x, xy.y, (1.0 - xy.x * xy.x - xy.y * xy.y).max(0.0).sqrt())
		return Vec3(base.x, base.y, base.z + 1.0).lerp(flow, distanceFactor).normalized()
	uv2 = m.scroll.zw + game.xy / m.scale.y
	uv3 = m.scrollThird.xy + game.xy / m.scale.z
	n2 = mapNormal(m.maps.y, uv2, p)
	n3 = mapNormal(m.maps.z, uv3, p)
	blended = (Vec3(0.0, 0.0, 1.0) + base * m.amplitude.x + n2 * m.amplitude.y + n3 * m.amplitude.z)
		.normalized()
	Vec3(0.0, 0.0, 1.0).lerp(blended, normalsDepth).normalized()

pub fn waterPixel(b WaterPoint, p WaterParams) Vec4:
	m = p.materials[i32(b.data.x + 0.5)]
	lod = b.data.z > 0.5
	eye = p.eye.xyz
	game = inGame(b.world)
	relative = inGame(b.world - eye)
	distance = relative.length()
	view = relative / distance
	height = b.world.y
	# the normals' detail fades out from the noise falloff to 8192 units
	distanceFactor = ((distance - 8192.0) / (m.params.x - 8192.0)).clamp(0.0, 1.0)
	reach = m.fog.x.max(1.0)
	range = m.fog.y.max(1.0)
	screen = screenOf(b.world, p)
	# how deep the water is under the surface here: x and y along the view, z and w straight down
	opaque = m.amounts.z.lerp(1.0, 1.0 - distanceFactor).clamp(0.0, 1.0)
	distanceMul = Vec4(opaque, opaque, opaque, opaque)
	if not lod:
		scene, d = sceneAt(screen, p)
		distanceMul = Vec4(1.0, 1.0, 1.0, 1.0) if d >= 59999.0
			else underWater(scene, eye, height, reach)
	depthControl = Vec4(1.0, 0.0, 0.0, 1.0)
	if not lod:
		depthControl = Vec4(
			m.depth.x * (distanceMul.x - 1.0) + 1.0,
			m.depth.y * (distanceMul.y - 1.0) + 1.0,
			m.depth.z * (distanceMul.z - 1.0) + 1.0,
			m.depth.w * (distanceMul.w - 1.0) + 1.0
		)
	normal = waterNormal(m, b, game, distanceFactor, depthControl.z, p)
	cosine = ((view * -1.0) @ normal).clamp(0.0, 1.0)
	fresnel = (1.0 - m.fresnel.x) * (1.0 - cosine).pow(5.0) + m.fresnel.x
	# the reflection: where the ray the perturbed normal reflects meets the mirrored view
	bent = normal * m.params.y + Vec3(0.0, 0.0, 1.0 - m.params.y)
	mirrored = view - bent * (2.0 * (view @ bent))
	mirrorAt = p.mirror @ (b.world + inEngine(mirrored) * 2000.0).withW(1.0)
	mirrorUv = Vec2(mirrorAt.x / mirrorAt.w * 0.5 + 0.5, mirrorAt.y / mirrorAt.w * 0.5 + 0.5)
	specular = p.reflection.sampleLevel(mirrorUv, 0.0).rgb
	# what lies under the surface: the scene through it (refracted by the normal), the water's own
	# color by the depth, how much of the water shows over the scene
	toSun = inGame(p.sunToward.xyz)
	refracted = m.shallow.rgb.lerp(m.deep.rgb, fresnel) * (toSun @ normal).clamp(0.0, 1.0)
	waterColor = refracted
	mul = 1.0
	if not lod:
		offset = normal.xy * (m.amounts.w * depthControl.y)
		refractUv = screenOf(b.world + Vec3(offset.x, 0.0, -offset.y), p)
		scene2, d2 = sceneAt(refractUv, p)
		usedUv = screen
		if d2 < 59999.0 and isUnder(scene2, eye, height):
			usedUv = refractUv
			distanceMul = underWater(scene2, eye, height, reach)
		elif d2 >= 59999.0:
			usedUv = refractUv
			distanceMul = Vec4(1.0, 1.0, 1.0, 1.0)
		refracted = p.refraction.sampleLevel(usedUv, 0.0).rgb
		waterColor = m.shallow.rgb.lerp(m.deep.rgb, distanceMul.y)
		mul = 1.0 - ((reach - distanceMul.x * reach) / range).clamp(0.0, 1.0).pow(m.fog.z)
		depthControl = Vec4(
			m.depth.x * (distanceMul.x - 1.0) + 1.0,
			m.depth.y * (distanceMul.y - 1.0) + 1.0,
			m.depth.z * (distanceMul.z - 1.0) + 1.0,
			m.depth.w * (distanceMul.w - 1.0) + 1.0
		)
	# the sun's glint
	sun = toSun
	reflectedSun = view - normal * (2.0 * (view @ normal))
	glint = (reflectedSun @ sun).clamp(0.0, 1.0).pow(m.amounts.x)
	share = 1.0 - (0.0 - m.deep.w).exp()
	sunColor = p.sunColor.rgb * (glint * share)
	fraction = 1.0.lerp(fresnel, distanceFactor)
	lit = waterColor.lerp(specular, fraction) + sunColor * depthControl.w
	fogAmount = (((distance - p.fog.x) / (p.fog.y - p.fog.x).max(1.0)).clamp(0.0, 1.0))
		.pow(p.fog.z.max(0.01))
		.min(p.fog.w)
	fogColor = p.fogNearColor.rgb.lerp(p.fogFarColor.rgb, fogAmount) * p.fade
	final = refracted.lerp(lit.lerp(fogColor, fogAmount), mul)
	if p.debug > 0.5:
		shown = Vec3(normal.x * 0.5 + 0.5, normal.z * 0.5 + 0.5, normal.y * 0.5 + 0.5)
		if p.debug > 1.5:
			shown = specular
		if p.debug > 2.5:
			shown = refracted
		if p.debug > 3.5:
			shown = Vec3(distanceMul.x, distanceMul.z, mul)
		return Vec4(shown.x * 0.4, shown.y * 0.4, shown.z * 0.4, 1.0)
	Vec4(final.x, final.y, final.z, 1.0)

# Skyrim's vanilla lighting of a surface (BSLightingShader), formula by formula from its DXBC in
# Skyrim - Shaders.bsa, read through Community Shaders' Lighting.hlsl and LightingEval.hlsli: in
# the textures' gamma, the diffuse light is the cell's ambient, its directional light
# and the placed lights (each times 1 - (distance / radius)², and its shadow when it casts
# them), plus the soft, rim and back lighting the material turns on, plus its own light; the
# texture times it times the vertex color, clamped at fLightingOutputColourClampPostLit through
# the fog; the highlight ((n.h)^glossiness times each light, not weighed by n.l) times the
# normal map's alpha and the material's specular color added, clamped at ...PostSpec through the
# fog.

import engine

# SkyrimPrefs.ini's fLightingOutputColourClampPostLit and fLightingOutputColourClampPostSpec
postLit f32 = 1.0
postSpec f32 = 1.0

# a lit material as the shader reads it (nif.Shading, and the part's highlight)
pub type Look:
	specular Vec4   # the highlight's color times its strength; its glossiness
	emit Vec4   # its own light; its glow map's texture + 1 (0 none)
	lighting Vec4   # the soft light's rolloff, the rim's power, what it turns on (1 soft, 2 rim, 4
	# back), 1 when its own light is its reference's emittance source's
	maps Vec4   # the soft and rim light's map + 1, the back light's map + 1 (0: white)
	environment Vec4   # the reflected cube map's texture + 1 (0 none), its scale, its mask's texture + 1

# The ambient (the executable's Sky::UpdateColors / BSLightingShader setup and Lighting.hlsl's
# mul(DirectionalAmbient, float4(n, 1))): the mean of the cell's six colors plus, along each axis,
# the normal's component times half the difference of its two colors (the second less the first:
# the cube's names are the light's travel direction), full strength, unclamped as the pixel stage takes it.
fn ambientCube(n Vec3, ambient Vec4[6]) Vec3:
	mean = (
		ambient[0].rgb + ambient[1].rgb + ambient[2].rgb + ambient[3].rgb + ambient[4].rgb +
			ambient[5].rgb
	) /
		6.0
	mean + (ambient[1].rgb - ambient[0].rgb) * (0.5 * n.x) +
		(ambient[3].rgb - ambient[2].rgb) * (0.5 * n.y) +
		(ambient[5].rgb - ambient[4].rgb) * (0.5 * n.z)

fn ambientOf(n Vec3, p CellParams) Vec3:
	ambientCube(n, p.ambient)

# GetSoftLightMultiplier: light wrapped past the edge by `rolloff`, less the plain light
fn softMultiplier(nl f32, rolloff f32) f32:
	soft = ((rolloff + nl) / (1.0 + rolloff)).clamp(0.0, 1.0)
	plain = nl.clamp(0.0, 1.0)
	(soft * soft * (3.0 - 2.0 * soft) - plain * plain * (3.0 - 2.0 * plain)).clamp(0.0, 1.0)

# GetRimLightMultiplier
fn rimMultiplier(toward Vec3, toEye Vec3, n Vec3, power f32) f32:
	nv = (n @ toEye).clamp(0.0, 1.0)
	(1.0 - nv).max(1.0e-6).pow(power) * (toEye @ (toward * -1.0)).clamp(0.0, 1.0)

# What a light of `color` (its fall-off and shadow in) from `toward` gives a surface whose normal
# is n: its diffuse light (with the soft, rim and back light of the look, colored by soft and
# back) and its highlight.
fn lightOn(
	n Vec3,
	toEye Vec3,
	toward Vec3,
	color Vec3,
	look Look,
	soft Vec3,
	back Vec3
) (Vec3, Vec3):
	nl = n @ toward
	diffuse = color * nl.max(0.0)
	turnedOn = i32(look.lighting.z + 0.5)
	if (turnedOn & 1) != 0:
		diffuse += color * softMultiplier(nl, look.lighting.x) * soft
	if (turnedOn & 2) != 0:
		diffuse += color * rimMultiplier(toward, toEye, n, look.lighting.y) * soft
	if (turnedOn & 4) != 0:
		diffuse += color * (-nl).max(0.0) * back
	h = (toward + toEye).normalized()
	(diffuse, color * (h @ n).clamp(0.0, 1.0).pow(look.specular.w))

# the share of light i that reaches the surface: a shadow light's (the first four), else all
fn shareOf(shadows Vec4, i i32) f32:
	if i == 0:
		return shadows.x
	if i == 1:
		return shadows.y
	if i == 2:
		return shadows.z
	if i == 3:
		return shadows.w
	1.0

# a map of the look's (its texture + 1 in `slot`) at uv, white when it has none
fn lookMap(slot f32, uv Vec2, p CellParams) Vec3:
	k = i32(slot + 0.5) - 1
	if k < 0:
		return Vec3(1.0, 1.0, 1.0)
	p.textures[k].sample(uv).rgb

# The cube map at index k of the cell's textures (its six faces side by side, +x -x +y -y +z -z as Direct3D numbers
# them) seen along d, a direction of the game's world (z up).
fn cubeColor(k i32, d Vec3, p CellParams) Vec3:
	a = d.abs()
	face f32 = 0.0
	s f32 = 0.0
	t f32 = 0.0
	major = a.x
	if a.x >= a.y and a.x >= a.z:
		face = 0.0 if d.x > 0.0 else 1.0
		s = -d.z if d.x > 0.0 else d.z
		t = -d.y
	elif a.y >= a.z:
		major = a.y
		face = 2.0 if d.y > 0.0 else 3.0
		s = d.x
		t = d.z if d.y > 0.0 else -d.z
	else:
		major = a.z
		face = 4.0 if d.z > 0.0 else 5.0
		s = d.x if d.z > 0.0 else -d.x
		t = -d.y
	u = (s / major * 0.5 + 0.5).clamp(0.002, 0.998)
	v = (t / major * 0.5 + 0.5).clamp(0.002, 0.998)
	p.textures[k].sample(Vec2((face + u) / 6.0, v)).rgb

# the reflection of the cell's world in a surface: the cube map along the view's mirror about the
# normal, times its scale and its mask (the highlight's mask where it has none), the lit light
# times it (Lighting.hlsl's ENVMAP and EYE)
fn reflected(n Vec3, toEye Vec3, mask f32, light Vec3, look Look, uv Vec2, p CellParams) Vec3:
	k = i32(look.environment.x + 0.5) - 1
	if k < 0:
		return Vec3(0.0, 0.0, 0.0)
	mirror = n * (2.0 * (n @ toEye)) - toEye
	# the renderer's y is up, the game's z
	mirrored = inGame(mirror)
	weight = look.environment.y *
		(mask if look.environment.z < 0.5 else lookMap(look.environment.z, uv, p).x)
	cubeColor(k, mirrored, p) * weight * light

# how much of the cell's fog lies between the eye and `world`
pub fn fogAmount(world Vec3, p CellParams) f32:
	distance = (p.eye.xyz - world).length()
	f = p.fog
	((distance - f.x) / (f.y - f.x).max(1.0)).clamp(0.0, 1.0).pow(f.z.max(0.01)).min(f.w)

# the color c seen through the cell's fog from the eye at `world`
pub fn fogged(c Vec3, world Vec3, p CellParams) Vec3:
	amount = fogAmount(world, p)
	c.lerp(p.fogNearColor.rgb.lerp(p.fogFarColor.rgb, amount), amount)

# The color a part lit by its reference's emittance source (XEMI) takes, white for any other: the
# vanilla Effect.hlsl's PropertyColor (BSEffectShaderProperty+0x88) and Lighting.hlsl's EmitColor
# (BSLightingShaderProperty+0xF0) point at the source's color, a region's from its weather by the
# hour (emittance.zap); `marked` is the part's flag of it.
pub fn emittanceOf(marked f32, p CellParams) Vec3:
	p.emittance.rgb if marked > 0.5 else Vec3(1.0, 1.0, 1.0)

# The color of a surface of texture color `base` and vertex color `tint` at `world` (uv on its
# maps), its normal n, the highlight masked by `mask`, lit by the cell (`shadows` the share of
# each shadow light reaching it) and fogged: the vanilla shader's sum, clamps and fog.
pub fn shaded(
	base Vec3,
	tint Vec3,
	n Vec3,
	world Vec3,
	uv Vec2,
	mask f32,
	look Look,
	shadows Vec4,
	p CellParams
) Vec3:
	toEye = (p.eye.xyz - world).normalized()
	soft = lookMap(look.maps.x, uv, p)
	back = lookMap(look.maps.y, uv, p)
	diffuse, highlight = lightOn(
		n,
		toEye,
		p.sunToward.xyz,
		p.sunColor.rgb * sunVisibility(world, p),
		look,
		soft,
		back
	)
	for i in 0..p.lightCount:
		l = p.lights[i]
		d = l.place.xyz - world
		r = l.place.w
		reach = 1.0 - ((d @ d) / (r * r)).min(1.0)
		reach *= shareOf(shadows, i)
		if reach > 0.0:
			more, glint = lightOn(n, toEye, d.normalized(), l.color.rgb * reach, look, soft, back)
			diffuse += more
			highlight += glint
	emit = look.emit.rgb * emittanceOf(look.lighting.w, p)
	diffuse += ambientOf(n, p) + emit * lookMap(look.emit.w, uv, p)
	c = base * diffuse * tint
	lit = (c - fogged(c, world, p) + Vec3(postLit, postLit, postLit)).min(c)
	withHighlight = lit + highlight * mask * look.specular.rgb +
		reflected(n, toEye, mask, diffuse, look, uv, p)
	over = withHighlight - fogged(withHighlight, world, p)
	withHighlight.min(over + Vec3(postSpec, postSpec, postSpec)) - over

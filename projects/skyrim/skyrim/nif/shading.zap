# What a lit material (BSLightingShaderProperty) gives the vanilla lighting shader beyond its
# textures and highlight: the highlight's color, its own light (Own_Emit, a glow shader's glow
# map), and the soft, rim and back lighting its flags turn on with their maps (Community Shaders'
# Lighting.hlsl: SOFT_LIGHTING, RIM_LIGHTING, BACK_LIGHTING, GLOWMAP).

# flags 1: the material lights itself; its normal map is in the model's space; its light's color
# is its reference's emittance source's (XEMI), set by the game per frame
flagOwnEmit = 0x40_0000
flagModelSpaceNormals = 0x1000
flagExternalEmittance = 0x2000_0000
# flags 2: a glow map multiplies its light; soft, rim and back lighting
flagGlowMap = 0x40
flagSoftLighting = 0x200_0000
flagRimLighting = 0x400_0000
flagBackLighting = 0x800_0000

# the shader types that color an actor's skin (Lighting.hlsl's FACEGEN, FACEGEN_RGB_TINT, HAIR):
# the face by its FaceGen tint texture, the body by the actor's skin tone, the hair by its color
pub toneFace = 4
pub toneSkin = 5
pub toneHair = 6

# the lighting a Shading's `lighting` turns on
pub softLighting = 1
pub rimLighting = 2
pub backLighting = 4

pub type Shading:
	specularColor Vec3 = Vec3(1.0, 1.0, 1.0)
	# its color; the multiple is not applied (the captures show the windows' texture under
	# their glow, unsaturated)
	emissive Vec3 = Vec3(0.0, 0.0, 0.0)
	glowMap str = ""   # what the emissive light is multiplied by, "" for none
	lighting i64 = 0   # softLighting | rimLighting | backLighting
	softRolloff f32 = 0.0   # lighting effect 1: how far past the edge soft light wraps
	rimPower f32 = 0.0   # lighting effect 2
	lightingMap str = ""   # the soft and rim light's color (the glow slot)
	backMap str = ""   # the back light's color
	tone i64 = 0   # toneFace, toneSkin, toneHair, 0 for none
	toneColor Vec3 = Vec3(0.5, 0.5, 0.5)   # the skin's or the hair's tint the model gives
	detailMap str = ""   # a face's detail (its brightness about a quarter grey)
	tintMap str = ""   # a face's FaceGen tint
	environment str = ""   # the cube map the surface reflects (shader types 1 and 16)
	environmentMask str = ""   # where it reflects, "" for the gloss
	environmentScale f32 = 0.0
	specularMap str = ""   # the highlight's mask of a model-space normal map (its texture set's
	# specular slot; such a map's alpha is not the mask)
	# its emissive color is its reference's emittance source's (XEMI) times the multiple
	# (BSLightingShader's SetupGeometry 0x141549550: EmitColor = *emissiveColor x emissiveMult)
	external bool = false
	emissiveMultiple f32 = 1.0

# the skin's or the hair's tint a lighting shader of those types gives, a mid grey (no tint) else
fn toneColorOf(extra ShaderExtra):
	match extra:
		SkinTint(color): color
		HairTint(color): color
		_: Vec3(0.5, 0.5, 0.5)

# the reflection's strength a lighting shader of its type gives, 0 for none
fn environmentScaleOf(extra ShaderExtra):
	match extra:
		EnvironmentMap(scale): scale
		Eye(scale, _, _): scale
		_: 0.0

# A lit material as the model gives it: the shader property's fields and its texture set's
# paths, from which its Shading and highlight are taken (kept whole, a renderer can take them
# again when it reads its flags differently)
pub type LitMaterial:
	shader LightingShader
	paths str[]

# path k of the material's texture set, "" for none
pub fn slotPath(l LitMaterial, k i64) str:
	l.paths[k].copy() if k < l.paths.len else ""

# the highlight's strength, 0 when the material has none (no Specular flag)
pub fn specularOf(l LitMaterial) f32:
	l.shader.specularStrength if (l.shader.flags1 & flagSpecular) != 0 else 0.0

pub fn shadingOf(l LitMaterial) Shading:
	m = l.shader
	lighting = 0
	if (m.flags2 & flagSoftLighting) != 0: lighting |= softLighting
	if (m.flags2 & flagRimLighting) != 0: lighting |= rimLighting
	if (m.flags2 & flagBackLighting) != 0: lighting |= backLighting
	glows = (m.flags2 & flagGlowMap) != 0
	face = m.shaderType == toneFace
	scale = m.extra.environmentScaleOf()
	Shading(
		specularColor = m.specularColor,
		emissive = m.emissiveColor if (m.flags1 & flagOwnEmit) != 0 or glows
		else Vec3(0.0, 0.0, 0.0),
		emissiveMultiple = m.emissiveMultiple,
		glowMap = l.slotPath(slotGlow) if glows else "",
		lighting,
		softRolloff = m.lightingEffect1,
		rimPower = m.lightingEffect2,
		lightingMap = l.slotPath(slotGlow)
		if (lighting & (softLighting | rimLighting)) != 0 else "",
		backMap = l.slotPath(slotSpecular) if (lighting & backLighting) != 0
		else "",
		tone = m.shaderType if m.shaderType in [toneFace, toneSkin, toneHair] else 0,
		toneColor = m.extra.toneColorOf(),
		detailMap = l.slotPath(slotParallax) if face else "",
		tintMap = l.slotPath(slotSubsurface) if face else "",
		environment = l.slotPath(slotEnvironment) if scale > 0.0 else "",
		environmentMask = l.slotPath(slotEnvironmentMask) if scale > 0.0 else "",
		environmentScale = scale,
		specularMap = l.slotPath(slotSpecular)
		if (m.flags1 & flagModelSpaceNormals) != 0 else "",
		external = (m.flags1 & flagExternalEmittance) != 0
	)

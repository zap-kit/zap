# The blocks that say how a shape looks: BSLightingShaderProperty (Skyrim's lit materials: its
# shader type, read before the name, the flags, the UV transform, the texture set, the emissive
# color, the clamp mode, alpha, refraction, glossiness, the specular color and strength, two
# lighting effects, then fields of its type alone), BSEffectShaderProperty (effects: one source
# texture, a base color, falloff), BSShaderTextureSet (the texture paths) and NiAlphaProperty.

# the shader flags 2 bit of a material drawn from both sides
pub flagDoubleSided = 0x10

# long: the two tables name the 32 bits of each
# the names of the bits of SkyrimShaderPropertyFlags1 (SLSF1), bit 0 first (nif.xml's)
pub flags1Names = [
	"Specular", "Skinned", "Temp_Refraction", "Vertex_Alpha", "Greyscale_To_PaletteColor",
	"Greyscale_To_PaletteAlpha", "Use_Falloff", "Environment_Mapping", "Receive_Shadows",
	"Cast_Shadows", "Facegen_Detail_Map", "Parallax", "Model_Space_Normals",
	"Non_Projective_Shadows", "Landscape", "Refraction", "Fire_Refraction",
	"Eye_Environment_Mapping", "Hair_Soft_Lighting", "Screendoor_Alpha_Fade",
	"Localmap_Hide_Secret", "FaceGen_RGB_Tint", "Own_Emit", "Projected_UV", "Multiple_Textures",
	"Remappable_Textures", "Decal", "Dynamic_Decal", "Parallax_Occlusion", "External_Emittance",
	"Soft_Effect", "ZBuffer_Test"
]

# the names of the bits of SkyrimShaderPropertyFlags2 (SLSF2), bit 0 first
pub flags2Names = [
	"ZBuffer_Write", "LOD_Landscape", "LOD_Objects", "No_Fade", "Double_Sided", "Vertex_Colors",
	"Glow_Map", "Assume_Shadowmask", "Packed_Tangent", "Multi_Index_Snow", "Vertex_Lighting",
	"Uniform_Scale", "Fit_Slope", "Billboard", "No_LOD_Land_Blend", "EnvMap_Light_Fade",
	"Wireframe", "Weapon_Blood", "Hide_On_Local_Map", "Premult_Alpha", "Cloud_LOD",
	"Anisotropic_Lighting", "No_Transparency_Multisampling", "Unused01", "Multi_Layer_Parallax",
	"Soft_Lighting", "Rim_Lighting", "Back_Lighting", "Unused02", "Tree_Anim", "Effect_Lighting",
	"HD_LOD_Objects"
]

# the names of the bits set in `flags`, from a table of the names of bits 0 to 31
pub fn flagNames(flags i64, names str[]) str[]:
	out = []
	for bit in 0..names.len:
		if (flags >> bit) & 1 != 0: out.push(names[bit].copy())
	out

# the texture set's slots
pub slotDiffuse = 0
pub slotNormal = 1   # the gloss in its alpha
pub slotGlow = 2   # or the skin's, the hair's, the rim light's
pub slotParallax = 3
pub slotEnvironment = 4
pub slotEnvironmentMask = 5
pub slotSubsurface = 6
pub slotSpecular = 7   # or the back light's

# what a lighting shader of one type adds after the common fields
pub type ShaderExtra:
	Plain
	EnvironmentMap(scale f32)   # type 1
	SkinTint(color Vec3)   # type 5
	HairTint(color Vec3)   # type 6
	Parallax(passes f32, scale f32)   # type 7
	MultiLayerParallax(thickness f32, refraction f32, textureScale Vec2, environment f32)   # 11
	Sparkle(parameters Vec4)   # type 14, snow
	Eye(cubeMapScale f32, left Vec3, right Vec3)   # type 16

pub type LightingShader:
	name str
	controller i64   # the first controller of its values, -1 none
	shaderType i64
	flags1 i64
	flags2 i64
	uvOffset Vec2
	uvScale Vec2
	textureSet i64
	emissiveColor Vec3
	emissiveMultiple f32
	clampMode i64
	alpha f32
	refraction f32
	glossiness f32
	specularColor Vec3
	specularStrength f32
	lightingEffect1 f32
	lightingEffect2 f32
	extra ShaderExtra

pub type EffectShader:
	name str
	controller i64
	flags1 i64
	flags2 i64
	uvOffset Vec2
	uvScale Vec2
	sourceTexture str
	clampMode i64
	falloff Vec4   # start and stop angles' cosines, start and stop opacities
	baseColor Vec4
	baseColorScale f32
	greyscaleTexture str
	lightingInfluence f32   # 0..1: how far the cell's light colors it (with Effect_Lighting)
	softDepth f32   # over how much depth it fades in where it meets what is behind it (Soft_Effect)

# BSSkyShaderProperty: what a sky object (the dome, the clouds, the stars, a moon) is drawn with:
# its texture and what kind of object it is (0 sun, 1 sun glare, 2 atmosphere, 3 clouds, 4 stars,
# 5 moon, 6 moon shadow, 7 aurora)
pub type SkyShader:
	flags1 i64
	flags2 i64
	uvOffset Vec2
	uvScale Vec2
	sourceTexture str
	objectType i64

fn readSkyShader(mut s Reader, names str[]):
	s.readNet(names)
	SkyShader(
		flags1 = s.u32(),
		flags2 = s.u32(),
		uvOffset = s.vec2(),
		uvScale = s.vec2(),
		sourceTexture = s.sized(),
		objectType = s.u32()
	)

# NiAlphaProperty: its flags taken apart (blending's source and destination factors are
# Gamebryo's: 6 source alpha, 7 one minus source alpha...; the test functions 0 always to 7 never)
pub type Alpha:
	blend bool = false
	source i64 = 6
	destination i64 = 7
	test bool = false
	testFunction i64 = 4
	threshold i64 = 128

fn readExtra(mut s Reader, shaderType i64) ShaderExtra:
	match shaderType:
		1: .EnvironmentMap(s.f32())
		5: .SkinTint(s.vec3())
		6: .HairTint(s.vec3())
		7:
			passes = s.f32()
			.Parallax(passes, s.f32())
		11:
			thickness = s.f32()
			refraction = s.f32()
			textureScale = s.vec2()
			.MultiLayerParallax(thickness, refraction, textureScale, s.f32())
		14:
			.Sparkle(s.vec4())
		16:
			scale = s.f32()
			left = s.vec3()
			.Eye(scale, left, s.vec3())
		_: .Plain

fn readLightingShader(mut s Reader, names str[]):
	shaderType = s.u32()
	name, _, controller = s.readNet(names)
	LightingShader(
		name,
		controller,
		shaderType,
		flags1 = s.u32(),
		flags2 = s.u32(),
		uvOffset = s.vec2(),
		uvScale = s.vec2(),
		textureSet = s.i32(),
		emissiveColor = s.vec3(),
		emissiveMultiple = s.f32(),
		clampMode = s.u32(),
		alpha = s.f32(),
		refraction = s.f32(),
		glossiness = s.f32(),
		specularColor = s.vec3(),
		specularStrength = s.f32(),
		lightingEffect1 = s.f32(),
		lightingEffect2 = s.f32(),
		extra = s.readExtra(shaderType)
	)

fn readEffectShader(mut s Reader, names str[]):
	name, _, controller = s.readNet(names)
	flags1 = s.u32()
	flags2 = s.u32()
	uvOffset = s.vec2()
	uvScale = s.vec2()
	sourceTexture = s.sized()
	clampMode = s.u8()
	lightingInfluence = f32(s.u8()) / 255.0
	s.skip(2)   # the environment map's least level, one unused
	falloff = s.vec4()
	baseColor = s.vec4()
	baseColorScale = s.f32()
	softDepth = s.f32()
	EffectShader(
		name,
		controller,
		flags1,
		flags2,
		uvOffset,
		uvScale,
		sourceTexture,
		clampMode,
		falloff,
		baseColor,
		baseColorScale,
		greyscaleTexture = s.sized(),
		lightingInfluence,
		softDepth
	)

fn readAlpha(mut s Reader, names str[]):
	s.readNet(names)
	flags = s.u16()
	Alpha(
		blend = (flags & 1) != 0,
		source = (flags >> 1) & 0xF,
		destination = (flags >> 5) & 0xF,
		test = (flags & 0x200) != 0,
		testFunction = (flags >> 10) & 7,
		threshold = s.u8()
	)

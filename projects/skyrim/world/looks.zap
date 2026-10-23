# A lit material's look as the shader reads it (shaders.Look: its highlight, its own light, its
# soft, rim and back lighting, its reflection), its maps found by their keys among the prepared
# textures. The cell keeps each lit part's material whole (nif.LitMaterial) and takes its look
# when it is drawn, so a change of how a material's fields or flags become its look needs no new
# prepare.

import skyrim.nif
import world.shaders

# the key a cube map's strip of faces is kept under among the textures
pub fn cubeKey(path str) str:
	"cube {nif.textureKey(path)}"

# the texture under this key + 1, 0 for none
fn slotOf(keys {str: i64}, key str) f32:
	f32((keys.get(key) ?? -1) + 1)

fn mapSlot(keys {str: i64}, path str) f32:
	0.0 if path.isEmpty else keys.slotOf(nif.textureKey(path))

pub fn lookOf(s nif.Shading, specularStrength f32, glossiness f32, keys {str: i64}) shaders.Look:
	shaders.Look(
		specular = (s.specularColor * specularStrength).withW(glossiness),
		emit = s.emissive.withW(keys.mapSlot(s.glowMap)),
		lighting = Vec4(s.softRolloff, s.rimPower, f32(s.lighting), 0.0),
		maps = Vec4(keys.mapSlot(s.lightingMap), keys.mapSlot(s.backMap), 0.0, 0.0),
		environment = Vec4(
			0.0 if s.environment.isEmpty else keys.slotOf(cubeKey(s.environment)),
			s.environmentScale,
			keys.mapSlot(s.environmentMask),
			0.0
		)
	)

# the look of a lit part's material, a plain one's (no shader property) when it has none
pub fn surfaceLook(lit nif.LitMaterial?, keys {str: i64}) shaders.Look:
	match lit:
		l: l.shadingOf().lookOf(l.specularOf(), l.shader.glossiness, keys)
		none: lookOf(nif.Shading(), 0.0, 0.0, keys)

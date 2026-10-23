# The programs of the 3D scenes, made once, and the surface the lit ones read (shaders/mesh.gpu.zap's
# Surface): the view, the material, the sun and the sky, the point lights, a shadow map.

import engine
import deep.shaders

pub type Shaders:
	lit engine.Program   # lit.gpu.zap: sun, shadow, four lights, sky
	depth engine.Program   # a shadow map's pass
	relief engine.Program   # relief.gpu.zap: parallax occlusion
	lights engine.Program   # lights.gpu.zap: hundreds of lights from a storage block
	bulb engine.Program   # a light's bulb, once per light

pub fn newShaders() Shaders:
	Shaders(
		lit = engine.newProgram(shader(shaders.meshVertex, shaders.litPixel)),
		depth = engine.newProgram(shader(shaders.meshVertex, shaders.depthPixel)),
		relief = engine.newProgram(shader(shaders.meshVertex, shaders.reliefPixel)),
		lights = engine.newProgram(shader(shaders.meshVertex, shaders.lightsPixel)),
		bulb = engine.newProgram(shader(shaders.bulbVertex, shaders.bulbPixel)))

# The surface seen from the view: plain (no material yet, the four point lights off, no shadow
# map, no checker, no palette), at the origin.
pub fn surfaceOf(v View) shaders.Surface:
	zero = Vec3(0.0, 0.0, 0.0)
	lights shaders.PointLight[4]
	for i in 0..4:
		lights[i] = shaders.PointLight(at = Vec4(0.0, 0.0, 0.0, 0.0), color = zero)
	shaders.Surface(
		viewProj = v.viewProj,
		model = Mat4(1.0),
		eye = v.eye,
		albedo = zero,
		metal = 0.0,
		rough = 0.0,
		emissive = zero,
		sunDir = zero,
		sunLight = zero,
		night = 0.0,
		lights,
		shadowViewProj = Mat4(1.0),
		shadowed = false,
		checker = false,
		paletted = false,
		depthScale = 0.0,
		lightCount = 0,
		shadowMap = engine.ShadowMap(id = -1, size = 0), relief = engine.Texture(
			id = -1,
			width = 0,
			height = 0
		), many = [])

# the surface's material: its albedo, metalness and roughness, light of its own
pub fn material(
	mut s shaders.Surface,
	albedo Vec3,
	metal f32,
	rough f32,
	emissive Vec3 = Vec3(0.0, 0.0, 0.0)
):
	s.albedo = albedo
	s.metal = metal
	s.rough = rough
	s.emissive = emissive

# the sun (toward it, its radiance) and the sky (0 day .. 1 night)
pub fn sky(mut s shaders.Surface, sunDir Vec3, sunLight Vec3, night f32):
	s.sunDir = sunDir
	s.sunLight = sunLight
	s.night = night

# point light i (0..3): where it is, how far it reaches (0: off), its color and strength
pub fn pointLight(mut s shaders.Surface, i i64, at Vec3, reach f32, light Vec3):
	s.lights[i] = shaders.PointLight(at = Vec4(at.x, at.y, at.z, reach), color = light)

# a model drawn by the program, placed by m, the surface as it is
pub fn drawPlaced(
	r engine.Renderer,
	p engine.Program,
	mut s shaders.Surface,
	m Mat4,
	model engine.Model
):
	s.model = m
	p.setParams(s)
	r.drawModel(p, model)

# the checkered ground in a material of this color and roughness (the checker on only for it)
pub fn drawGround(
	r engine.Renderer,
	p engine.Program,
	mut s shaders.Surface,
	ground engine.Model,
	albedo Vec3,
	rough f32
):
	s.checker = true
	s.material(albedo, 0.0, rough)
	r.drawPlaced(p, s, Mat4(1.0), ground)
	s.checker = false

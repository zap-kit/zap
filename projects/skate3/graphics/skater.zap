# The skater on the GPU and drawn where he stands, turned to his heading: each part of his body
# and of his board a model with its texture and tint.

import engine
import skate
import graphics.shaders

pub type SkaterPart:
	texture engine.Texture
	tint Vec4
	alphaTest bool
	model engine.Model

pub type SkaterFigure:
	program engine.Program
	parts SkaterPart[]
	textures engine.GpuTexture[] = []   # whose handles the parts read

pub fn newSkaterFigure(move s skate.Skater) SkaterFigure:
	gpu = uploadTextures(s.textures, {})
	textures = gpu.byId
	white = gpu.white
	program = engine.newProgram(shader(shaders.skaterVertex, shaders.skaterPixel))
	parts = []
	for m in s.meshes:
		parts.push(SkaterPart(
			texture = textures.get(m.color) ?? white,
			tint = Vec4(m.tint[0], m.tint[1], m.tint[2], 1.0),
			alphaTest = m.alphaTest,
			model = engine.newModel(m.vertices, program.vertexStride)))
	SkaterFigure(program, parts, textures = gpu.owned)

pub fn drawSkater(
	mut r engine.Renderer,
	f SkaterFigure,
	sc WorldScene,
	place Mat4,
	projection Mat4,
	view Mat4,
	eye Vec3
):
	p = f.program
	r.setBlending(false)
	r.setDepth(true, true, false)
	params = shaders.SkaterParams(
		projection,
		view,
		model = place,
		tint = engine.white,
		alphaTest = false,
		sun = Vec3(0.4, 0.8, 0.3).normalized(), exposure = 1.0, eye, haze = sc.hazeOf(), picture = engine.Texture(
			id = -1,
			width = 0,
			height = 0
	))
	for part in f.parts:
		params.tint = part.tint
		params.alphaTest = part.alphaTest
		params.picture = part.texture
		p.setParams(params)
		r.drawModel(p, part.model)

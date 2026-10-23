# A skinned figure from a glTF file drawn in the world: posed on the CPU (a clip at a time, or a
# pose the caller writes as a one-key clip), bent on the GPU by the engine's skinned vertex
# stage, lit as the skater is.

import engine
import graphics.shaders

pub type GltfFigure:
	program engine.Program
	models engine.SkinnedModel[]
	crowd engine.Crowd

pub fn newGltfFigure(path str) GltfFigure:
	GltfFigure(
		program = engine.newProgram(shader(engine.skinnedVertex, shaders.figurePixel)),
		models = [engine.loadSkinned(path)],
		crowd = engine.newCrowd(1)
	)

# the figure standing at `at` turned `yaw` about y, in `pose`, drawn into the world scene
pub fn drawGltfFigure(
	mut r engine.Renderer,
	mut f GltfFigure,
	sc WorldScene,
	pose engine.Pose,
	at Vec3,
	yaw f32,
	projection Mat4,
	view Mat4,
	eye Vec3
):
	f.crowd.clear()
	f.crowd.addBody(0, f.models[0], pose, at, yaw, 1.0, 0.0, 0.0, engine.white)
	r.setBlending(false)
	r.setDepth(true, true, false)
	f.crowd.setView(f.program, projection @ view)
	params = shaders.FigureParams(
		sun = Vec3(0.4, 0.8, 0.3).normalized(),
		exposure = 1.0,
		eye,
		haze = sc.hazeOf(),
		picture = engine.Texture(id = -1, width = 0, height = 0))
	for part in f.crowd.crowdParts(f.models):
		params.picture = part.texture
		f.program.setParams(params)
		f.crowd.drawPart(r, f.program, f.models, part)

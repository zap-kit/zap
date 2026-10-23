# The prepared cast on the GPU and drawn in the cell: every body an engine skinned model posed by
# its skeleton's rig (the clips the skeleton's bodies share), the frame's bodies one crowd whose
# palettes the poses make, bent by the engine's skinned vertex stage, each part lit as the cell is
# (shaders.actorPixel) with its material, its textures and its skin's tone.

import engine
import engine.gltf
import skyrim
import skyrim.actor
import world.shaders

# a head shape's lip morphs with its vertices at rest
type FaceRest:
	shape actor.FaceShape
	rest f32[]

# a model's face: its shapes and the lip targets' weights it shows now
type Face:
	shapes FaceRest[]
	shown f32[]

pub type ActorScene:
	program engine.Program
	models engine.SkinnedModel[]   # the player's body, then each NPC's in the cast's order
	skeletonOf i64[]   # by model: the skeleton that poses it
	scales f32[]   # by model
	motions engine.Rig[]   # the skeletons' rigs, their clips
	speeds f32[,]   # by skeleton, by clip: how fast its motion carries the actor, units a second
	crowd engine.Crowd
	textures engine.GpuTexture[]
	materials ActorMaterial[,]   # by model, by part
	params shaders.CellParams   # the cell's light, the cast's textures and the part's material
	faces Face[]   # by model

# a body of the frame: its model, its pose, its feet (y up) and its turn about y (0 facing -z)
pub type ActorPose:
	model i64
	pose engine.Pose
	feet Vec3
	yaw f32

fn skinnedOf(h ActorHead):
	model = engine.newSkinned(modelOf(h.body.copy()))
	if model.parts.len != h.materials.len: fail("a prepared actor has a part without triangles")
	model

# the skeleton's rig: its nodes at rest and the clips that move them
pub fn skeletonRig(s SkeletonHead) engine.Rig:
	m = modelOf(s.rig.copy())
	m.rigOf()

# The prepared cast on the GPU, lit by the cell's lights.
pub fn newActorScene(c CastHead, file engine.Prepared, cell CellScene) ActorScene:
	body = file.bodyOf()
	textures = c.textures.map(gpuTexture(body, it))
	params = cell.params.copy()
	params.textures = textures.map(.texture())
	heads = [c.player.copy()]
	heads.extend(c.npcs.map(.look.copy()))
	ActorScene(
		faces = heads.map(.faceOf()),
		program = engine.newProgram(shader(engine.skinnedVertex, shaders.actorPixel)),
		models = heads.map(.skinnedOf()),
		skeletonOf = heads.map(.skeleton),
		scales = heads.map(.scale),
		motions = c.skeletons.map(.skeletonRig()),
		speeds = c.skeletons.map(.speeds.copy()),
		crowd = engine.newCrowd(heads.len),
		textures,
		materials = heads.map(.materials.copy()),
		params
	)

fn faceOf(h ActorHead):
	floats = gltf.skinVertexFloats
	Face(
		shapes = h.faces.map(
			FaceRest(
				shape = it.copy(),
				rest = h.body.vertices[it.first * floats..(it.first + it.count) * floats].copy()
			)
		),
		shown = fill(skyrim.lipPhonemes.len + skyrim.lipModifiers.len, 0.0)
	)

# The model's face moved by the weights of the lip targets (skyrim.lipTarget's order), as the lip
# track of a line and the blinks give them; nothing is written when they are those it has.
pub fn setFace(mut a ActorScene, model i64, weights f32[]):
	if a.faces[model].shown == weights: return
	for f in a.faces[model].shapes:
		engine.writeSkinnedVertices(
			a.models[model],
			f.shape.first,
			f.shape.shapeMoved(f.rest, weights)
		)
	a.faces[model].shown = weights.copy()

# the part's material as the actor pixel stage reads it
fn setPart(mut a ActorScene, m ActorMaterial):
	a.params.part = m.look
	a.params.partCutout = m.cutout
	a.params.partDiffuse = i32(m.diffuse)
	a.params.partNormalMap = i32(m.normalMap)
	a.params.partTone = Vec4(f32(m.tone), f32(m.tintMap), f32(m.detailMap), 0.0)
	a.params.partToneColor = m.toneColor.withW(1.0)

# The frame's bodies drawn into the cell's screen and depth.
pub fn drawActors(
	mut r engine.Renderer,
	mut a ActorScene,
	bodies ActorPose[],
	projection Mat4,
	view Mat4,
	eye Vec3
):
	if bodies.isEmpty: return
	a.crowd.clear()
	for b in bodies:
		a.crowd.addMovedBody(b.model, a.models[b.model], a.motions[a.skeletonOf[b.model]], b.pose,
			b.feet, b.yaw, a.scales[b.model], 0.0, 0.0, engine.white)
	a.crowd.setView(a.program, projection @ view)
	a.params.projection = projection
	a.params.view = view
	a.params.eye = eye.withW(1.0)
	r.setBlending(false)
	r.setDepth(true, true, true)
	for part in a.crowd.crowdParts(a.models):
		a.setPart(a.materials[part.model][part.part])
		a.program.setParams(a.params)
		a.crowd.drawPart(r, a.program, a.models, part)

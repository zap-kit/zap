# The grass on the GPU: each kind's model once, its plants as instances (shaders/grass.gpu.zap),
# drawn with the opaque parts into the cell's picture and into its normal buffer, both sides of each
# blade. The way in: addGrass with the kinds (game/grass.zap makes them); advance runs the wind's
# clock.

import engine
import world.shaders

# the mesh of one kind of grass (the game's axes) and the texture it names (in the batch's own list)
pub type GrassModel:
	vertices shaders.GrassVertex[]
	indices u32[]
	texture f32

# one kind: its model, its plants, how it sways and whether its scale is uniform
pub type GrassKind:
	model GrassModel
	instances shaders.GrassInstance[]
	wavePeriod f32
	uniform bool

# a kind on the GPU: its mesh and the plants to draw
pub type GrassDraw:
	mesh MeshDraw
	instances shaders.GrassInstance[]

# the scene's grass: the program, the kinds drawn, the textures the kinds own, the clock and the
# wind's strength
pub type GrassSet:
	program engine.Program
	draws GrassDraw[] = []
	kinds Vec4[] = []
	textures engine.GpuTexture[] = []
	seconds f32 = 0.0
	wind f32 = 0.0

pub fn newGrassSet() GrassSet:
	GrassSet(program = engine.newProgram(shader(shaders.grassVertex, shaders.grassPixel)))

# an instance of the kind numbered `kind`
fn renumbered(i shaders.GrassInstance, kind f32):
	shaders.GrassInstance(
		place = i.place,
		rowX = i.rowX,
		rowY = i.rowY,
		rowZ = Vec4(i.rowZ.x, i.rowZ.y, i.rowZ.z, kind)
	)

# The grass added to a scene: its textures join the cell's list, which the kinds' models name from
# where the cell's end; `wind` is the most the wind moves a blade, in units.
pub fn addGrass(
	mut sc CellScene,
	kinds GrassKind[],
	move textures engine.GpuTexture[],
	wind f32
):
	first = f32(sc.params.textures.len)
	for t in textures:
		sc.params.textures.push(t.texture())
	sc.grass.textures.extend(textures)
	for k in kinds:
		number = f32(sc.grass.kinds.len)
		sc.grass.kinds.push(
			Vec4(k.model.texture + first, k.wavePeriod, 1.0 if k.uniform else 0.0, 0.0)
		)
		sc.grass.draws.push(
			GrassDraw(
				mesh = newMeshDraw(k.model.vertices, k.model.indices),
				instances = k.instances.map(.renumbered(number))
			)
		)
	sc.grass.wind = wind

# the wind's clock on
pub fn advanceGrass(mut sc CellScene, dt f32):
	sc.grass.seconds += dt

# the grass drawn, its blades turned to the normal pass's view normals when `normals`
pub fn drawGrass(mut r engine.Renderer, sc CellScene, normals bool):
	if sc.grass.draws.isEmpty: return
	cell = sc.params
	params = shaders.GrassParams(
		projection = cell.projection,
		view = cell.view,
		eye = cell.eye,
		ambient = cell.ambient,
		sunColor = cell.sunColor,
		fogNearColor = cell.fogNearColor,
		fogFarColor = cell.fogFarColor,
		fog = cell.fog,
		textures = cell.textures.copy(),
		kinds = sc.grass.kinds.copy(),
		seconds = sc.grass.seconds,
		windMagnitude = sc.grass.wind,
		normalPass = 1.0 if normals else 0.0
	)
	program = sc.grass.program
	program.setParams(params)
	r.setBlending(false)
	r.setDepth(true, true, false)
	for d in sc.grass.draws:
		r.drawInstances(program, d.mesh.model, d.instances)

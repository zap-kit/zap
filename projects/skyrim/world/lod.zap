# The distant land and objects on the GPU: their vertices and indices in one buffer each, their
# textures sent with their levels and read by index (bindless) among the cell's, drawn after the
# near land into the cell's picture and into its normal buffer (shaders/lod.gpu.zap).

import engine
import world.shaders

# The vertex stage and the pixel stage of the distant land and objects, one program for every batch
# of a scene.
pub fn newLodProgram() engine.Program:
	engine.newProgram(shader(shaders.lodVertex, shaders.lodPixel))

# a vertex with its textures' indices moved by `by` (its batch's textures joined to a longer list)
fn shiftedMaps(v shaders.LodVertex, by f32):
	noise = v.maps.z + by if v.maps.z >= 0.0 else v.maps.z
	shaders.LodVertex(
		position = v.position,
		normal = v.normal,
		uv = v.uv,
		color = v.color,
		maps = Vec4(v.maps.x + by, v.maps.y + by, noise, v.maps.w)
	)

# The distant land and objects added to a scene: their textures join the cell's list, which their
# vertices index from where the cell's end.
pub fn addLodMesh(
	mut sc CellScene,
	vertices shaders.LodVertex[],
	indices u32[],
	move textures engine.GpuTexture[]
):
	first = f32(sc.params.textures.len)
	for t in textures:
		sc.params.textures.push(t.texture())
	draw = newMeshDraw(vertices.map(.shiftedMaps(first)), indices)
	draw.textures = textures
	sc.lods.push(draw)

pub fn drawLods(mut r engine.Renderer, sc CellScene):
	if sc.lods.isEmpty: return
	program = sc.lodProgram
	program.setParams(sc.params)
	for l in sc.lods:
		r.setDepth(true, true, true)
		r.drawIndexed(program, l.model, l.indices, l.indices.count)

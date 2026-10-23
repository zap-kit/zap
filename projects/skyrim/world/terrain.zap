# The landscape on the GPU: the vertices and indices of its quadrants in one buffer each, its
# textures sent with their levels and read by index (bindless) among the cell's, drawn with the
# opaque parts into the cell's picture and again into its normal buffer.

import engine
import world.shaders

# The vertex stage and the pixel stage of the landscape, one program for every landscape of a scene.
pub fn newTerrainProgram() engine.Program:
	engine.newProgram(shader(shaders.terrainVertex, shaders.terrainPixel))

# the landscape's mesh sent to the GPU
pub fn newTerrainDraw(
	vertices engine.TerrainVertex[],
	indices u32[],
	move textures engine.GpuTexture[]
) MeshDraw:
	draw = newMeshDraw(vertices, indices)
	draw.textures = textures
	draw

# The landscape added to a scene: its textures join the cell's list, which its vertices index from
# where the cell's end (`firstTexture` is that index).
pub fn addTerrainMesh(
	mut sc CellScene,
	vertices engine.TerrainVertex[],
	indices u32[],
	move textures engine.GpuTexture[]
):
	first = f32(sc.params.textures.len)
	for t in textures:
		sc.params.textures.push(t.texture())
	sc.terrains.push(newTerrainDraw(vertices.map(.shiftedTiles(first)), indices, textures))

pub fn drawTerrains(mut r engine.Renderer, sc CellScene):
	program = sc.terrainProgram
	program.setParams(sc.params)
	for t in sc.terrains:
		r.setDepth(true, true, true)
		r.drawIndexed(program, t.model, t.indices, t.indices.count)

# The land of an exterior area's loaded grid (game/terrain.zap's terrainOf over the grid's cells):
# the ground the player walks on is part of the area's physics, written with it, and its mesh is
# drawn with the scene.

import engine.physics
import skyrim
import skyrim.esm

# the cells of the area's loaded grid, as the corners x0..x1, y0..y1 of terrainOf
fn gridCorners(area esm.Area):
	half = esm.gridSide(5) / 2
	(area.x - half, area.y - half, area.x + half, area.y + half)

# the land of the area's whole grid with its textures
pub fn terrainOfArea(install skyrim.Install, mut plugin esm.Esm, area esm.Area) Terrain:
	x0, y0, x1, y1 = area.gridCorners()
	install.terrainOf(plugin, area.world, x0, y0, x1, y1)

# the area's land as the physics walks on it, without its textures (the world made ahead)
pub fn collideAreaLand(mut w physics.World, plugin esm.Esm, area esm.Area):
	x0, y0, x1, y1 = area.gridCorners()
	land = Terrain(vertices = [], indices = [], textures = [], body = [], grids = [])
	for y in y0..=y1:
		for x in x0..=x1:
			if plugin.landOf(area.world, x, y) is l:
				land.grids.push(TerrainGrid(x, y, heights = l.heights.copy()))
	w.collideTerrain(land)

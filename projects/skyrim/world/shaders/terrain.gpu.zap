# The landscape drawn as Skyrim's lighting shader draws it (the LANDSCAPE permutation of
# Lighting.hlsl): the tiles of a quadrant blended by their weights per pixel (engine.tileShares)
# under the cell's vertex colors, the normal bent by the blended normal map, then lit and fogged
# as any other surface of the cell (lighting.gpu.zap) with no highlight of its own.

import engine

# the land's material: no soft, rim or back light, no glow, no reflection, and a highlight
# only where the cell's lights give one to its normal map's alpha
terrainLook = Look(
	specular = Vec4(0.0, 0.0, 0.0, 1.0),
	emit = Vec4(0.0, 0.0, 0.0, 0.0),
	lighting = Vec4(0.0, 0.0, 0.0, 0.0),
	maps = Vec4(0.0, 0.0, 0.0, 0.0),
	environment = Vec4(0.0, 0.0, 0.0, 0.0)
)

pub fn terrainVertex(v engine.TerrainVertex, p CellParams) (Vec4, engine.TerrainPoint):
	(p.projection @ p.view @ v.position.withW(1.0), engine.terrainPoint(v))

# the tile's diffuse and normal map texels times its share
fn tileTexel(
	b engine.TerrainPoint,
	p CellParams,
	diffuse f32,
	normalMap f32,
	share f32
) (Vec4, Vec4):
	(
		p.textures[engine.tileSlot(diffuse)].sample(b.uv) * share,
		p.textures[engine.tileSlot(normalMap)].sample(b.uv) * share
	)

pub fn terrainPixel(b engine.TerrainPoint, p CellParams) Vec4:
	if p.debugId > 0.5:
		return Vec4(0.0, 0.0, 0.0, 1.0)
	s = engine.tileShares(b)
	d0, n0 = tileTexel(b, p, b.diffuse.x, b.normalMaps.x, s.first.x)
	d1, n1 = tileTexel(b, p, b.diffuse.y, b.normalMaps.y, s.first.y)
	d2, n2 = tileTexel(b, p, b.diffuse.z, b.normalMaps.z, s.first.z)
	d3, n3 = tileTexel(b, p, b.diffuse.w, b.normalMaps.w, s.first.w)
	d4, n4 = tileTexel(b, p, b.diffuse2.x, b.normalMaps2.x, s.second.x)
	d5, n5 = tileTexel(b, p, b.diffuse2.y, b.normalMaps2.y, s.second.y)
	diffuse = d0 + d1 + d2 + d3 + d4 + d5
	normalMap = n0 + n1 + n2 + n3 + n4 + n5
	n = b.normal.normalized()
	tangent = (b.tangent - n * (n @ b.tangent)).normalized()
	bent = bentBy(n, tangent, n.cross(tangent), normalMap)
	if p.normalPass > 0.5:
		return (p.view @ bent.withW(0.0)).xyz.withW(1.0)
	shadows = shadowsAt(b.world, p)
	shaded(diffuse.rgb, b.color.rgb, bent, b.world, b.uv, normalMap.a, terrainLook, shadows, p)
		.withW(1.0)

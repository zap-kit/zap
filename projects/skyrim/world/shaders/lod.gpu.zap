# The distant land and objects as Skyrim's lighting shader draws them (the LODLANDNOISE and
# LODOBJECTS permutations of Lighting.hlsl): the land's block texture times the noise texture's
# blend (GetLodLandBlendParameter / GetLodLandBlendMultiplier) under a model-space normal map, the
# objects' atlas texture under their vertex normals, both lit and fogged as any surface of the cell
# (lighting.gpu.zap) with no highlight. Beyond 70000 units the land is pushed a little back
# (AdjustLodLandscapeVertexPositionCS) so the objects stand in front of it.

import engine

# a vertex of the distant land or objects (y up, in the cell's space)
pub type LodVertex:
	position Vec3
	normal Vec3
	uv Vec2
	color Vec4
	# the diffuse and normal map textures' indices in the program's list, the noise texture's
	# (-1 for none), 1 for land and 0 for an object
	maps Vec4

pub type LodPoint:
	world Vec3
	normal Vec3
	uv Vec2
	color Vec4
	maps Vec4

# the distance past which the land is pushed back, and by how much a unit of it
lodPushStart f32 = 70000.0
lodPushRate f32 = 0.0001

pub fn lodVertex(v LodVertex, p CellParams) (Vec4, LodPoint):
	c = p.projection @ p.view @ v.position.withW(1.0)
	push = (lodPushRate * (c.w - lodPushStart).max(0.0)).min(1.0) * 0.5 * v.maps.w
	(
		Vec4(c.x, c.y, c.z + push, c.w),
		LodPoint(world = v.position, normal = v.normal, uv = v.uv, color = v.color, maps = v.maps)
	)

fn blendParameter(color Vec3) f32:
	t = (1.6666666 * (color @ Vec3(0.55, 0.55, 0.55) - 0.4)).clamp(0.0, 1.0)
	t * t * (3.0 - 2.0 * t) * 0.8

fn blendMultiplier(parameter f32, mask f32) f32:
	0.8333333 * (parameter * (0.37 - mask) + mask) + 0.37

pub fn lodPixel(b LodPoint, p CellParams) Vec4:
	if p.debugId > 0.5:
		return Vec4(0.0, 0.0, 0.0, 1.0)
	texel = p.textures[engine.tileSlot(b.maps.x)].sample(b.uv)
	map = p.textures[engine.tileSlot(b.maps.y)].sample(b.uv)
	base = texel.rgb
	n = b.normal.normalized()
	if b.maps.w > 0.5:
		noise = p.textures[engine.tileSlot(b.maps.z)].sample(b.uv * 3.0).x
		base = base * blendMultiplier(blendParameter(base), noise)
		# the map keeps the game's model-space normal as (x, z, y) of the z-up space
		n = Vec3(map.x - 0.5, map.y - 0.5, 0.5 - map.z).normalized()
	if p.normalPass > 0.5:
		return (p.view @ n.withW(0.0)).xyz.withW(1.0)
	shaded(base, b.color.rgb, n, b.world, b.uv, 0.0, terrainLook, Vec4(1.0, 1.0, 1.0, 1.0), p)
		.withW(1.0)

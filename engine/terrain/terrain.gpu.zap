# The pixel stage's part of terrain: what a vertex stage passes on, and the tiles blended by their
# weights as the landscape permutation of Skyrim's Lighting.hlsl does (the weights divided by their
# sum, a tile under 0.01 left out, the diffuse and the normal map each the weighted sum).

# a vertex of a patch as the program's vertex stage takes it; the tiles' indices ride as floats
# (whole numbers) and are read back rounded
pub type TerrainVertex:
	position Vec3
	normal Vec3
	tangent Vec3
	color Vec4
	uv Vec2
	weights Vec4   # tiles 0 to 3
	weights2 Vec4   # tiles 4 and 5 in x and y
	diffuse Vec4   # the tiles' diffuse textures: 0 to 3
	diffuse2 Vec4   # 4 and 5 in x and y
	normalMaps Vec4
	normalMaps2 Vec4

# what a terrain vertex stage passes on to the pixel stage
pub type TerrainPoint:
	world Vec3
	normal Vec3
	tangent Vec3
	color Vec4
	uv Vec2
	weights Vec4
	weights2 Vec4
	diffuse Vec4
	diffuse2 Vec4
	normalMaps Vec4
	normalMaps2 Vec4

# each tile's share of a pixel (tiles 0 to 3, then 4 and 5)
pub type TerrainShares:
	first Vec4
	second Vec2

pub fn terrainPoint(v TerrainVertex) TerrainPoint:
	TerrainPoint(
		world = v.position,
		normal = v.normal,
		tangent = v.tangent,
		color = v.color,
		uv = v.uv,
		weights = v.weights,
		weights2 = v.weights2,
		diffuse = v.diffuse,
		diffuse2 = v.diffuse2,
		normalMaps = v.normalMaps,
		normalMaps2 = v.normalMaps2
	)

fn tileShare(w f32, total f32) f32:
	share = w / total
	share if share > 0.01 else 0.0

# The tiles' shares of a pixel as the landscape shader weighs them: each weight over their sum,
# one under 0.01 left out. A shader samples each tile's textures (the array is read where it is
# declared) and adds them up times these.
pub fn tileShares(b TerrainPoint) TerrainShares:
	total = b.weights.x + b.weights.y + b.weights.z + b.weights.w + b.weights2.x + b.weights2.y
	t = total.max(0.000001)
	TerrainShares(
		first = Vec4(
			tileShare(b.weights.x, t),
			tileShare(b.weights.y, t),
			tileShare(b.weights.z, t),
			tileShare(b.weights.w, t)
		),
		second = Vec2(tileShare(b.weights2.x, t), tileShare(b.weights2.y, t))
	)

# the texture list index a vertex carries as a float
pub fn tileSlot(index f32) i32:
	i32(index + 0.5)

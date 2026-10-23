# A mesh's corner, unpacked from its word (world/meshing.zap's vertexWord), and moved by the
# wind and the waves: what the world's and the shadow's vertex stages share.

# a corner as the mesh holds it: one word, its CornerParts' toBits (world/meshing.zap's vertexWord)
pub type CornerWord:
	word u32

pub type Across = i32 in 0..=16   # x or z in the chunk, its far side included
pub type Up = i32 in 0..=64
pub type FaceKind = i32 in 0..=6   # the six faces, a plant
pub type Quarter = i32 in 0..=3   # a material, how open a corner is (0 shut in .. 3 open)
pub type TextureLayer = i32 in 0..=31

# what a corner's word holds, packed by toBits: 31 bits, x lowest
pub type CornerParts:
	x Across
	y Up
	z Across
	u bool
	v bool
	face FaceKind
	material Quarter
	open Quarter
	layer TextureLayer

materialLeaves i32 = 1
materialWater i32 = 2
materialLine i32 = 3
plantFace i32 = 6   # a plant's crossed quads

# the faces' normals: +x -x +y -y +z -z, a plant (lit as the ground under it)
normals Vec3[7] = [
	Vec3(1, 0, 0),
	Vec3(-1, 0, 0),
	Vec3(0, 1, 0),
	Vec3(0, -1, 0),
	Vec3(0, 0, 1),
	Vec3(0, 0, -1),
	Vec3(0, 1, 0)
]

# the light of a corner by how open it is (0 shut in by three blocks .. 3 open)
openLight f32[4] = [0.45, 0.65, 0.82, 1.0]

pub type Corner:
	position Vec3   # in the world
	uvLayer Vec3
	face i32
	material i32
	light f32

# the corner of the word w, of the chunk whose corner is at `origin`, `time` seconds in
fn unpack(w u32, origin Vec3, time f32) Corner:
	k = CornerParts.fromBits(w)
	c = Corner(
		position = origin + Vec3(f32(k.x), f32(k.y), f32(k.z)),
		uvLayer = Vec3(1.0 if k.u else 0.0, 1.0 if k.v else 0.0, f32(k.layer)),
		face = k.face,
		material = k.material,
		light = openLight[k.open])
	# leaves sway in the wind, a plant from its roots (its top corners, v 0); water's surface
	# waves, a little below the block's top (its top corners: the top face's, and a side's v 0)
	if c.material == materialLeaves:
		p = c.position
		reach = (1.0 - c.uvLayer.y) * 0.16 if c.face == plantFace else 0.035
		gust = 0.6 + 0.4 * (time * 0.7 + p.x * 0.05 + p.z * 0.03).sin()
		c.position.x += (time * 1.7 + p.y * 0.9 + p.z * 0.6).sin() * reach * gust
		c.position.z += (time * 1.3 + p.x * 0.7 + p.y * 0.4).cos() * reach * gust
	if c.material == materialWater and (c.face == 2 or c.uvLayer.y < 0.5):
		p = c.position
		c.position.y += ((time * 1.6 + p.x * 0.8).sin() + (time * 1.2 + p.z * 0.9).cos()) * 0.04 -
			0.14
	c

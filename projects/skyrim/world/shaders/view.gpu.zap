# Where a depth buffer's surface lies, shared by the passes that read one (occlusion, TAA).

import engine

# the game's axes (z up) as the engine's (y up), and back
pub fn inEngine(v Vec3) Vec3:
	Vec3(v.x, v.z, -v.y)

pub fn inGame(v Vec3) Vec3:
	Vec3(v.x, -v.z, v.y)

# the view-space point (looking down -z) of the surface `depth` holds at uv; `unproject` is the
# projection's 1 / m[0], 1 / m[5], m[10] and m[14]. A target's first row is the clip space's y = -1
# (rhi/vulkan/commands.zap), so uv's y grows upward.
pub fn viewAtDepth(depth engine.Texture, unproject Vec4, uv Vec2) Vec3:
	d = depth.sampleLevel(uv, 0.0).r * 2.0 - 1.0
	z = -unproject.w / (d + unproject.z)
	Vec3((uv.x * 2.0 - 1.0) * -z * unproject.x, (uv.y * 2.0 - 1.0) * -z * unproject.y, z)

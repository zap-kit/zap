# std/math in a pixel stage: a projection and a view made, the frustum's planes and a box tested
# against them, a vector turned, the turn between two directions and a product of turns, each the
# same Zap the CPU runs, compiled for the GPU.

import math

pub type Camera:
	turn Quat
	aspect f32
	lo Vec3
	hi Vec3

pub fn pixel(uv Vec2, c Camera) Vec4:
	projection = Mat4.perspective(1.0, c.aspect, 0.1, 100.0)
	view = Mat4.lookAlong(Vec3(0.0, 0.0, 5.0), Vec3(uv.x, uv.y, -1.0))
	planes = (projection @ view).frustumPlanes()
	seen = 1.0 if math.isBoxInFrustum(planes, c.lo, c.hi) else 0.0
	turned = c.turn.rotate(Vec3(uv.x, uv.y, 1.0))
	both = c.turn @ Quat.between(Vec3(0.0, 0.0, 1.0), turned)
	Vec4(both.x, both.y, turned.z, seen)

# A pixel stage that reads a compute stage's value, and a compute stage that gives a result: what
# the shader tests expect refused.

pub type Counts:
	counts i32[]

pub fn pixel(uv Vec2) Vec4:
	Vec4(uv.x, uv.y, f32(globalId.x), 1.0)

pub fn counted(p Counts) i32:
	p.counts[0]

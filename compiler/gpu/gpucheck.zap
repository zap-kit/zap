# A GPU function (flagGpu: a function of a `.gpu.zap` file) is checked as any other, in the
# GPU's terms: a number literal no place types is an i32 or an f32 (the GPU has no 64-bit
# numbers), and a stage may read what only a GPU has: the textures' reads (t.sample(uv),
# t.sampleLevel(uv, lod), t.size(), a shadow map's s.compare(uv, depth); an array's take the
# layer after uv), the derivatives of a float or a vector across the pixels (ddx, ddy, fwidth),
# discard(), the values the GPU gives (gpuValues), a compute stage's barrier() and the operations
# across the lanes that run together (x.laneSum(), b.laneAny()...). The CPU's code never calls a
# GPU function.

import shader

alias nodes = c.nodes
alias tys = c.types

fn gpuDerivative(m str):
	m in ["ddx", "ddy", "fwidth"]

# a value the GPU gives a stage's code, by its name: its type (the language's), and the stage
# that has it (shader.stageFragment, shader.stageCompute)
type GpuValue:
	name str
	typeName str
	stage i64

# the pixel's window place, depth and 1 / w (a pixel stage's); a compute stage's invocation's
# place in the whole dispatch, in its group and its group's, its index in its group, its lane
# among those that run together and their count
gpuValues = [
	GpuValue("pixelPosition", "Vec4", shader.stageFragment),
	GpuValue("globalId", "IVec3", shader.stageCompute),
	GpuValue("localId", "IVec3", shader.stageCompute),
	GpuValue("groupId", "IVec3", shader.stageCompute),
	GpuValue("localIndex", "i32", shader.stageCompute),
	GpuValue("lane", "i32", shader.stageCompute),
	GpuValue("laneCount", "i32", shader.stageCompute)
]

# the type of the value the GPU gives that `name` names, none for any other name
fn gpuValueType(mut c Checker, name str) TypeId?:
	v = try gpuValues.find(.name == name)
	tyInt(32, true) if v.typeName == "i32" else c.languageType(v.typeName)

# How many arguments a method across the lanes that run together takes (-1: not one): their
# sum, least, greatest, the first lane's value, lane i's (laneAt(i)), the sum of the lanes
# before this one (lanePrefixSum), and a bool's laneAny and laneAll.
fn gpuLaneArity(m str):
	if m in ["laneSum", "laneMin", "laneMax", "laneFirst", "lanePrefixSum"] or m in laneBoolMethods:
		return 0
	1 if m == "laneAt" else -1

# a bool's methods across the lanes: whether it holds in any (every) lane that runs with this one
laneBoolMethods = ["laneAny", "laneAll"]

# one of the engine's textures as a stage reads it: Texture, TextureArray, ShadowMap
fn gpuTexture(c Checker, t TypeId):
	shader.samplerKinds.any(.zap == nodes[declOf(tys, t)].text2)

# the language's type of that name (Vec4, IVec2...)
fn languageType(mut c Checker, name str) TypeId:
	tyOfDecl(tys, nodes, c.findDeclInModule("rt", nStructDecl, name) ?? fail("rt has no {name}"))

# a texture's read: a color (Vec4), a shadow map's comparison (the fraction lit, f32), or its
# size at a level (IVec2, IVec3 for an array's layers too)
fn checkTextureMethod(mut c Checker, e NodeId, t TypeId, move m str) TypeId:
	kind = nodes[declOf(tys, t)].text2.copy()
	array = kind == "TextureArray"
	n = c.argCount(e)
	f32 = tyFloat(32)
	wanted TypeId[] = []
	if m == "sample" and kind != "ShadowMap":
		wanted = [c.languageType("Vec2"), f32] if array else [c.languageType("Vec2")]
	elif m == "sampleLevel" and kind != "ShadowMap":
		wanted = [c.languageType("Vec2"), f32, f32] if array else [c.languageType("Vec2"), f32]
	elif m == "compare" and kind == "ShadowMap":
		wanted = [c.languageType("Vec2"), f32]
	elif m == "size" and n <= 1:
		wanted = [tyInt(32, true)] if n == 1 else []
	else:
		c.errorAt(nodes[e].line, nodes[e].col, compileError("TextureRead", ["{kind}"]))
		return tyError
	if not c.expectArgs(e, m, wanted.len): return tyError
	for i in 0..wanted.len:
		a = c.argAt(e, i)
		at = c.derefIfRef(a, c.checkExpr(a, wanted[i]))
		if not isAssignable(tys, at, wanted[i]):
			errorAt(
				c,
				nodes[a].line,
				nodes[a].col,
				compileError("GpuArgumentType", ["{m}", "{c.showTy(wanted[i])}", "{c.showTy(at)}"])
			)
	if m == "compare": return f32
	if m == "size": return c.languageType("IVec3" if array else "IVec2")
	c.languageType("Vec4")

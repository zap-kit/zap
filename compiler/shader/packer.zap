# The CPU's side of a parameter struct: Zap source the compiler adds to the struct's module, so
# the program sets a stage's parameters from a value of the same struct the shader declares,
# laid out by the same computation (lower.zap's partOf), the two sides agreeing by
# construction:
#   pub fn gpuName() str                  the part's name in the program's reflection
#   pub fn gpuWrite(mut words u32[], at i64, mut textures i64[], textureAt i64,
#       mut buffers u8[,], bufferAt i64, mut arrays i64[,], arrayAt i64)
# gpuWrite writes the struct's numbers into the block's words from `at` (straight stores: the
# RHI compares the block with what it holds),
# each texture's id (its `id` field: the engine's Texture, TextureArray, ShadowMap) at its
# binding, each storage buffer's elements as their bytes, each texture array's ids. On the CPU
# a Vec2..Vec4 has fields x y z w, a matrix `m` of its columns' numbers; a
# bool is 1 or 0, an enum the number of its variant.

# the module's helpers, written once beside its packers
pub packerHelpers = """
	fn zapGpuBool(b bool) u32:
		1 if b else 0
	"""

type Writer:
	lines str[]
	loops i64   # loop variables made so far (zapI0, zapI1...)

fn writeLine(mut w Writer, indent i64, text str):
	w.lines.push("\t".repeat(indent) + text)

# the source of the packer of part `part`, the methods of its struct (declared in u; params its
# numbers, where partOf put them)
pub fn packerSource(u Unit, part Part, params Param[], gpuName str) str ? GpuError:
	w = Writer(lines = [], loops = 0)
	w.writeLine(0, "pub fn gpuName() str:")
	w.writeLine(1, "\"{gpuName}\"")
	w.writeLine(0, "pub fn gpuWrite(mut zapWords u32[], zapAt i64, mut zapTextures i64[], zapTextureAt i64, mut zapBuffers u8[,], zapBufferAt i64, mut zapArrays i64[,], zapArrayAt i64):")
	members = try u.unitMembers()
	bodyAt = w.lines.len
	number = 0
	texture = 0
	buffer = 0
	array = 0
	for f in u.fieldsOf(part.name):
		path = "self.{f.name}"
		if isTextureType(f.tname):
			if f.arr >= 0:
				w.writeLine(1, "zapArrays[zapArrayAt + {array}].clear()")
				w.writeLine(1, "for zapTexture in {path}:")
				w.writeLine(2, "zapArrays[zapArrayAt + {array}].push(zapTexture.id)")
				array += 1
			else:
				w.writeLine(1, "zapTextures[zapTextureAt + {texture}] = {path}.id")
				texture += 1
			continue
		if f.arr == 0:
			w.writeBuffer(path, buffer)
			buffer += 1
			continue
		offset = params[number].offset - part.offset
		number += 1
		u.writeValue(members, w, 1, path, f, "zapAt + {offset / 4}")
	if w.lines.len == bodyAt:
		w.writeLine(1, "pass")
	"{w.lines.join("\n")}\n"

# the words of a value of the block (std140) written from the word `at` (an expression)
fn writeValue(u Unit, members Ty[,], mut w Writer, indent i64, path str, f Field, at str):
	if f.arr >= 0:
		stride = u.unitTy(f.tname, f.arr).strideOf(true, members) / 4
		i = "zapI{w.loops}"
		w.loops += 1
		w.writeLine(indent, "for {i} in 0..{f.arr}:")
		element = Field(
			name = f.name.copy(),
			tname = f.tname.copy(),
			zname = f.zname.copy(),
			arr = -1,
			pos = f.pos
		)
		u.writeValue(members, w, indent + 1, "{path}[{i}]", element, "{at} + {i} * {stride}")
		return
	if f.tname in u.structs:
		fields = u.fieldsOf(f.tname)
		offsets = offsetsOf(fields.map(u.unitTy(.tname, .arr)), true, members)
		for i in 0..fields.len:
			writeValue(
				u,
				members,
				w,
				indent,
				"{path}.{fields[i].name}",
				fields[i],
				"{at} + {offsets[i] / 4}"
			)
		return
	if f.zname in u.enums:
		e = "zapE{w.loops}"
		w.loops += 1
		w.writeLine(indent, "{e} u32 = match {path}:")
		for top in u.tops:
			if u.nodes[top].kind == kEnum and u.nodes[top].text == f.zname:
				kids = u.nodes[top].kids
				for v in 0..kids.len:
					w.writeLine(indent + 1, "{u.nodes[kids[v]].text}: {v}")
		w.writeLine(indent, "zapWords[{at}] = {e}")
		return
	t = u.unitTy("uint" if f.tname == "bool" else f.tname.copy(), -1)
	if f.tname == "bool":
		w.writeLine(indent, "zapWords[{at}] = zapGpuBool({path})")
		return
	for (word, part) in t.wordsOf(path):
		w.writeLine(indent, "zapWords[{at} + {word}] = {part}")

# each word of a number, vector or matrix (as the CPU's struct holds it) and its place: a
# vector's components in order, a matrix's columns 16 bytes apart (std140, std430 alike)
fn wordsOf(t Ty, path str):
	out = []
	if t.cols > 1:
		for c in 0..t.cols:
			for r in 0..t.rows:
				out.push((c * 4 + r, bitsOf(bFloat, "{path}.m[{c * t.rows + r}]")))
		return out
	if t.rows > 1:
		return (0..t.rows).map((it, bitsOf(t.base, "{path}.{swizzleSets[0][it..it + 1]}")))
	out.push((0, bitsOf(t.base, path)))
	out

# a number as the u32 of its bits
fn bitsOf(base i64, v str):
	if base == bFloat: return "{v}.toBits()"
	if base == bInt: return "u32({v})"
	v.copy()

# a storage buffer's elements as their bytes, into the room of the last ones: a record of
# scalars, Vec2s and Vec4s in that order (lower.zap checks it) is laid out alike by std430,
# Direct3D and the CPU
fn writeBuffer(mut w Writer, path str, k i64):
	w.writeLine(1, "{path}.copyBytesTo(zapBuffers[zapBufferAt + {k}])")

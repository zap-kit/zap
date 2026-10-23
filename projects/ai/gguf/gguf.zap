# GGUF, the file llama.cpp's models come in: a header of metadata (each key a value: a number, a
# bool, a text, or a list of those) and of tensors (each its name, its shape, how its numbers are
# stored, where they are), then the tensors' data. A module of the standard library:
#
#   g = gguf.open("model.gguf") ?? fail("{error}")
#   heads = g.int("llama.attention.head_count") ?? 32
#   w = g.tensor("blk.0.attn_q.weight") ?? fail("{error}")   # a tensor.Tensor on the GPU
#
# A file is data, not trusted: every count and offset the header gives is checked against the
# file before it is read.

import fs
import tensor

# a metadata value
pub type Value:
	Number(n f64)
	Flag(b bool)
	Text(s str)
	Numbers(ns f64[])
	Texts(ss str[])

# a tensor of the file: its name, its shape (row-major: GGUF's dimensions last first), its
# numbers' kind (ggml's type) and where its data starts after the header
pub type TensorInfo:
	name str
	shape i64[]
	kind i64
	offset i64

pub type File:
	file fs.File
	values {str: Value}
	tensors TensorInfo[]
	dataStart i64
	size i64

	# a number of the metadata, none when it has none of that key
	pub fn number(key str) f64?:
		if values.get(key) is Number(n): return n
		none

	# an integer of the metadata
	pub fn int(key str) i64?:
		if values.get(key) is Number(n): return i64(n)
		none

	pub fn text(key str) str?:
		if values.get(key) is Text(s): return s.copy()
		none

	pub fn texts(key str) str[]?:
		if values.get(key) is Texts(ss): return ss.copy()
		none

	pub fn numbers(key str) f64[]?:
		if values.get(key) is Numbers(ns): return ns.copy()
		none

	# the tensor named `name` read onto the GPU, kept as it is stored (f32, f16, bf16, Q8 or Q4; asF32
	# expands a stored one to f32 there)
	pub fn tensor(name str, asF32 bool = false) tensor.Tensor ? str:
		t = tensors.find(.name == name) ?? return "no tensor {name}"
		count = tensor.shapeCount(t.shape)
		n = bytesOf(t.kind, count) ??
			return "tensor {name} is stored as ggml's type {t.kind}, which this module does not read"
		raw = file.readAt(dataStart + t.offset, n) ?? return "tensor {name} cannot be read"
		if t.kind == kindF32:
			numbers = fill(count, f32(0))
			for i in 0..count:
				numbers[i] = raw.f32le(4 * i)
			return tensor.fromList(t.shape, numbers).gpu()
		if t.kind == kindF16 or t.kind == kindBF16:
			numbers = (0..count).map(
				halfValue(raw.u16le(2 * it)) if t.kind == kindF16
				else tensor.bfloatValue(raw.u16le(2 * it))
			)
			stored = tensor.Format.F16 if t.kind == kindF16 else tensor.Format.BF16
			return tensor.fromList(t.shape, numbers).gpu(.F32 if asF32 else stored)
		# blocks: a scale (an f16), then the integers' bytes
		per = 32 if t.kind == kindQ8 else 16
		blocks = count / 32
		scales f32[] = []
		scales.reserve(blocks)
		bytes u8[] = []
		bytes.reserve(blocks * per)
		for k in 0..blocks:
			at = k * (per + 2)
			scales.push(halfValue(raw.u16le(at)))
			bytes.extend(raw[at + 2..at + 2 + per])
		format = tensor.Format.Q8 if t.kind == kindQ8 else tensor.Format.Q4
		stored = tensor.quantizedFrom(t.shape, format, scales, bytes)
		if asF32: return stored.toCpu().gpu()
		stored

	# rows first..first + n of a matrix tensor (a table of embeddings) as f32s, read from the file
	# alone, row after row
	pub fn rows(name str, first i64, n i64) f32[] ? str:
		t = tensors.find(.name == name) ?? return "no tensor {name}"
		if t.shape.len != 2 or first < 0 or n < 0 or first + n > t.shape[0]:
			return "rows {first}..{first + n} of tensor {name}"
		width = t.shape[1]
		perRow = bytesOf(t.kind, width) ??
			return "tensor {name} is stored as ggml's type {t.kind}, which this module does not read"
		raw = file.readAt(dataStart + t.offset + first * perRow, n * perRow) ??
			return "tensor {name} cannot be read"
		out f32[] = []
		out.reserve(n * width)
		if t.kind == kindF32:
			for i in 0..n * width:
				out.push(raw.f32le(4 * i))
		elif t.kind == kindF16 or t.kind == kindBF16:
			for i in 0..n * width:
				h = u32(raw.u16le(2 * i))
				out.push(halfValue(h) if t.kind == kindF16 else tensor.bfloatValue(h))
		else:
			per = 32 if t.kind == kindQ8 else 16
			for k in 0..n * width / 32:
				at = k * (per + 2)
				d = halfValue(raw.u16le(at))
				for j in 0..32:
					if t.kind == kindQ8:
						q = i64(raw[at + 2 + j])
						out.push(f32(q - 256 if q >= 128 else q) * d)
					else:
						q = i64(raw[at + 2 + j % 16])
						out.push(f32((q & 15 if j < 16 else q >> 4) - 8) * d)
		out

# ggml's types this module reads, and the bytes of a block of each and the numbers it holds
pub kindF32 = 0
pub kindF16 = 1
pub kindQ4 = 2
pub kindQ8 = 8
pub kindBF16 = 30

# the bytes of `count` numbers stored as kind, none for a kind this module does not read
pub fn bytesOf(kind i64, count i64) i64?:
	if kind == kindF32: return count * 4
	if kind == kindF16 or kind == kindBF16: return count * 2
	if kind == kindQ8: return count / 32 * 34
	if kind == kindQ4: return count / 32 * 18
	none

# the header of a GGUF file read and checked, the file kept open for its tensors
pub fn open(path str) File ? str:
	file = fs.open(path) ?? return "no {path}"
	size = file.len
	head = file.readAt(0, size.min(64 << 20)) ?? return "{path} cannot be read"
	if head.len < 24 or head[..4] != "GGUF".bytes(): return "{path} is not a GGUF file"
	r = Header(bytes = head, at = 4)
	version = r.u32()
	if version < 2 or version > 3: return "{path} is GGUF version {version}, not 2 or 3"
	tensorCount = r.u64()
	valueCount = r.u64()
	if tensorCount < 0 or tensorCount > 1_000_000 or valueCount < 0 or valueCount > 1_000_000:
		return "{path}'s counts are damaged"
	values {str: Value} = {}
	loop valueCount:
		key = r.text() ?? return "{path}'s header is damaged"
		kind = r.u32()
		value = try r.value(kind)
		values[key] = value
	tensors = []
	loop tensorCount:
		name = r.text() ?? return "{path}'s header is damaged"
		dims = r.u32()
		if dims < 0 or dims > 8: return "{path}: tensor {name} has {dims} dimensions"
		shape i64[] = []
		loop dims:
			shape.insert(0, r.u64())
		kind = r.u32()
		offset = r.u64()
		tensors.push(TensorInfo(name, shape, kind, offset))
	if r.short: return "{path}'s header is damaged or past 64 MB"
	align = 32
	if values.get("general.alignment") is Number(n):
		align = i64(n).max(1)
	start = r.at.alignUp(align)
	for t in tensors:
		bytes = bytesOf(t.kind, tensor.shapeCount(t.shape)) ?? 0
		if t.offset < 0 or start + t.offset + bytes > size:
			return "{path}: tensor {t.name}'s data is past the file's end"
	File(file, values, tensors, dataStart = start, size)

# a header being read: its bytes and the place reached; short once a read went past the end
type Header:
	bytes u8[]
	at i64
	short bool = false

fn room(mut r Header, n i64):
	if n < 0 or r.at + n > r.bytes.len:
		r.short = true
		return false
	true

fn u32(mut r Header):
	if not r.room(4): return 0
	v = i64(r.bytes.u32le(r.at))
	r.at += 4
	v

fn u64(mut r Header):
	if not r.room(8): return 0
	v = i64.wrap(r.bytes.u64le(r.at))
	r.at += 8
	v

fn text(mut r Header) str?:
	n = r.u64()
	if not r.room(n): return none
	s = str(r.bytes[r.at..r.at + n])
	r.at += n
	s

# a value of GGUF's type `kind` (an array's elements each one)
fn value(mut r Header, kind i64) Value ? str:
	if kind == 9:
		inner = r.u32()
		n = r.u64()
		if n < 0 or n > r.bytes.len: return "an array of {n} elements"
		if inner == 8:
			texts = []
			loop n:
				texts.push(r.text() ?? return "a text past the header's end")
			return Value.Texts(texts)
		numbers = []
		loop n:
			v = try r.value(inner)
			if v is Number(x):
				numbers.push(x)
			elif v is Flag(b):
				numbers.push(1.0 if b else 0.0)
			else:
				return "an array of arrays"
		return Value.Numbers(numbers)
	if kind == 8: return Value.Text(r.text() ?? return "a text past the header's end")
	if kind == 7:
		if not r.room(1): return "a bool past the header's end"
		r.at += 1
		return Value.Flag(r.bytes[r.at - 1] != 0)
	sizes = [1, 1, 2, 2, 4, 4, 4, 0, 0, 0, 8, 8, 8]
	if kind < 0 or kind >= sizes.len or sizes[kind] == 0: return "a value of type {kind}"
	n = sizes[kind]
	if not r.room(n): return "a number past the header's end"
	b = r.bytes
	at = r.at
	r.at += n
	if kind == 6: return Value.Number(f64(b.f32le(at)))
	if kind == 12: return Value.Number(b.f64le(at))
	if kind == 0: return Value.Number(f64(b[at]))
	if kind == 1: return Value.Number(f64(i64(b[at]) - (256 if b[at] >= 128 else 0)))
	if kind == 2: return Value.Number(f64(b.u16le(at)))
	if kind == 3: return Value.Number(f64(b.i16le(at)))
	if kind == 4: return Value.Number(f64(b.u32le(at)))
	if kind == 5: return Value.Number(f64(b.i32le(at)))
	if kind == 10: return Value.Number(f64(b.u64le(at)))
	Value.Number(f64(b.i64le(at)))

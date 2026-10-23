# ActionScript 2's bytecode decoded (SWF file format specification v19, chapter 5 "Actions", the
# SWF 4 to 7 ones): a block of actions, each a code and, from 0x80 on, a length and its data, until
# an End (0) or the block's end. Jumps, If, With, Try and a function's body name their ends in
# bytes; they are kept as the index of the action there, so the interpreter (machine.zap) walks a
# list. A target that is not an action's start ends the block, as Ruffle (core/src/avm1) does.

import engine.swf

# a value Push puts on the stack, as the file writes it
pub type PushItem:
	Text(s str)
	Number(x f64)
	Null
	Undefined
	Register(r i64)
	Boolean(b bool)
	Constant(k i64)   # an entry of the constant pool

# DefineFunction (0x9B) or DefineFunction2 (0x8E): its body is the actions body .. end
pub type FunctionDef:
	name str
	params str[]
	paramRegisters i64[]   # DefineFunction2: each parameter's register, 0 for none
	registers i64   # DefineFunction2's register count; 4 for DefineFunction, the global ones
	flags i64   # DefineFunction2's preload and suppress bits (preloadThis 1 .. preloadGlobal 0x100)
	two bool
	body i64
	end i64

# Try (0x8F): the try block runs from the action after it to tryEnd, the catch to catchEnd, the
# finally to finallyEnd
pub type TryDef:
	catchName str
	catchRegister i64   # -1: the error goes into the variable catchName
	hasCatch bool
	hasFinally bool
	tryEnd i64
	catchEnd i64
	finallyEnd i64

pub type Action:
	Op(code i64)   # an action without data
	GotoFrame(frame i64)
	GetUrl(url str, target str)
	StoreRegister(r i64)
	ConstantPool(items str[])
	WaitForFrame(frame i64, skip i64)
	SetTarget(name str)
	GotoLabel(label str)
	WaitForFrame2(skip i64)
	Function(def FunctionDef)
	Try(def TryDef)
	With(end i64)
	Push(items PushItem[])
	Jump(to i64)
	GetUrl2(flags i64)
	If(to i64)
	Call
	GotoFrame2(play bool, bias i64)
	Unknown(code i64, length i64)

# a decoded block of actions
pub type Block:
	actions Action[]

# the place and size of one action in the bytes
type Span:
	code i64
	start i64   # its data's first byte
	end i64

# the block in the bytes: the actions up to an End or the end
pub fn decodeBlock(bytes u8[]) Block:
	spans = []
	starts = []
	at = 0
	while at < bytes.len:
		code = i64(bytes[at])
		if code == 0: break
		length = 0
		if code >= 0x80:
			if at + 3 > bytes.len: break
			length = bytes.u16le(at + 1)
		start = at + (3 if code >= 0x80 else 1)
		if start + length > bytes.len: break
		starts.push(at)
		spans.push(Span(code, start, end = start + length))
		at = start + length
	block = Block(actions = [])
	for k, s in spans:
		r = swf.newReader(bytes, s.start, s.end)
		block.actions.push(r.decodeAction(s.code, s.end - s.start, starts, at))
	block

# the index of the action starting at the byte `offset`; the actions' count at the block's end
# and for a place inside an action
fn indexAt(starts i64[], offset i64, end i64):
	if offset >= end: return starts.len
	lo = 0
	hi = starts.len
	while lo < hi:
		mid = (lo + hi) / 2
		if starts[mid] < offset: lo = mid + 1
		else: hi = mid
	lo if lo < starts.len and starts[lo] == offset else starts.len

# long: one arm per action with data
fn decodeAction(mut r swf.TagReader, code i64, length i64, starts i64[], end i64) Action:
	next = r.end
	match code:
		0x81: .GotoFrame(r.u16())
		0x83:
			url = r.text()
			.GetUrl(url, r.text())
		0x87: .StoreRegister(r.u8())
		0x88:
			items = []
			loop r.u16():
				items.push(r.text())
			.ConstantPool(items)
		0x8A:
			frame = r.u16()
			.WaitForFrame(frame, r.u8())
		0x8B: .SetTarget(r.text())
		0x8C: .GotoLabel(r.text())
		0x8D: .WaitForFrame2(r.u8())
		0x8E, 0x9B: .Function(r.readFunction(code == 0x8E, starts, end))
		0x8F: .Try(r.readTry(starts, end))
		0x94: .With(indexAt(starts, next + r.u16(), end))
		0x96: .Push(r.readPush())
		0x99: .Jump(indexAt(starts, next + r.i16(), end))
		0x9A: .GetUrl2(r.u8())
		0x9D: .If(indexAt(starts, next + r.i16(), end))
		0x9E: .Call
		0x9F:
			flags = r.u8()
			.GotoFrame2((flags & 1) != 0, r.u16() if (flags & 2) != 0 else 0)
		_: .Op(code) if code < 0x80 else .Unknown(code, length)

fn readFunction(mut r swf.TagReader, two bool, starts i64[], end i64):
	name = r.text()
	count = r.u16()
	def = FunctionDef(name, params = [], paramRegisters = [], registers = 4, flags = 0, two,
		body = 0, end = 0)
	if two:
		def.registers = r.u8()
		def.flags = r.u16()
	loop count:
		if two: def.paramRegisters.push(r.u8())
		def.params.push(r.text())
	size = r.u16()
	def.body = indexAt(starts, r.end, end)
	def.end = indexAt(starts, r.end + size, end)
	def

fn readTry(mut r swf.TagReader, starts i64[], end i64):
	flags = r.u8()
	trySize = r.u16()
	catchSize = r.u16()
	finallySize = r.u16()
	inRegister = (flags & 4) != 0
	t = TryDef(catchName = "", catchRegister = -1, hasCatch = (flags & 1) != 0,
		hasFinally = (flags & 2) != 0, tryEnd = 0, catchEnd = 0, finallyEnd = 0)
	if inRegister: t.catchRegister = r.u8()
	else: t.catchName = r.text()
	t.tryEnd = indexAt(starts, r.end + trySize, end)
	t.catchEnd = indexAt(starts, r.end + trySize + catchSize, end)
	t.finallyEnd = indexAt(starts, r.end + trySize + catchSize + finallySize, end)
	t

# a double as SWF writes one: its high 32 bits first, each half little-endian
fn swappedDouble(mut r swf.TagReader):
	high = r.u32()
	low = r.u32()
	b = []
	b.pushU32le(low)
	b.pushU32le(high)
	b.f64le(0)

fn readPush(mut r swf.TagReader):
	items PushItem[] = []
	while r.remaining() > 0 and not r.short:
		kind = r.u8()
		match kind:
			0: items.push(.Text(r.text()))
			1: items.push(.Number(f64(r.float())))
			2: items.push(.Null)
			3: items.push(.Undefined)
			4: items.push(.Register(r.u8()))
			5: items.push(.Boolean(r.u8() != 0))
			6: items.push(.Number(r.swappedDouble()))
			7: items.push(.Number(f64(i32.wrap(r.u32()))))
			8: items.push(.Constant(r.u8()))
			9: items.push(.Constant(r.u16()))
			_: break
	items

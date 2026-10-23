# The decoder: one instruction's bytes into its parts (Intel SDM vol. 2, chapter 2): the legacy
# prefixes, REX, the opcode in its map, ModRM, SIB, the displacement and the immediate, the
# operand form from the table (ops.zap). VEX-encoded instructions (C4, C5) are recognised and
# refused: SkyrimSE.exe's math is SSE only. A byte sequence the table does not know is an error
# that names its address and bytes.

pub type Instr:
	at u64
	len i64 = 0
	map i64 = 0
	opcode i64 = 0
	pfx i64 = 0   # the mandatory prefix: 0 none, 1 66, 2 F3, 3 F2
	opsize i64 = 4   # the integer operand size in bytes
	rex i64 = 0   # the REX byte, 0 for none
	rep i64 = 0   # F3 or F2 before a string instruction
	seg i64 = 0   # 0x64 (fs) or 0x65 (gs) before a memory operand
	hasModrm bool = false
	mod i64 = 0
	reg i64 = 0   # ModRM reg, REX.R added
	rm i64 = 0   # ModRM rm, REX.B added (a register when mod is 3)
	mem bool = false
	base i64 = -1   # -1 none, 16 rip
	index i64 = -1
	scale i64 = 1
	disp i64 = 0
	imm i64 = 0
	form i64 = 0   # the form's key in the table (ops.zap)
	sse bool = false   # an XMM register is an operand

	fn rexW():
		rex & 8 != 0

# the operands' immediate bytes
fn immBytes(code str, opsize i64):
	match code:
		"Ib", "Jb": 1
		"Iw": 2
		"Iz", "Jz": 2 if opsize == 2 else 4
		"Iv": opsize
		_: 0

fn hasModrmIn(operands str[]):
	operands.any(it.startsWith("E") or it.startsWith("G") or it.startsWith("M") or it.startsWith("V") or
		.startsWith("W") or .startsWith("U"))

# the opcodes whose operand size is 64 bits without REX.W (pushes, pops, near branches)
fn defaultsTo64(map i64, opcode i64, reg i64):
	if map != 0: return false
	match opcode:
		0x50..=0x5F, 0x68, 0x6A, 0x8F, 0xC2, 0xC3, 0xC9, 0xE8, 0xE9, 0xEB: true
		0xFF: reg in [2, 4, 6]
		_: false

fn signed(v u64, bytes i64) i64:
	if bytes == 8: return i64(v)
	shift = 64 - 8 * bytes
	i64(v << u64(shift)) >> shift

pub fn bytesText(code u8[]) str:
	code.map("{it:02x}").join(" ")

# The instruction at `at`, its bytes `code` (15, as many as an instruction may have).
pub fn decode(at u64, code u8[]) Instr ? str:
	d = Instr(at)
	try d.decodeInto(code)
	d

# d (its address set) decoded from its bytes
pub fn decodeInto(mut d Instr, code u8[]) ? str:
	at = d.at
	p = 0
	has66 = false
	loop:
		b = code[p]
		match b:
			0x66: has66 = true
			0xF2, 0xF3: d.rep = b
			0x64, 0x65: d.seg = b
			0x2E, 0x3E, 0x26, 0x36, 0xF0: pass
			0x67: return "0x{at:x}: 32-bit addressing is not emulated ({bytesText(code[..p + 1])})"
			_: break
		p += 1
	if code[p] >= 0x40 and code[p] <= 0x4F:
		d.rex = code[p]
		p += 1
	if code[p] == 0xC4 or code[p] == 0xC5:
		return "0x{at:x}: a VEX instruction, not emulated ({bytesText(code[..p + 4])})"
	if code[p] == 0x0F:
		p += 1
		d.map = 1
		if code[p] == 0x38 or code[p] == 0x3A:
			d.map = 2 if code[p] == 0x38 else 3
			p += 1
	d.opcode = code[p]
	p += 1
	d.pfx = 1 if has66 else 0
	if d.rep == 0xF3: d.pfx = 2
	if d.rep == 0xF2: d.pfx = 3
	d.form = formKey(d.map, d.pfx, d.opcode) ?? return unknown(at, code, p)
	f = forms[d.form].copy()
	d.sse = f.usesXmm()
	if not d.sse and d.map > 0 and d.pfx == 1: d.pfx = 0
	d.opsize = 8 if d.rexW() else 2 if has66 else 4
	if hasModrmIn(f.operands):
		p = d.modrm(code, p)
	if defaultsTo64(d.map, d.opcode, d.reg & 7): d.opsize = 2 if has66 else 8
	if f.nameIn(d.reg) == "?": return unknown(at, code, p)
	for o in f.operands:
		n = immBytes(o, d.opsize)
		# test, the only member of its group with an immediate
		if d.map == 0 and (d.opcode == 0xF6 or d.opcode == 0xF7) and (d.reg & 7) < 2 and
			o.startsWith("E"):
			n = 1 if d.opcode == 0xF6 else immBytes("Iz", d.opsize)
		if n > 0:
			v = 0
			for k in 0..n:
				v |= u64(code[p + k]) << u64(8 * k)
			d.imm = signed(v, n)
			if o == "Iw": d.imm = i64(v)
			p += n
	d.len = p

fn unknown(at u64, code u8[], p i64):
	"0x{at:x}: unknown instruction {bytesText(code[..(p + 2).min(code.len)])}"

# ModRM, SIB and the displacement from p: the position after them
fn modrm(mut d Instr, code u8[], start i64):
	p = start
	m = i64(code[p])
	p += 1
	d.hasModrm = true
	d.mod = m >> 6
	d.reg = (m >> 3 & 7) | (d.rex & 4) << 1
	low = m & 7
	d.rm = low | (d.rex & 1) << 3
	if d.mod == 3: return p
	d.mem = true
	if low == 4:
		sib = i64(code[p])
		p += 1
		d.scale = 1 << (sib >> 6)
		index = (sib >> 3 & 7) | (d.rex & 2) << 2
		d.index = -1 if index == 4 else index
		baseLow = sib & 7
		d.base = baseLow | (d.rex & 1) << 3
		if baseLow == 5 and d.mod == 0:
			d.base = -1
			d.disp = signed(code.u32le(p), 4)
			return p + 4
	elif low == 5 and d.mod == 0:
		d.base = 16
		d.disp = signed(code.u32le(p), 4)
		return p + 4
	else:
		d.base = d.rm
	if d.mod == 1:
		d.disp = signed(code[p], 1)
		p += 1
	if d.mod == 2:
		d.disp = signed(code.u32le(p), 4)
		p += 4
	p

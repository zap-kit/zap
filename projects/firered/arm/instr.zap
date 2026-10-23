# The common form both tables lower to: an ARM or Thumb instruction as what it does, with the
# address it sits at. Its text is the canonical assembly (`text()`), which `assemble` reads back.

# the operations of data processing, in the order of ARM's opcode field
pub aluNames = [
	"and",
	"eor",
	"sub",
	"rsb",
	"add",
	"adc",
	"sbc",
	"rsc",
	"tst",
	"teq",
	"cmp",
	"cmn",
	"orr",
	"mov",
	"bic",
	"mvn"
]
pub aluTst = 8
pub aluCmp = 10
pub aluCmn = 11
pub aluMov = 13
pub aluMvn = 15

# the conditions, in the order of the condition field; 14 is always
pub condNames = [
	"eq",
	"ne",
	"cs",
	"cc",
	"mi",
	"pl",
	"vs",
	"vc",
	"hi",
	"ls",
	"ge",
	"lt",
	"gt",
	"le",
	"",
	"nv"
]
pub always = 14

pub shiftNames = ["lsl", "lsr", "asr", "ror", "rrx"]
pub shiftRrx = 4

pub sp = 13
pub lr = 14
pub pc = 15

# the second operand of data processing, and the offset of a load or a store
pub type Operand:
	Imm(v u32, rot i64)   # rot: the rotation its encoding gave, 0 for none
	Reg(m i64, shift i64, amount i64)   # shiftNames; rrx has no amount, lsl 0 is none
	RegShift(m i64, shift i64, s i64)   # shifted by the low byte of register s

pub type Op:
	Alu(kind i64, sets bool, d i64, n i64, b Operand)
	Mul(sets bool, d i64, m i64, s i64, acc i64)   # d = m * s (+ acc unless acc is -1)
	MulLong(signed bool, adds bool, sets bool, lo i64, hi i64, m i64, s i64)
	Load(size i64, signed bool, d i64, n i64, offset Operand, pre bool, up bool, back bool)
	Store(size i64, d i64, n i64, offset Operand, pre bool, up bool, back bool)
	Block(load bool, n i64, list i64, pre bool, up bool, back bool, user bool)
	Swap(byte bool, d i64, m i64, n i64)
	Branch(target i64, link bool)
	Exchange(m i64)
	Software(n i64)
	ReadPsr(d i64, saved bool)
	WritePsr(saved bool, mask i64, b Operand)   # mask: the fields c x s f as bits 0 to 3
	Undefined

pub type Instr:
	at i64
	size i64
	thumb bool
	cond i64
	op Op

	# what reading the program counter gives this instruction
	pub fn pcValue() i64:
		at + (4 if thumb else 8)

	# the address after it
	pub fn next() i64:
		at + size

	# the canonical assembly of the instruction
	pub fn text() str:
		c = condNames[cond]
		match op:
			Alu(kind, sets, d, n, b):
				name = aluNames[kind]
				s = "s" if sets and (kind < aluTst or kind > aluCmn) else ""
				if kind >= aluTst and kind <= aluCmn:
					return "{name}{c} {regName(n)}, {b.operandText()}"
				if kind == aluMov or kind == aluMvn:
					return "{name}{s}{c} {regName(d)}, {b.operandText()}"
				"{name}{s}{c} {regName(d)}, {regName(n)}, {b.operandText()}"
			Mul(sets, d, m, s, acc):
				flag = "s" if sets else ""
				if acc < 0: return "mul{flag}{c} {regName(d)}, {regName(m)}, {regName(s)}"
				"mla{flag}{c} {regName(d)}, {regName(m)}, {regName(s)}, {regName(acc)}"
			MulLong(signed, adds, sets, lo, hi, m, s):
				name = "{"s" if signed else "u"}{"mlal" if adds else "mull"}{"s" if sets else ""}"
				"{name}{c} {regName(lo)}, {regName(hi)}, {regName(m)}, {regName(s)}"
			Load(width, signed, d, n, offset, pre, up, back):
				"ldr{sizeName(width, signed)}{c} {regName(d)}, {addressText(n, offset, pre, up, back)}"
			Store(width, d, n, offset, pre, up, back):
				"str{sizeName(width, false)}{c} {regName(d)}, {addressText(n, offset, pre, up, back)}"
			Block(load, n, list, pre, up, back, user):
				mode = "{"i" if up else "d"}{"b" if pre else "a"}"
				"{"ldm" if load else "stm"}{mode}{c} {regName(n)}{"!" if back else ""}, \{{listText(list)}}{"^" if user else ""}"
			Swap(
				byte,
				d,
				m,
				n
			): "swp{"b" if byte else ""}{c} {regName(d)}, {regName(m)}, [{regName(n)}]"
			Branch(target, link): "b{"l" if link else ""}{c} 0x{target:08X}"
			Exchange(m): "bx{c} {regName(m)}"
			Software(n): "swi{c} #0x{n:X}"
			ReadPsr(d, saved): "mrs{c} {regName(d)}, {"spsr" if saved else "cpsr"}"
			WritePsr(saved, mask, b):
				"msr{c} {"spsr" if saved else "cpsr"}_{psrMaskText(mask)}, {b.operandText()}"
			Undefined: "undefined"

pub fn regName(r i64) str:
	match r:
		13: "sp"
		14: "lr"
		15: "pc"
		_: "r{r}"

# "r0, r4-r7, lr"
pub fn listText(list i64) str:
	parts = []
	r = 0
	while r < 16:
		if (list >> r) & 1 == 0:
			r += 1
			continue
		last = r
		while last < 15 and (list >> (last + 1)) & 1 == 1 and last + 1 < 13:
			last += 1
		parts.push(regName(r) if last == r else "{regName(r)}-{regName(last)}")
		r = last + 1
	parts.join(", ")

fn immText(v u32):
	"#{v}" if v < 10 else "#0x{v:X}"

fn operandText(b Operand):
	match b:
		Imm(v, rot):
			if (rot == 0) == (v <= 255): return immText(v)
			"#{v.rotateLeft(rot)}, {rot}"
		Reg(m, shift, amount):
			if shift == shiftRrx: return "{regName(m)}, rrx"
			if shift == 0 and amount == 0: return regName(m)
			"{regName(m)}, {shiftNames[shift]} #{amount}"
		RegShift(m, shift, s): "{regName(m)}, {shiftNames[shift]} {regName(s)}"

fn offsetText(offset Operand, up bool):
	sign = "" if up else "-"
	match offset:
		Imm(v, _): "#{sign}{v}" if v < 10 else "#{sign}0x{v:X}"
		_: "{sign}{offset.operandText()}"

fn sizeName(size i64, signed bool):
	match size:
		1: "sb" if signed else "b"
		2: "sh" if signed else "h"
		_: ""

fn addressText(n i64, offset Operand, pre bool, up bool, back bool):
	zero = match offset:
		Imm(v, _): v == 0
		_: false
	if not pre: return "[{regName(n)}], {offset.offsetText(up)}"
	if zero and not back: return "[{regName(n)}]"
	"[{regName(n)}, {offset.offsetText(up)}]{"!" if back else ""}"

# the fields of a status register a mask names, "fsxc"
pub fn psrMaskText(mask i64) str:
	t = ""
	for i, letter in ["f", "s", "x", "c"]:
		if (mask >> (3 - i)) & 1 == 1: t += letter
	t

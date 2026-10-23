# Assembly text read into the common form: the decoder's templates filled in, and the programs
# the tests write. It reads the canonical text `text()` writes, and the forms a template gives
# (a shift of #0, an offset of #0).

type Base:
	Alu(kind i64)
	Multiply(adds bool)
	Long(signed bool, adds bool)
	Memory(load bool, size i64, signed bool)
	Multiple(load bool, up bool, pre bool)
	Swap(byte bool)
	Jump(link bool)
	Exchange
	Software
	ReadPsr
	WritePsr
	Undefined

type Mnemonic:
	name str
	base Base
	takesS bool

fn mnemonics():
	out = []
	for k, name in aluNames:
		out.push(Mnemonic(name = name.copy(), base = .Alu(k), takesS = k < aluTst or k > aluCmn))
	out.extend(
		[
			Mnemonic(name = "mul", base = .Multiply(false), takesS = true),
			Mnemonic(name = "mla", base = .Multiply(true), takesS = true),
			Mnemonic(name = "umull", base = .Long(false, false), takesS = true),
			Mnemonic(name = "umlal", base = .Long(false, true), takesS = true),
			Mnemonic(name = "smull", base = .Long(true, false), takesS = true),
			Mnemonic(name = "smlal", base = .Long(true, true), takesS = true),
			Mnemonic(name = "ldr", base = .Memory(true, 4, false), takesS = false),
			Mnemonic(name = "ldrb", base = .Memory(true, 1, false), takesS = false),
			Mnemonic(name = "ldrh", base = .Memory(true, 2, false), takesS = false),
			Mnemonic(name = "ldrsb", base = .Memory(true, 1, true), takesS = false),
			Mnemonic(name = "ldrsh", base = .Memory(true, 2, true), takesS = false),
			Mnemonic(name = "str", base = .Memory(false, 4, false), takesS = false),
			Mnemonic(name = "strb", base = .Memory(false, 1, false), takesS = false),
			Mnemonic(name = "strh", base = .Memory(false, 2, false), takesS = false),
			Mnemonic(name = "swp", base = .Swap(false), takesS = false),
			Mnemonic(name = "swpb", base = .Swap(true), takesS = false),
			Mnemonic(name = "b", base = .Jump(false), takesS = false),
			Mnemonic(name = "bl", base = .Jump(true), takesS = false),
			Mnemonic(name = "bx", base = .Exchange, takesS = false),
			Mnemonic(name = "swi", base = .Software, takesS = false),
			Mnemonic(name = "mrs", base = .ReadPsr, takesS = false),
			Mnemonic(name = "msr", base = .WritePsr, takesS = false),
			Mnemonic(name = "undefined", base = .Undefined, takesS = false)
		]
	)
	for load in [false, true]:
		for mode in ["da", "db", "ia", "ib"]:
			out.push(
				Mnemonic(
					name = "{"ldm" if load else "stm"}{mode}",
					base = .Multiple(load, mode[0] == 'i', mode[1] == 'b'),
					takesS = false
				)
			)
	out

# The text of one instruction read into the common form; a text that is none stops the program
# (the templates and the tests write them).
pub type Assembler:
	names Mnemonic[]

	pub fn assemble(text str, at i64, thumb bool, size i64) Instr:
		space = text.indexOf(" ") ?? text.len
		word = text[..space]
		k, sets, cond = self.mnemonicOf(word) ?? fail("no instruction '{word}' in '{text}'")
		Instr(
			at,
			size,
			thumb,
			cond,
			op = names[k].base.operation(sets, splitOperands(text[space..].trimmed()))
		)

	# the index of the mnemonic a word starts with, whether it sets the flags, its condition
	fn mnemonicOf(word str) (i64, bool, i64)?:
		for k, m in names:
			if not word.startsWith(m.name): continue
			sets = m.takesS and word[m.name.len..].startsWith("s")
			cond = condNames.indexOf(word[m.name.len + (1 if sets else 0)..]) ?? continue
			return (k, sets, cond)
		none

pub fn newAssembler() Assembler:
	Assembler(names = mnemonics().sortedBy(-.name.len))

# the operands split at the commas outside brackets and braces
fn splitOperands(s str):
	out = []
	depth = 0
	start = 0
	for i, c in s.bytes():
		if c == '[' or c == '{': depth += 1
		if c == ']' or c == '}': depth -= 1
		if c == ',' and depth == 0:
			out.push(s[start..i].trimmed().copy())
			start = i + 1
	if start < s.len: out.push(s[start..].trimmed().copy())
	out

fn reg(t str):
	match t:
		"sp": 13
		"lr": 14
		"pc": 15
		"r{n}":
			r = i64.parse(n) ?? fail("no register '{t}'")
			if r < 0 or r > 15: fail("no register '{t}'")
			r
		_: fail("no register '{t}'")

# a number in decimal or after 0x, with an optional minus
fn number(t str):
	negative = t.startsWith("-")
	digits = t[1..] if negative else t
	v = i64.parse(digits) ?? fail("no number '{t}'")
	-v if negative else v

fn immediate(t str):
	if not t.startsWith("#"): fail("no immediate '{t}'")
	number(t[1..])

fn operandAt(ops str[], k i64) ref str:
	if k >= ops.len: fail("too few operands")
	ops[k]

# a shift word: "lsl #3", "lsr r2", "rrx"
fn shifted(m i64, t str) Operand:
	if t == "rrx": return .Reg(m, shiftRrx, 0)
	space = t.indexOf(" ") ?? fail("no shift '{t}'")
	kind = shiftNames.indexOf(t[..space]) ?? fail("no shift '{t}'")
	amountText = t[space + 1..]
	if amountText.startsWith("#"):
		amount = immediate(amountText)
		if amount == 0 and kind == 0: return .Reg(m, 0, 0)
		return .Reg(m, kind, amount)
	.RegShift(m, kind, reg(amountText))

# the second operand from ops[k]: "#v", "#imm, rot", "rm", "rm, shift"
fn operand2(ops str[], k i64) Operand:
	first = operandAt(ops, k)
	if first.startsWith("#"):
		v = immediate(first)
		if k + 1 < ops.len:
			rot = number(ops[k + 1])
			return .Imm(u32.wrap(v).rotateRight(rot), rot)
		w = u32.wrap(v)
		return .Imm(w, 0 if w <= 255 else rotationOf(w))
	m = reg(first)
	if k + 1 < ops.len: return shifted(m, ops[k + 1])
	.Reg(m, 0, 0)

# the even rotation that brings v into 8 bits
fn rotationOf(v u32):
	for rot in 0..16:
		if v.rotateLeft(rot * 2) <= 255: return rot * 2
	0

fn operation(base Base, sets bool, ops str[]) Op:
	match base:
		Alu(kind):
			if kind >= aluTst and kind <= aluCmn:
				return .Alu(kind, true, 0, reg(operandAt(ops, 0)), operand2(ops, 1))
			if kind == aluMov or kind == aluMvn:
				return .Alu(kind, sets, reg(operandAt(ops, 0)), 0, operand2(ops, 1))
			.Alu(
				kind,
				sets,
				reg(operandAt(ops, 0)),
				reg(operandAt(ops, 1)),
				operand2(ops, 2)
			)
		Multiply(adds):
			d = reg(operandAt(ops, 0))
			m = reg(operandAt(ops, 1))
			s = reg(operandAt(ops, 2))
			.Mul(sets, d, m, s, reg(operandAt(ops, 3)) if adds else -1)
		Long(signed, adds):
			.MulLong(
				signed,
				adds,
				sets,
				reg(operandAt(ops, 0)),
				reg(operandAt(ops, 1)),
				reg(operandAt(ops, 2)),
				reg(operandAt(ops, 3))
			)
		Memory(load, size, signed): memoryOp(load, size, signed, ops)
		Multiple(load, up, pre): multipleOp(load, up, pre, ops)
		Swap(byte):
			n = operandAt(ops, 2)
			if not n.startsWith("[") or not n.endsWith("]"): fail("no address '{n}'")
			.Swap(
				byte,
				reg(operandAt(ops, 0)),
				reg(operandAt(ops, 1)),
				reg(n[1..len - 1])
			)
		Jump(link): .Branch(number(operandAt(ops, 0)), link)
		Exchange: .Exchange(reg(operandAt(ops, 0)))
		Software: .Software(immediate(operandAt(ops, 0)))
		ReadPsr:
			psr = operandAt(ops, 1)
			.ReadPsr(reg(operandAt(ops, 0)), psr == "spsr")
		WritePsr:
			target = operandAt(ops, 0)
			under = target.indexOf("_") ?? fail("no fields in '{target}'")
			mask = 0
			for c in target[under + 1..].bytes():
				mask |= 1 << (match c:
					'c': 0
					'x': 1
					's': 2
					_: 3
				)
			.WritePsr(target.startsWith("spsr"), mask, operand2(ops, 1))
		Undefined: .Undefined

# an offset: "#-4", "r2", "-r2", "r2, lsl #2"
fn offsetOf(parts str[]) (Operand, bool):
	if parts.isEmpty: return (.Imm(0, 0), true)
	first = parts[0]
	if first.startsWith("#"):
		v = immediate(first)
		return (.Imm(u32(v.abs()), 0), not first.startsWith("#-"))
	up = not first.startsWith("-")
	m = reg(first if up else first[1..])
	if parts.len > 1: return (shifted(m, parts[1]), up)
	(.Reg(m, 0, 0), up)

fn memoryOp(load bool, size i64, signed bool, ops str[]) Op:
	d = reg(operandAt(ops, 0))
	address = operandAt(ops, 1)
	if not address.startsWith("["): fail("no address '{address}'")
	back = address.endsWith("!")
	inside = address[1..len - (2 if back else 1)]
	pre = ops.len == 2
	parts = splitOperands(inside)
	n = reg(parts[0])
	offset, up = offsetOf(parts[1..] if pre else ops[2..])
	if load: return .Load(size, signed, d, n, offset, pre, up, back or not pre)
	.Store(size, d, n, offset, pre, up, back or not pre)

fn multipleOp(load bool, up bool, pre bool, ops str[]) Op:
	base = operandAt(ops, 0)
	back = base.endsWith("!")
	n = reg(base[..len - 1] if back else base)
	listed = operandAt(ops, 1)
	user = listed.endsWith("^")
	inner = listed[1..len - (2 if user else 1)]
	list = 0
	for part in splitOperands(inner):
		match part.indexOf("-"):
			dash:
				for r in reg(part[..dash])..=reg(part[dash + 1..]):
					list |= 1 << r
			none: list |= 1 << reg(part)
	.Block(load, n, list, pre, up, back, user)

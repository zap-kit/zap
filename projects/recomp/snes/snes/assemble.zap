# Assembly text read back into an instruction: the canonical text `Instr.text()` writes. The
# operand's shape names the mode (its hex digits the letter: two `d`, four `w`, six `l`); an
# immediate takes the one immediate mode its mnemonic has, a six-digit operand of a branch its
# offset, two banks a block move.

pub type Assembler:
	opcodes {str: i64}   # "name mode" to the opcode
	rows Row[]

	# the instruction the text writes at `at`; a text that is none stops the program
	pub fn assemble(text str, at i64) Instr:
		space = text.indexOf(" ") ?? text.len
		name = text[..space]
		operand = text[space + 1..] if space < text.len else ""
		shape, value, written = operandShape(operand)
		mode, opcode = self.modeOf(name, shape) ?? fail("no instruction '{text}'")
		v = value
		bytes = written
		if isRelative(mode):
			bytes = operandSize(mode, native16)
			v = (value - (at + 1 + bytes)) & ((1 << (8 * bytes)) - 1)
		widths = Widths(e = false, m = mode == "#m" and bytes == 1, x = mode == "#x" and bytes == 1)
		Instr(
			at,
			opcode,
			name = name.copy(),
			mode,
			value = v,
			size = 1 + bytes,
			widths
		)

	# the mode of the mnemonic an operand's shape is, and its opcode
	fn modeOf(name str, shape str) (str, i64)?:
		for mode in modesOf(shape):
			if self.opcodes.get("{name} {mode}") is opcode: return (mode, opcode)
		none

pub fn newAssembler(rows Row[]) Assembler:
	opcodes {str: i64} = {}
	for r in rows:
		opcodes["{r.name} {r.mode}"] = r.opcode
	Assembler(opcodes, rows = rows.copy())

# the modes an operand's shape may be
fn modesOf(shape str):
	match shape:
		"#": ["#m", "#x", "#8"]
		"l": ["l", "r", "rl"]
		"d,d": ["b,b"]
		"a": ["A"]
		_: [shape.copy()]

# an operand's shape (its hex runs as their letters, an immediate as `#`), its value and its
# bytes; a block move's banks are the source then the destination, its value the destination's
# byte first
fn operandShape(operand str):
	shape = ""
	values = []
	bytes = 0
	k = 0
	while k < operand.len:
		if operand[k] != '$':
			shape += operand[k..k + 1]
			k += 1
			continue
		start = k + 1
		k = start
		while k < operand.len and isHexDigit(operand[k]):
			k += 1
		digits = k - start
		values.push(i64.parse("0x{operand[start..k]}") ?? fail("bad operand '{operand}'"))
		bytes += digits / 2
		if not shape.endsWith("#"): shape += ["d", "w", "l"][digits / 2 - 1]
	if values.len == 2: return (shape, values[1] | (values[0] << 8), bytes)
	(shape, values.first ?? 0, bytes)

fn isHexDigit(c u8):
	(c >= '0' and c <= '9') or (c >= 'A' and c <= 'F')

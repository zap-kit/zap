# The one decoder of the table: a row is an opcode, its mnemonic and its addressing mode. A mode is written as its operand reads in assembly, a letter for the operand's bytes:
# `d` a direct-page offset (one byte), `w` a 16-bit address, `l` a 24-bit one; `#m` an immediate as
# wide as the accumulator, `#x` as the index registers, `#8` a byte; `r` and `rl` a branch's
# 8- and 16-bit offset (read as its target); `b,b` a block move's source and destination banks;
# `A` the accumulator and nothing for an implied operand.

pub type Row:
	opcode i64
	name str
	mode str

# the registers' widths an instruction is read and run in: the emulation mode, and the M and X
# flags (set: 8 bits)
pub type Widths:
	e bool
	m bool
	x bool

pub native16 = Widths(e = false, m = false, x = false)
pub powerOn = Widths(e = true, m = true, x = true)

# the rows of a table's text: a line each, the opcode in hex, the mnemonic, the mode (none for
# implied)
pub fn rowsOf(table str) Row[]:
	rows = []
	for line in table.lines():
		parts = line.words()
		if parts.len < 2: continue
		opcode = i64.parse("0x{parts[0]}") ?? fail("bad opcode in '{line}'")
		if opcode != rows.len: fail("the table's opcodes are out of order at '{line}'")
		mode = parts[2].copy() if parts.len == 3 else ""
		rows.push(Row(opcode, name = parts[1].copy(), mode))
	if rows.len != 256: fail("the table has {rows.len} opcodes, not 256")
	rows

# the bytes of a mode's operand in the widths
pub fn operandSize(mode str, w Widths) i64:
	match mode:
		"", "A": 0
		"#m": 1 if w.m else 2
		"#x": 1 if w.x else 2
		"w", "w,x", "w,y", "(w)", "(w,x)", "[w]", "rl", "b,b": 2
		"l", "l,x": 3
		_: 1

# whether the mode is a branch's offset
pub fn isRelative(mode str) bool:
	mode == "r" or mode == "rl"

pub fn isImmediate(mode str) bool:
	mode.startsWith("#")

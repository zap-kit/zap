# An instruction written as Intel's syntax writes it (`movss xmm0, dword ptr [rip + 0x1b2c]`), for
# the trace and the disassembly; the operands from the form's codes (ops.zap).

names64 = [
	"rax",
	"rcx",
	"rdx",
	"rbx",
	"rsp",
	"rbp",
	"rsi",
	"rdi",
	"r8",
	"r9",
	"r10",
	"r11",
	"r12",
	"r13",
	"r14",
	"r15"
]
names32 = [
	"eax",
	"ecx",
	"edx",
	"ebx",
	"esp",
	"ebp",
	"esi",
	"edi",
	"r8d",
	"r9d",
	"r10d",
	"r11d",
	"r12d",
	"r13d",
	"r14d",
	"r15d"
]
names16 = [
	"ax",
	"cx",
	"dx",
	"bx",
	"sp",
	"bp",
	"si",
	"di",
	"r8w",
	"r9w",
	"r10w",
	"r11w",
	"r12w",
	"r13w",
	"r14w",
	"r15w"
]
names8 = [
	"al",
	"cl",
	"dl",
	"bl",
	"spl",
	"bpl",
	"sil",
	"dil",
	"r8b",
	"r9b",
	"r10b",
	"r11b",
	"r12b",
	"r13b",
	"r14b",
	"r15b"
]
highNames8 = ["al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"]

# the name of general register r at a size, a byte register without REX being ah..bh from 4 on
pub fn regName(r i64, size i64, rex i64) str:
	match size:
		8: names64[r]
		4: names32[r]
		2: names16[r]
		_: names8[r] if rex != 0 else highNames8[r]

fn sizeName(bytes i64):
	match bytes:
		1: "byte"
		2: "word"
		4: "dword"
		8: "qword"
		_: "xmmword"

fn hex(v i64):
	if v < 0: return "-0x{(-v):x}"
	"0x{v:x}"

# a memory operand; one relative to rip by the address it reaches
fn memText(d Instr, bytes i64):
	seg = "fs:" if d.seg == 0x64 else "gs:" if d.seg == 0x65 else ""
	if d.base == 16:
		return "{sizeName(bytes)} ptr {seg}[0x{d.at + u64(d.len) + u64.wrap(d.disp):x}]"
	parts = []
	if d.base >= 0: parts.push(names64[d.base].copy())
	if d.index >= 0:
		parts.push("{names64[d.index]}*{d.scale}" if d.scale > 1 else names64[d.index].copy())
	inner = parts.join(" + ")
	if d.disp != 0 or parts.isEmpty:
		sign = "-" if d.disp < 0 else "+"
		inner = hex(d.disp) if parts.isEmpty else "{inner} {sign} 0x{d.disp.abs():x}"
	if bytes == 0: return "{seg}[{inner}]"
	"{sizeName(bytes)} ptr {seg}[{inner}]"

# the bytes of an operand code's size: b w d q, v the operand size, y 4 or 8 by REX.W, a W's count
pub fn codeBytes(d Instr, code str) i64:
	match code[1..]:
		"b": 1
		"w": 2
		"d": 4
		"q": 8
		"y": 8 if d.rexW() else 4
		"4": 4
		"8": 8
		"16": 16
		_: d.opsize

fn operandText(d Instr, code str):
	match code:
		"AL": "al"
		"CL": "cl"
		"1": "1"
		"rAX": regName(0, d.opsize, d.rex)
		"Ib", "Iw", "Iz", "Iv": hex(d.imm)
		"Jb", "Jz": "0x{u64(i64(d.at) + d.len + d.imm):x}"
		"V": "xmm{d.reg}"
		"U": "xmm{d.rm}"
		"M": d.memText(0)
		_:
			kind = code[..1]
			bytes = d.codeBytes(code)
			if kind == "Z": return regName((d.opcode & 7) | (d.rex & 1) << 3, bytes, d.rex)
			if kind == "G": return regName(d.reg, bytes, d.rex)
			if d.mem: return d.memText(bytes)
			if kind == "W": return "xmm{d.rm}"
			regName(d.rm, bytes, d.rex)

# the instruction as text
pub fn textOf(d Instr) str:
	f = forms[d.form].copy()
	name = f.nameIn(d.reg)
	ops = f.operands.map(d.operandText(it)).join(", ")
	if d.rep == 0xF3 and (name.startsWith("movs") or name.startsWith("stos")) and d.map == 0:
		name = "rep {name}"
	if ops.isEmpty: return name
	"{name} {ops}"

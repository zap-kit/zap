# An instruction as the assembler writes it, for listings and tests: offsets in hex.

conditionNames = [
	"t",
	"f",
	"hi",
	"ls",
	"cc",
	"cs",
	"ne",
	"eq",
	"vc",
	"vs",
	"pl",
	"mi",
	"ge",
	"lt",
	"gt",
	"le"
]

fn hex(v i64):
	"${v:x}" if v >= 0 else "-${-v:x}"

fn register(r i64):
	"d{r}" if r < 8 else "a{r - 8}"

fn sizeSuffix(size i64):
	match size:
		1: ".b"
		2: ".w"
		4: ".l"
		_: ""

# a MOVEM mask's registers, d0-d7 then a0-a7 from bit 0 (reversed for -(An))
fn listText(mask i64, isReversed bool):
	names = []
	for i in 0..16:
		bit = 15 - i if isReversed else i
		if mask >> bit & 1 != 0: names.push(register(i))
	names.join("/")

pub fn operandText(o Operand, isReversed bool = false) str:
	index = "{register(o.index)}{".l" if o.indexLong else ".w"}"
	match o.mode:
		None: ""
		D: "d{o.reg}"
		A: "a{o.reg}"
		Ind: "(a{o.reg})"
		PostInc: "(a{o.reg})+"
		PreDec: "-(a{o.reg})"
		Disp: "{hex(o.value)}(a{o.reg})"
		Index: "{hex(o.value)}(a{o.reg},{index})"
		AbsW: "{hex(o.value)}.w"
		AbsL: "{hex(o.value)}.l"
		PcDisp: "{hex(o.value)}(pc)"
		PcIndex: "{hex(o.value)}(pc,{index})"
		Imm: "#{hex(o.value)}"
		Ccr: "ccr"
		Sr: "sr"
		Usp: "usp"
		List: listText(o.value, isReversed)

# The instruction's text: its mnemonic, size and operands ("move.l d0,-(a7)").
pub fn text(i Inst) str:
	if i.row < 0: return "dc.w ${i.word:x}"
	row = rows[i.row]
	match i.kind:
		Aline, Fline: return "{row.name} ${i.word:x}"
		Bcc, Scc, Dbcc:
			name = "{row.name}{conditionNames[i.cond]}"
			if i.kind == .Scc: return "{name} {i.src.operandText()}"
			if i.kind == .Dbcc: return "{name} d{i.src.reg},${i.target:x}"
			return "{name} ${i.target:x}"
		Bra, Bsr: return "{row.name} ${i.target:x}"
		_: pass
	shown = i.size > 0 and row.size != "-" and i.kind != .Lea and i.kind != .Pea
	name = "{row.name}{sizeSuffix(i.size) if shown else ""}"
	isReversed = i.dst.mode == .PreDec
	a = i.src.operandText(isReversed)
	b = i.dst.operandText()
	if a == "": return name
	if b == "": return "{name} {a}"
	"{name} {a},{b}"

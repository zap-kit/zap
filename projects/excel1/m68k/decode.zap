# The decoder: one reading of table.zap for every word. It finds a word's row and reads its
# operands and their extension words into an Inst; disassembly writes an Inst back as text.

pub type Mode:
	None
	D   # Dn
	A   # An
	Ind   # (An)
	PostInc   # (An)+
	PreDec   # -(An)
	Disp   # d16(An)
	Index   # d8(An,Xn)
	AbsW
	AbsL
	PcDisp   # d16(PC): value is the code offset it names
	PcIndex   # d8(PC,Xn): value is the code offset before the index
	Imm
	Ccr
	Sr
	Usp
	List   # a MOVEM's register mask in value

pub type Operand:
	mode Mode = .None
	reg i64 = 0   # the register (0-7)
	value i64 = 0   # a displacement, an address, an immediate or a mask
	index i64 = 0   # an indexed mode's index register: 0-7 data, 8-15 address
	indexLong bool = false

pub type Inst:
	at i64   # the offset of its first word in the code
	length i64   # bytes, extension words included
	word i64   # the first word
	row i64   # its row in table.rows, -1 for a word no row decodes
	kind Kind
	size i64   # 1, 2 or 4 bytes, 0 for none
	src Operand
	dst Operand
	cond i64   # a Bcc's, Scc's or DBcc's condition (bits 11-8)
	target i64   # a branch's code offset, -1 for none

# reads the code's words from at, as a decoding goes
type Words:
	code ref u8[]
	at i64
	isShort bool   # a word past the code's end was asked for

	fn next():
		if at + 2 > code.len:
			isShort = true
			at += 2
			return 0
		w = i64(code.u16be(at))
		at += 2
		w

fn signed16(w i64):
	w - 0x1_0000 if w >= 0x8000 else w

fn signed8(b i64):
	b - 0x100 if b >= 0x80 else b

fn sizeOf(spec str, w i64):
	match spec:
		"b": 1
		"w": 2
		"l": 4
		"s": [1, 2, 4, 0][w >> 6 & 3]
		"m": [0, 1, 4, 2][w >> 12 & 3]
		"8": 4 if w & 0x100 != 0 else 2
		"6": 4 if w & 0x40 != 0 else 2
		_: -1

# the mode's place in a class mask, -1 for none
fn modeIndex(mode i64, reg i64):
	if mode < 7: return mode
	if reg <= 4: return 7 + reg
	-1

# the modes by their place in a class mask
modesByIndex Mode[] = [
	.D,
	.A,
	.Ind,
	.PostInc,
	.PreDec,
	.Disp,
	.Index,
	.AbsW,
	.AbsL,
	.PcDisp,
	.PcIndex,
	.Imm
]

# the operand of an effective address, its extension words read
fn effective(mut w Words, mode i64, reg i64, size i64):
	m = modesByIndex[modeIndex(mode, reg)]
	match m:
		Disp: Operand(mode = m, reg, value = signed16(w.next()))
		Index:
			ext = w.next()
			Operand(
				mode = m,
				reg,
				value = signed8(ext & 255),
				index = ext >> 12 & 15,
				indexLong = ext & 0x800 != 0
			)
		AbsW: Operand(mode = m, value = signed16(w.next()) & 0xFFFF_FFFF)
		AbsL: Operand(mode = m, value = w.next() << 16 | w.next())
		PcDisp:
			base = w.at
			Operand(mode = m, value = base + signed16(w.next()))
		PcIndex:
			base = w.at
			ext = w.next()
			Operand(
				mode = m,
				value = base + signed8(ext & 255),
				index = ext >> 12 & 15,
				indexLong = ext & 0x800 != 0
			)
		Imm: Operand(mode = m, value = w.immediate(size))
		_: Operand(mode = m, reg)

fn immediate(mut w Words, size i64):
	if size == 4: return w.next() << 16 | w.next()
	v = w.next()
	v & 255 if size == 1 else v

# whether the effective address of bits 5-0 (or of a move's 11-6) is one the class takes
fn isAllowed(classMask str, mode i64, reg i64, size i64):
	i = modeIndex(mode, reg)
	i >= 0 and classMask[i] == '1' and not (i == 1 and size == 1)

# The operand of a spec, reading its extension words.
fn operand(mut w Words, spec str, word i64, size i64, at i64) Operand:
	r9 = word >> 9 & 7
	r0 = word & 7
	match spec:
		"ea": w.effective(word >> 3 & 7, r0, size)
		"mv": w.effective(word >> 6 & 7, r9, size)
		"d9": Operand(mode = .D, reg = r9)
		"d0": Operand(mode = .D, reg = r0)
		"a9": Operand(mode = .A, reg = r9)
		"a0": Operand(mode = .A, reg = r0)
		"pd9": Operand(mode = .PreDec, reg = r9)
		"pd0": Operand(mode = .PreDec, reg = r0)
		"pi9": Operand(mode = .PostInc, reg = r9)
		"pi0": Operand(mode = .PostInc, reg = r0)
		"di0": Operand(mode = .Disp, reg = r0, value = signed16(w.next()))
		"#": Operand(mode = .Imm, value = w.immediate(size))
		"#b": Operand(mode = .Imm, value = w.next() & 255)
		"#w": Operand(mode = .Imm, value = w.next())
		"q9": Operand(mode = .Imm, value = 8 if r9 == 0 else r9)
		"q8": Operand(mode = .Imm, value = signed8(word & 255) & 0xFFFF_FFFF)
		"r9": Operand(mode = .D, reg = r9)
		"ccr": Operand(mode = .Ccr)
		"sr": Operand(mode = .Sr)
		"usp": Operand(mode = .Usp)
		"list": Operand(mode = .List, value = w.next())
		"v4": Operand(mode = .Imm, value = word & 15)
		"br":
			d = word & 255
			Operand(mode = .Imm, value = at + 2 + (signed16(w.next()) if d == 0 else signed8(d)))
		"dbr": Operand(mode = .Imm, value = at + 2 + signed16(w.next()))
		_: Operand()

# whether the row's fields are valid for the word: its size and its effective addresses
fn isValid(r Row, word i64):
	size = sizeOf(r.size, word)
	if size == 0: return false
	mask = classMask(r.modes)
	if (r.src == "ea" or r.dst == "ea") and
		not isAllowed(mask, word >> 3 & 7, word & 7, size): return false
	if r.dst == "mv" and not isAllowed(classMask("dalt"), word >> 6 & 7, word >> 9 & 7, size):
		return false
	true

# the row that decodes the word, -1 for none
pub fn rowOf(word i64) i64:
	for i, m in matchers:
		if m.mask & word == m.value and rows[i].isValid(word): return i
	-1

# The instruction at `at` in the code.
pub fn decode(code u8[], at i64) Inst:
	w = Words(code, at, isShort = false)
	word = w.next()
	r = rowOf(word)
	if r < 0 or w.isShort:
		return Inst(
			at,
			length = 2,
			word,
			row = -1,
			kind = .Illegal,
			size = 0,
			src = Operand(),
			dst = Operand(),
			cond = 0,
			target = -1
		)
	row = rows[r]
	size = sizeOf(row.size, word)
	# a MOVEM's mask comes before its effective address's words, whichever side it is on
	list = w.operand("list", word, size, at) if row.src == "list" or row.dst == "list"
		else Operand()
	src = list if row.src == "list" else w.operand(row.src, word, size, at)
	dst = list if row.dst == "list" else w.operand(row.dst, word, size, at)
	isBranch = row.src == "br" or row.dst == "dbr"
	inst = Inst(
		at,
		length = w.at - at,
		word,
		row = r,
		kind = row.kind,
		size = 0 if size < 0 else size,
		src,
		dst,
		cond = word >> 8 & 15,
		target = (dst.value if row.dst == "dbr" else src.value) if isBranch else -1
	)
	if w.isShort: return Inst(..inst, row = -1, kind = .Illegal)
	inst

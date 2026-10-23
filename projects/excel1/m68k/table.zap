# long: the 68000's instructions, one row each
#
# The 68000 described once, as data: each instruction's bits and what it does. A row's bits are
# 16 characters, '0' and '1' fixed, '.' a field's; the first row whose fixed bits match and whose
# fields are valid (its size, its effective addresses) decodes the word, so a narrower row comes
# before a wider one that shares its bits. What a row does is its kind, which lower.zap turns into
# the common form, its size and its two operands. A size is fixed ("b", "w", "l"), read from the
# word ("s" bits 7-6: 00 byte, 01 word, 10 long; "m" a move's bits 13-12: 01 byte, 11 word, 10
# long; "8" bit 8 and "6" bit 6: 0 word, 1 long) or none ("-"). An operand is
#   ea      the effective address of bits 5-0 (mode 5-3, register 2-0), of the row's mode class
#   mv      a move's destination, bits 11-6 (register 11-9, mode 8-6), data alterable
#   d9 d0   a data register of bits 11-9 or 2-0;  a9 a0 an address register
#   pd9 pd0 -(An) of bits 11-9 or 2-0;  pi9 pi0 (An)+
#   di0     d16(An) of bits 2-0 (MOVEP)
#   #       an immediate of the size;  #b a byte's (a bit's number);  #w a word's
#   q9      3 bits at 11-9, 0 for 8 (ADDQ, SUBQ, a shift's count);  q8 the signed byte of 7-0
#   r9      a shift's count in the data register of bits 11-9
#   ccr sr usp   those registers;  list   a MOVEM's register mask;  v4   a TRAP's vector
#   br      a branch's displacement (bits 7-0, a word after it when 0);  dbr  a word's
# and the mode classes say which effective addresses a row takes: all, data (no An), mem (no Dn
# or An), ctl (control: no register, no (An)+, -(An) or immediate), alt (alterable: no PC
# relative or immediate), dalt, malt, calt (alterable and data, memory or control), dni (data
# but no immediate), ctlpi (control or (An)+), caltpd (control alterable or -(An)).

pub type Kind:
	Move
	Movea
	Moveq
	Movem
	Movep
	Lea
	Pea
	Clr
	Neg
	Negx
	Not
	Tst
	Tas
	Ext
	Swap
	Exg
	Add
	Adda
	Addx
	Sub
	Suba
	Subx
	Cmp
	Cmpa
	Cmpm
	And
	Or
	Eor
	Mulu
	Muls
	Divu
	Divs
	Abcd
	Sbcd
	Nbcd
	Asl
	Asr
	Lsl
	Lsr
	Rol
	Ror
	Roxl
	Roxr
	Btst
	Bchg
	Bclr
	Bset
	Bra
	Bsr
	Bcc
	Dbcc
	Scc
	Jmp
	Jsr
	Rts
	Rte
	Rtr
	Link
	Unlk
	Trap
	Trapv
	Chk
	Nop
	Stop
	Reset
	Illegal
	Aline
	Fline

pub type Row:
	bits str
	name str
	kind Kind
	size str
	src str
	dst str
	modes str

pub rows = [
	Row("0000000000111100", "ori", .Or, "b", "#", "ccr", "-"),
	Row("0000000001111100", "ori", .Or, "w", "#", "sr", "-"),
	Row("00000000........", "ori", .Or, "s", "#", "ea", "dalt"),
	Row("0000001000111100", "andi", .And, "b", "#", "ccr", "-"),
	Row("0000001001111100", "andi", .And, "w", "#", "sr", "-"),
	Row("00000010........", "andi", .And, "s", "#", "ea", "dalt"),
	Row("00000100........", "subi", .Sub, "s", "#", "ea", "dalt"),
	Row("00000110........", "addi", .Add, "s", "#", "ea", "dalt"),
	Row("0000101000111100", "eori", .Eor, "b", "#", "ccr", "-"),
	Row("0000101001111100", "eori", .Eor, "w", "#", "sr", "-"),
	Row("00001010........", "eori", .Eor, "s", "#", "ea", "dalt"),
	Row("00001100........", "cmpi", .Cmp, "s", "#", "ea", "dalt"),
	Row("0000100000......", "btst", .Btst, "-", "#b", "ea", "dni"),
	Row("0000100001......", "bchg", .Bchg, "-", "#b", "ea", "dalt"),
	Row("0000100010......", "bclr", .Bclr, "-", "#b", "ea", "dalt"),
	Row("0000100011......", "bset", .Bset, "-", "#b", "ea", "dalt"),
	Row("0000...100001...", "movep", .Movep, "w", "di0", "d9", "-"),
	Row("0000...101001...", "movep", .Movep, "l", "di0", "d9", "-"),
	Row("0000...110001...", "movep", .Movep, "w", "d9", "di0", "-"),
	Row("0000...111001...", "movep", .Movep, "l", "d9", "di0", "-"),
	Row("0000...100......", "btst", .Btst, "-", "d9", "ea", "data"),
	Row("0000...101......", "bchg", .Bchg, "-", "d9", "ea", "dalt"),
	Row("0000...110......", "bclr", .Bclr, "-", "d9", "ea", "dalt"),
	Row("0000...111......", "bset", .Bset, "-", "d9", "ea", "dalt"),
	Row("00.....001......", "movea", .Movea, "m", "ea", "a9", "all"),
	Row("00..............", "move", .Move, "m", "ea", "mv", "all"),
	Row("0100000011......", "move", .Move, "w", "sr", "ea", "dalt"),
	Row("01000000........", "negx", .Negx, "s", "ea", "", "dalt"),
	Row("0100...110......", "chk", .Chk, "w", "ea", "d9", "data"),
	Row("0100...111......", "lea", .Lea, "l", "ea", "a9", "ctl"),
	Row("01000010........", "clr", .Clr, "s", "ea", "", "dalt"),
	Row("0100010011......", "move", .Move, "w", "ea", "ccr", "data"),
	Row("01000100........", "neg", .Neg, "s", "ea", "", "dalt"),
	Row("0100011011......", "move", .Move, "w", "ea", "sr", "data"),
	Row("01000110........", "not", .Not, "s", "ea", "", "dalt"),
	Row("0100100000......", "nbcd", .Nbcd, "b", "ea", "", "dalt"),
	Row("0100100001000...", "swap", .Swap, "w", "d0", "", "-"),
	Row("0100100001......", "pea", .Pea, "l", "ea", "", "ctl"),
	Row("0100100010000...", "ext", .Ext, "w", "d0", "", "-"),
	Row("0100100011000...", "ext", .Ext, "l", "d0", "", "-"),
	Row("010010001.......", "movem", .Movem, "6", "list", "ea", "caltpd"),
	Row("0100101011111100", "illegal", .Illegal, "-", "", "", "-"),
	Row("0100101011......", "tas", .Tas, "b", "ea", "", "dalt"),
	Row("01001010........", "tst", .Tst, "s", "ea", "", "dalt"),
	Row("010011001.......", "movem", .Movem, "6", "ea", "list", "ctlpi"),
	Row("010011100100....", "trap", .Trap, "-", "v4", "", "-"),
	Row("0100111001010...", "link", .Link, "w", "a0", "#w", "-"),
	Row("0100111001011...", "unlk", .Unlk, "l", "a0", "", "-"),
	Row("0100111001100...", "move", .Move, "l", "a0", "usp", "-"),
	Row("0100111001101...", "move", .Move, "l", "usp", "a0", "-"),
	Row("0100111001110000", "reset", .Reset, "-", "", "", "-"),
	Row("0100111001110001", "nop", .Nop, "-", "", "", "-"),
	Row("0100111001110010", "stop", .Stop, "-", "#w", "", "-"),
	Row("0100111001110011", "rte", .Rte, "-", "", "", "-"),
	Row("0100111001110101", "rts", .Rts, "-", "", "", "-"),
	Row("0100111001110110", "trapv", .Trapv, "-", "", "", "-"),
	Row("0100111001110111", "rtr", .Rtr, "-", "", "", "-"),
	Row("0100111010......", "jsr", .Jsr, "-", "ea", "", "ctl"),
	Row("0100111011......", "jmp", .Jmp, "-", "ea", "", "ctl"),
	Row("0101....11001...", "db", .Dbcc, "w", "d0", "dbr", "-"),
	Row("0101....11......", "s", .Scc, "b", "ea", "", "dalt"),
	Row("0101...0........", "addq", .Add, "s", "q9", "ea", "alt"),
	Row("0101...1........", "subq", .Sub, "s", "q9", "ea", "alt"),
	Row("01100000........", "bra", .Bra, "-", "br", "", "-"),
	Row("01100001........", "bsr", .Bsr, "-", "br", "", "-"),
	Row("0110............", "b", .Bcc, "-", "br", "", "-"),
	Row("0111...0........", "moveq", .Moveq, "l", "q8", "d9", "-"),
	Row("1000...011......", "divu", .Divu, "w", "ea", "d9", "data"),
	Row("1000...111......", "divs", .Divs, "w", "ea", "d9", "data"),
	Row("1000...100000...", "sbcd", .Sbcd, "b", "d0", "d9", "-"),
	Row("1000...100001...", "sbcd", .Sbcd, "b", "pd0", "pd9", "-"),
	Row("1000...0........", "or", .Or, "s", "ea", "d9", "data"),
	Row("1000...1........", "or", .Or, "s", "d9", "ea", "malt"),
	Row("1001...011......", "suba", .Suba, "w", "ea", "a9", "all"),
	Row("1001...111......", "suba", .Suba, "l", "ea", "a9", "all"),
	Row("1001...1..000...", "subx", .Subx, "s", "d0", "d9", "-"),
	Row("1001...1..001...", "subx", .Subx, "s", "pd0", "pd9", "-"),
	Row("1001...0........", "sub", .Sub, "s", "ea", "d9", "all"),
	Row("1001...1........", "sub", .Sub, "s", "d9", "ea", "malt"),
	Row("1010............", "aline", .Aline, "-", "", "", "-"),
	Row("1011...011......", "cmpa", .Cmpa, "w", "ea", "a9", "all"),
	Row("1011...111......", "cmpa", .Cmpa, "l", "ea", "a9", "all"),
	Row("1011...1..001...", "cmpm", .Cmpm, "s", "pi0", "pi9", "-"),
	Row("1011...0........", "cmp", .Cmp, "s", "ea", "d9", "all"),
	Row("1011...1........", "eor", .Eor, "s", "d9", "ea", "dalt"),
	Row("1100...011......", "mulu", .Mulu, "w", "ea", "d9", "data"),
	Row("1100...111......", "muls", .Muls, "w", "ea", "d9", "data"),
	Row("1100...100000...", "abcd", .Abcd, "b", "d0", "d9", "-"),
	Row("1100...100001...", "abcd", .Abcd, "b", "pd0", "pd9", "-"),
	Row("1100...101000...", "exg", .Exg, "l", "d9", "d0", "-"),
	Row("1100...101001...", "exg", .Exg, "l", "a9", "a0", "-"),
	Row("1100...110001...", "exg", .Exg, "l", "d9", "a0", "-"),
	Row("1100...0........", "and", .And, "s", "ea", "d9", "data"),
	Row("1100...1........", "and", .And, "s", "d9", "ea", "malt"),
	Row("1101...011......", "adda", .Adda, "w", "ea", "a9", "all"),
	Row("1101...111......", "adda", .Adda, "l", "ea", "a9", "all"),
	Row("1101...1..000...", "addx", .Addx, "s", "d0", "d9", "-"),
	Row("1101...1..001...", "addx", .Addx, "s", "pd0", "pd9", "-"),
	Row("1101...0........", "add", .Add, "s", "ea", "d9", "all"),
	Row("1101...1........", "add", .Add, "s", "d9", "ea", "malt"),
	Row("1110000011......", "asr", .Asr, "w", "ea", "", "malt"),
	Row("1110000111......", "asl", .Asl, "w", "ea", "", "malt"),
	Row("1110001011......", "lsr", .Lsr, "w", "ea", "", "malt"),
	Row("1110001111......", "lsl", .Lsl, "w", "ea", "", "malt"),
	Row("1110010011......", "roxr", .Roxr, "w", "ea", "", "malt"),
	Row("1110010111......", "roxl", .Roxl, "w", "ea", "", "malt"),
	Row("1110011011......", "ror", .Ror, "w", "ea", "", "malt"),
	Row("1110011111......", "rol", .Rol, "w", "ea", "", "malt"),
	Row("1110...0..000...", "asr", .Asr, "s", "q9", "d0", "-"),
	Row("1110...1..000...", "asl", .Asl, "s", "q9", "d0", "-"),
	Row("1110...0..001...", "lsr", .Lsr, "s", "q9", "d0", "-"),
	Row("1110...1..001...", "lsl", .Lsl, "s", "q9", "d0", "-"),
	Row("1110...0..010...", "roxr", .Roxr, "s", "q9", "d0", "-"),
	Row("1110...1..010...", "roxl", .Roxl, "s", "q9", "d0", "-"),
	Row("1110...0..011...", "ror", .Ror, "s", "q9", "d0", "-"),
	Row("1110...1..011...", "rol", .Rol, "s", "q9", "d0", "-"),
	Row("1110...0..100...", "asr", .Asr, "s", "r9", "d0", "-"),
	Row("1110...1..100...", "asl", .Asl, "s", "r9", "d0", "-"),
	Row("1110...0..101...", "lsr", .Lsr, "s", "r9", "d0", "-"),
	Row("1110...1..101...", "lsl", .Lsl, "s", "r9", "d0", "-"),
	Row("1110...0..110...", "roxr", .Roxr, "s", "r9", "d0", "-"),
	Row("1110...1..110...", "roxl", .Roxl, "s", "r9", "d0", "-"),
	Row("1110...0..111...", "ror", .Ror, "s", "r9", "d0", "-"),
	Row("1110...1..111...", "rol", .Rol, "s", "r9", "d0", "-"),
	Row("1111............", "fline", .Fline, "-", "", "", "-")
]

type Matcher:
	mask u16
	value u16

# each row's fixed bits, after the rows (a module's files are initialised in order)
matchers = rows.map(r:
	mask, value = fixedBits(r.bits)
	Matcher(mask, value)
)

# The effective-address modes, in the order of a class's mask: Dn, An, (An), (An)+, -(An),
# d16(An), d8(An,Xn), abs.W, abs.L, d16(PC), d8(PC,Xn), #imm.
pub fn classMask(name str) str:
	match name:
		"all": "111111111111"
		"data": "101111111111"
		"mem": "001111111111"
		"ctl": "001001111110"
		"alt": "111111111000"
		"dalt": "101111111000"
		"malt": "001111111000"
		"calt": "001001111000"
		"dni": "101111111110"
		"ctlpi": "001101111110"
		"caltpd": "001011111000"
		_: "000000000000"

# a row's fixed bits as a mask and the value they hold
pub fn fixedBits(bits str) (u16, u16):
	mask = 0
	value = 0
	for i in 0..16:
		c = bits[i]
		if c != '.':
			mask |= 1 << (15 - i)
			if c == '1': value |= 1 << (15 - i)
	(u16(mask), u16(value))

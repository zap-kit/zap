# long: the opcode table, one line an instruction form
# The instructions the decoder knows (Intel SDM vol. 2, appendix A's opcode maps): each form's map
# (0 one byte, 1 0F, 2 0F 38, 3 0F 3A), mandatory prefix (0 none, 1 66, 2 F3, 3 F2), opcode, name
# and operands in the appendix's notation, which tells the decoder whether a ModRM byte and an
# immediate follow and the text how to write the operands:
#   E/G a general register or memory / the ModRM reg; M memory only; V/W an XMM register / an XMM
#   register or memory; U an XMM register in ModRM rm; Z the register in the opcode's low bits;
#   b w d q byte..quadword, v the operand size (16, 32, 64), y 32 or 64 by REX.W, z 16 or 32;
#   W4 W8 W16 the bytes of memory read; Ib Iw Iz Iv immediates, Jb Jz relative targets;
#   AL rAX CL 1 fixed operands.
# A name with `|` is a group: ModRM reg picks the name, `?` none (an unknown instruction).

pub type OpForm:
	name str
	operands str[]

fn addForm(mut out {i64: OpForm}, map i64, pfx i64, opcode i64, name str, operands str):
	out[map << 16 | pfx << 8 | opcode] = OpForm(
		name = name.copy(),
		operands = operands.split(",").filter(not .isEmpty)
	)

aluNames = "add|or|adc|sbb|and|sub|xor|cmp"
shiftNames = "rol|ror|rcl|rcr|shl|shr|sal|sar"

fn oneByte(mut out {i64: OpForm}):
	names = aluNames.split("|")
	for k in 0..8:
		out.addForm(0, 0, k * 8, names[k], "Eb,Gb")
		out.addForm(0, 0, k * 8 + 1, names[k], "Ev,Gv")
		out.addForm(0, 0, k * 8 + 2, names[k], "Gb,Eb")
		out.addForm(0, 0, k * 8 + 3, names[k], "Gv,Ev")
		out.addForm(0, 0, k * 8 + 4, names[k], "AL,Ib")
		out.addForm(0, 0, k * 8 + 5, names[k], "rAX,Iz")
		out.addForm(0, 0, 0x50 + k, "push", "Zv")
		out.addForm(0, 0, 0x58 + k, "pop", "Zv")
		out.addForm(0, 0, 0xB0 + k, "mov", "Zb,Ib")
		out.addForm(0, 0, 0xB8 + k, "mov", "Zv,Iv")
		if k > 0: out.addForm(0, 0, 0x90 + k, "xchg", "Zv,rAX")
		out.addForm(1, 0, 0xC8 + k, "bswap", "Zv")
	conditions = [
		"o",
		"no",
		"b",
		"ae",
		"e",
		"ne",
		"be",
		"a",
		"s",
		"ns",
		"p",
		"np",
		"l",
		"ge",
		"le",
		"g"
	]
	for c in 0..16:
		out.addForm(0, 0, 0x70 + c, "j{conditions[c]}", "Jb")
		out.addForm(1, 0, 0x80 + c, "j{conditions[c]}", "Jz")
		out.addForm(1, 0, 0x40 + c, "cmov{conditions[c]}", "Gv,Ev")
		out.addForm(1, 0, 0x90 + c, "set{conditions[c]}", "Eb")

fn fixedForms(mut out {i64: OpForm}):
	out.addForm(0, 0, 0x63, "movsxd", "Gv,Ed")
	out.addForm(0, 0, 0x68, "push", "Iz")
	out.addForm(0, 0, 0x69, "imul", "Gv,Ev,Iz")
	out.addForm(0, 0, 0x6A, "push", "Ib")
	out.addForm(0, 0, 0x6B, "imul", "Gv,Ev,Ib")
	out.addForm(0, 0, 0x80, aluNames, "Eb,Ib")
	out.addForm(0, 0, 0x81, aluNames, "Ev,Iz")
	out.addForm(0, 0, 0x83, aluNames, "Ev,Ib")
	out.addForm(0, 0, 0x84, "test", "Eb,Gb")
	out.addForm(0, 0, 0x85, "test", "Ev,Gv")
	out.addForm(0, 0, 0x86, "xchg", "Eb,Gb")
	out.addForm(0, 0, 0x87, "xchg", "Ev,Gv")
	out.addForm(0, 0, 0x88, "mov", "Eb,Gb")
	out.addForm(0, 0, 0x89, "mov", "Ev,Gv")
	out.addForm(0, 0, 0x8A, "mov", "Gb,Eb")
	out.addForm(0, 0, 0x8B, "mov", "Gv,Ev")
	out.addForm(0, 0, 0x8D, "lea", "Gv,M")
	out.addForm(0, 0, 0x8F, "pop|?|?|?|?|?|?|?", "Ev")
	out.addForm(0, 0, 0x90, "nop", "")
	out.addForm(0, 0, 0x98, "cwde", "")
	out.addForm(0, 0, 0x99, "cdq", "")
	out.addForm(0, 0, 0xA4, "movsb", "")
	out.addForm(0, 0, 0xA5, "movs", "")
	out.addForm(0, 0, 0xA8, "test", "AL,Ib")
	out.addForm(0, 0, 0xA9, "test", "rAX,Iz")
	out.addForm(0, 0, 0xAA, "stosb", "")
	out.addForm(0, 0, 0xAB, "stos", "")
	out.addForm(0, 0, 0xC0, shiftNames, "Eb,Ib")
	out.addForm(0, 0, 0xC1, shiftNames, "Ev,Ib")
	out.addForm(0, 0, 0xC2, "ret", "Iw")
	out.addForm(0, 0, 0xC3, "ret", "")
	out.addForm(0, 0, 0xC6, "mov|?|?|?|?|?|?|?", "Eb,Ib")
	out.addForm(0, 0, 0xC7, "mov|?|?|?|?|?|?|?", "Ev,Iz")
	out.addForm(0, 0, 0xC9, "leave", "")
	out.addForm(0, 0, 0xCC, "int3", "")
	out.addForm(0, 0, 0xD0, shiftNames, "Eb,1")
	out.addForm(0, 0, 0xD1, shiftNames, "Ev,1")
	out.addForm(0, 0, 0xD2, shiftNames, "Eb,CL")
	out.addForm(0, 0, 0xD3, shiftNames, "Ev,CL")
	out.addForm(0, 0, 0xE8, "call", "Jz")
	out.addForm(0, 0, 0xE9, "jmp", "Jz")
	out.addForm(0, 0, 0xEB, "jmp", "Jb")
	out.addForm(0, 0, 0xF6, "test|test|not|neg|mul|imul|div|idiv", "Eb")
	out.addForm(0, 0, 0xF7, "test|test|not|neg|mul|imul|div|idiv", "Ev")
	out.addForm(0, 0, 0xFC, "cld", "")
	out.addForm(0, 0, 0xFE, "inc|dec|?|?|?|?|?|?", "Eb")
	out.addForm(0, 0, 0xFF, "inc|dec|call|?|jmp|?|push|?", "Ev")
	out.addForm(1, 0, 0x0B, "ud2", "")
	out.addForm(1, 0, 0x18, "prefetch|prefetch|prefetch|prefetch|nop|nop|nop|nop", "M")
	out.addForm(1, 0, 0x1F, "nop", "Ev")
	out.addForm(1, 0, 0xA3, "bt", "Ev,Gv")
	out.addForm(1, 0, 0xA4, "shld", "Ev,Gv,Ib")
	out.addForm(1, 0, 0xA5, "shld", "Ev,Gv,CL")
	out.addForm(1, 0, 0xAB, "bts", "Ev,Gv")
	out.addForm(1, 0, 0xAC, "shrd", "Ev,Gv,Ib")
	out.addForm(1, 0, 0xAD, "shrd", "Ev,Gv,CL")
	out.addForm(1, 0, 0xAE, "?|?|ldmxcsr|stmxcsr|?|lfence|mfence|sfence", "Ed")
	out.addForm(1, 0, 0xAF, "imul", "Gv,Ev")
	out.addForm(1, 0, 0xB0, "cmpxchg", "Eb,Gb")
	out.addForm(1, 0, 0xB1, "cmpxchg", "Ev,Gv")
	out.addForm(1, 0, 0xB3, "btr", "Ev,Gv")
	out.addForm(1, 0, 0xB6, "movzx", "Gv,Eb")
	out.addForm(1, 0, 0xB7, "movzx", "Gv,Ew")
	out.addForm(1, 0, 0xBA, "?|?|?|?|bt|bts|btr|btc", "Ev,Ib")
	out.addForm(1, 0, 0xBB, "btc", "Ev,Gv")
	out.addForm(1, 0, 0xBC, "bsf", "Gv,Ev")
	out.addForm(1, 0, 0xBD, "bsr", "Gv,Ev")
	out.addForm(1, 0, 0xBE, "movsx", "Gv,Eb")
	out.addForm(1, 0, 0xBF, "movsx", "Gv,Ew")
	out.addForm(1, 0, 0xC0, "xadd", "Eb,Gb")
	out.addForm(1, 0, 0xC1, "xadd", "Ev,Gv")
	out.addForm(1, 2, 0xB8, "popcnt", "Gv,Ev")
	out.addForm(1, 2, 0xBC, "tzcnt", "Gv,Ev")
	out.addForm(1, 2, 0xBD, "lzcnt", "Gv,Ev")

# the SSE forms of an opcode in its four prefixes (packed single, packed double, scalar single,
# scalar double): the names separated by spaces, "-" for one that does not exist, and the operands
# of each separated by spaces
fn sse(mut out {i64: OpForm}, opcode i64, names str, operands str):
	parts = names.split(" ")
	shapes = operands.split(" ")
	for p in 0..4:
		if parts[p] != "-": out.addForm(1, p, opcode, parts[p], shapes[p])

fn sseFloat(mut out {i64: OpForm}):
	packed = "V,W16 V,W16 V,W4 V,W8"
	out.sse(0x51, "sqrtps sqrtpd sqrtss sqrtsd", packed)
	out.sse(0x58, "addps addpd addss addsd", packed)
	out.sse(0x59, "mulps mulpd mulss mulsd", packed)
	out.sse(0x5C, "subps subpd subss subsd", packed)
	out.sse(0x5D, "minps minpd minss minsd", packed)
	out.sse(0x5E, "divps divpd divss divsd", packed)
	out.sse(0x5F, "maxps maxpd maxss maxsd", packed)
	out.sse(0xC2, "cmpps cmppd cmpss cmpsd", "V,W16,Ib V,W16,Ib V,W4,Ib V,W8,Ib")
	out.sse(0x5A, "cvtps2pd cvtpd2ps cvtss2sd cvtsd2ss", "V,W8 V,W16 V,W4 V,W8")
	out.sse(0x5B, "cvtdq2ps cvtps2dq cvttps2dq -", "V,W16 V,W16 V,W16 -")
	out.sse(0xE6, "- cvttpd2dq cvtdq2pd cvtpd2dq", "- V,W16 V,W8 V,W16")
	out.sse(0x2A, "- - cvtsi2ss cvtsi2sd", "- - V,Ey V,Ey")
	out.sse(0x2C, "- - cvttss2si cvttsd2si", "- - Gy,W4 Gy,W8")
	out.sse(0x2D, "- - cvtss2si cvtsd2si", "- - Gy,W4 Gy,W8")
	out.sse(0x2E, "ucomiss ucomisd - -", "V,W4 V,W8 - -")
	out.sse(0x2F, "comiss comisd - -", "V,W4 V,W8 - -")
	out.sse(0x10, "movups movupd movss movsd", "V,W16 V,W16 V,W4 V,W8")
	out.sse(0x11, "movups movupd movss movsd", "W16,V W16,V W4,V W8,V")
	out.sse(0x12, "movlps movlpd movsldup movddup", "V,W8 V,W8 V,W16 V,W8")
	out.sse(0x13, "movlps movlpd - -", "W8,V W8,V - -")
	out.sse(0x14, "unpcklps unpcklpd - -", "V,W16 V,W16 - -")
	out.sse(0x15, "unpckhps unpckhpd - -", "V,W16 V,W16 - -")
	out.sse(0x16, "movhps movhpd movshdup -", "V,W8 V,W8 V,W16 -")
	out.sse(0x17, "movhps movhpd - -", "W8,V W8,V - -")
	out.sse(0x28, "movaps movapd - -", "V,W16 V,W16 - -")
	out.sse(0x29, "movaps movapd - -", "W16,V W16,V - -")
	out.sse(0x50, "movmskps movmskpd - -", "Gd,U Gd,U - -")
	out.sse(0x52, "rsqrtps - rsqrtss -", "V,W16 - V,W4 -")
	out.sse(0x53, "rcpps - rcpss -", "V,W16 - V,W4 -")
	out.sse(0x54, "andps andpd - -", "V,W16 V,W16 - -")
	out.sse(0x55, "andnps andnpd - -", "V,W16 V,W16 - -")
	out.sse(0x56, "orps orpd - -", "V,W16 V,W16 - -")
	out.sse(0x57, "xorps xorpd - -", "V,W16 V,W16 - -")
	out.sse(0xC6, "shufps shufpd - -", "V,W16,Ib V,W16,Ib - -")

# the integer SSE2 forms of two XMM operands, 66-prefixed: opcode and name pairs
lanePairs = "60 punpcklbw 61 punpcklwd 62 punpckldq 63 packsswb 64 pcmpgtb 65 pcmpgtw 66 pcmpgtd 67 packuswb 68 punpckhbw 69 punpckhwd 6A punpckhdq 6B packssdw 6C punpcklqdq 6D punpckhqdq 74 pcmpeqb 75 pcmpeqw 76 pcmpeqd D1 psrlw D2 psrld D3 psrlq D4 paddq D5 pmullw DA pminub DB pand DE pmaxub DF pandn E1 psraw E2 psrad EA pminsw EB por EE pmaxsw EF pxor F1 psllw F2 pslld F3 psllq F4 pmuludq F8 psubb F9 psubw FA psubd FB psubq FC paddb FD paddw FE paddd"

# the SSE4.1 forms of two XMM operands (66 0F 38)
sse41Pairs = "00 pshufb 14 blendvps 17 ptest 29 pcmpeqq 37 pcmpgtq 38 pminsb 39 pminsd 3B pminud 3D pmaxsd 3F pmaxud 40 pmulld"

fn pairsInto(mut out {i64: OpForm}, map i64, pairs str):
	words = pairs.split(" ")
	for k in 0..words.len / 2:
		out.addForm(map, 1, i64.parse("0x{words[2 * k]}") ?? 0, words[2 * k + 1], "V,W16")

fn sseInteger(mut out {i64: OpForm}):
	out.pairsInto(1, lanePairs)
	out.pairsInto(2, sse41Pairs)
	out.addForm(1, 1, 0x6E, "movd", "V,Ey")
	out.addForm(1, 1, 0x7E, "movd", "Ey,V")
	out.addForm(1, 2, 0x7E, "movq", "V,W8")
	out.addForm(1, 1, 0xD6, "movq", "W8,V")
	out.addForm(1, 1, 0x6F, "movdqa", "V,W16")
	out.addForm(1, 2, 0x6F, "movdqu", "V,W16")
	out.addForm(1, 1, 0x7F, "movdqa", "W16,V")
	out.addForm(1, 2, 0x7F, "movdqu", "W16,V")
	out.addForm(1, 1, 0x70, "pshufd", "V,W16,Ib")
	out.addForm(1, 2, 0x70, "pshufhw", "V,W16,Ib")
	out.addForm(1, 3, 0x70, "pshuflw", "V,W16,Ib")
	out.addForm(1, 1, 0x71, "?|?|psrlw|?|psraw|?|psllw|?", "U,Ib")
	out.addForm(1, 1, 0x72, "?|?|psrld|?|psrad|?|pslld|?", "U,Ib")
	out.addForm(1, 1, 0x73, "?|?|psrlq|psrldq|?|?|psllq|pslldq", "U,Ib")
	out.addForm(1, 1, 0xC4, "pinsrw", "V,Ew,Ib")
	out.addForm(1, 1, 0xC5, "pextrw", "Gd,U,Ib")
	out.addForm(1, 1, 0xD7, "pmovmskb", "Gd,U")
	out.addForm(3, 1, 0x08, "roundps", "V,W16,Ib")
	out.addForm(3, 1, 0x09, "roundpd", "V,W16,Ib")
	out.addForm(3, 1, 0x0A, "roundss", "V,W4,Ib")
	out.addForm(3, 1, 0x0B, "roundsd", "V,W8,Ib")
	out.addForm(3, 1, 0x0C, "blendps", "V,W16,Ib")
	out.addForm(3, 1, 0x16, "pextrd", "Ey,V,Ib")
	out.addForm(3, 1, 0x17, "extractps", "Ed,V,Ib")
	out.addForm(3, 1, 0x21, "insertps", "V,W4,Ib")
	out.addForm(3, 1, 0x22, "pinsrd", "V,Ey,Ib")

fn buildForms():
	out {i64: OpForm} = {}
	out.oneByte()
	out.fixedForms()
	out.sseFloat()
	out.sseInteger()
	out

pub forms = buildForms()

fn usesXmm(f OpForm):
	f.operands.any(.startsWith("V") or .startsWith("W") or .startsWith("U"))

# the key of the form of an opcode of `map` under its mandatory prefix; an integer form's
# unprefixed one where the prefix only sizes the operands (66) or repeats (F2, F3)
pub fn formKey(map i64, pfx i64, opcode i64) i64?:
	exact = map << 16 | pfx << 8 | opcode
	if map > 0 and forms.get(exact) != none: return exact
	plain = map << 16 | opcode
	f = try forms.get(plain)
	if map > 0 and pfx > 0 and usesXmm(f): return none
	plain

# the name a group's ModRM reg picks, "?" for none
pub fn nameIn(f OpForm, reg i64) str:
	if not ("|" in f.name): return f.name.copy()
	f.name.split("|")[reg & 7].copy()

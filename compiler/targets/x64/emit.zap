# x86-64 instruction emission helpers shared by the backends. rax is the working register,
# rcx the second operand; data references are RIP-relative into the data area.

# push rbp; mov rbp, rsp: a generated helper's frame, from here a region of code of its own for
# the unwinder
fn framePrologue(mut a Asm):
	a.asmUnwindRegion(unwindFrame)
	a.em1(0x55)
	a.em3(0x48, 0x89, 0xE5)

# the code's bytes: each value's low byte (a displacement or an immediate given negative)
fn em1(mut a Asm, b0 i64):
	a.code.push(u8.wrap(b0))

fn em2(mut a Asm, b0 i64, b1 i64):
	a.em1(b0)
	a.em1(b1)

fn em3(mut a Asm, b0 i64, b1 i64, b2 i64):
	a.em1(b0)
	a.em1(b1)
	a.em1(b2)

fn em4(mut a Asm, b0 i64, b1 i64, b2 i64, b3 i64):
	a.em1(b0)
	a.em1(b1)
	a.em1(b2)
	a.em1(b3)

fn em5(mut a Asm, b0 i64, b1 i64, b2 i64, b3 i64, b4 i64):
	a.em4(b0, b1, b2, b3)
	a.em1(b4)

fn emN(mut a Asm, bs i64[]):
	for b in bs:
		a.em1(b)

fn emit32(mut a Asm, v i64):
	bytesPut32(a.code, v)

fn emit64(mut a Asm, v i64):
	bytesPut64(a.code, v)

fn pushRax(mut a Asm):
	a.em1(0x50)

fn movRaxImm(mut a Asm, v i64):
	if v == 0:
		a.em2(0x31, 0xC0)   # xor eax, eax
	elif v > 0 and v <= 4_294_967_295:
		a.em1(0xB8)   # mov eax, imm32 (zero-extended)
		a.emit32(v)
	elif v >= -2_147_483_648 and v <= 2_147_483_647:
		a.em3(0x48, 0xC7, 0xC0)
		a.emit32(v)
	else:
		a.em2(0x48, 0xB8)
		a.emit64(v)

# an unconditional jump; one right after another (nothing placed between) is unreachable
fn jmpLabel(mut a Asm, l i64):
	if a.lastJmpEnd == a.code.len: return
	a.em1(0xE9)
	a.asmRel32Label(l)
	a.fixJump[len - 1] = 1
	a.lastJmpEnd = a.code.len
	a.lastJmpTarget = l
	a.endJmpEnd = a.code.len
	a.endJmpTarget = l
	a.endJmpLabels.clear()

# cc: 0x84 je, 0x85 jne, 0x80 jo, 0x82 jb/jc, 0x83 jae, 0x8C jl, 0x8D jge, 0x8E jle, 0x8F jg, 0x87 ja, 0x86 jbe
fn jccLabel(mut a Asm, cc i64, l i64):
	a.em2(0x0F, cc)
	a.asmRel32Label(l)
	a.fixJump[len - 1] = 2

fn callLabel(mut a Asm, l i64):
	a.em1(0xE8)
	a.asmRel32Label(l)

fn testRax(mut a Asm):
	a.em3(0x48, 0x85, 0xC0)

fn addRsp(mut a Asm, n i64):
	if n != 0 and n <= 127:
		a.em4(0x48, 0x83, 0xC4, n)   # add rsp, imm8
	elif n != 0:
		a.em3(0x48, 0x81, 0xC4)
		a.emit32(n)

# [REX] op1 [op2]: an instruction's prefix and opcode for register reg and a memory operand on
# base and index (-1: none); the REX byte only when one of its bits is set
fn emRexOpcode(mut a Asm, rexW bool, op1 i64, op2 i64, reg i64, base i64, index i64):
	rex = 0x40
	if rexW:
		rex |= 8
	if reg >= 8:
		rex |= 4
	if index >= 8:
		rex |= 2
	if base >= 8:
		rex |= 1
	if rex != 0x40:
		a.em1(rex)
	a.em1(op1)
	if op2 >= 0:
		a.em1(op2)

# The ModRM byte addressing [base + index + disp] for the register field reg (index -1: none),
# its SIB byte when one is needed, and the shortest displacement: none when it is 0 (rbp and r13
# always take one), one byte when it fits, else four
fn emModRm(mut a Asm, reg i64, base i64, index i64, disp i64):
	if base == ripBase:
		a.em1(0x05 | (reg & 7) << 3)   # [rip + disp32]: the data at disp, the instruction's last bytes
		a.asmDisp32Data(disp)
		return
	md = 0x80
	if disp == 0 and (base & 7) != 5:
		md = 0
	elif disp >= -128 and disp <= 127:
		md = 0x40
	rm = base & 7
	if index >= 0 or rm == 4:
		rm = 4   # a SIB byte follows
	a.em1(md | (reg & 7) << 3 | rm)
	if rm == 4:
		ix = 4   # no index
		if index >= 0:
			ix = index & 7
		a.em1(ix << 3 | (base & 7))
	if md == 0x40:
		a.em1(disp & 255)
	elif md == 0x80:
		a.emit32(disp)

# [REX] op1 [op2] modrm [sib] [disp]: an instruction on register reg and the memory operand
# [base + index + disp], with x64 register numbers (rax 0, rcx 1, rdx 2, rbx 3, rbp 5, r8 8,
# r12..r15 12..15; rsp never appears). A 0x66 prefix, when needed, goes before this.
fn memOp(mut a Asm, rexW bool, op1 i64, op2 i64, reg i64, base i64, index i64, disp i64):
	a.emRexOpcode(rexW, op1, op2, reg, base, index)
	a.emModRm(reg, base, index, disp)

# [REX] op1 [op2] modrm sib: an instruction on register reg and [base + index * (1 << scaleBits)]
fn memOpScaled(mut a Asm, rexW bool, op1 i64, op2 i64, reg i64, base i64, index i64, scaleBits i64):
	a.emRexOpcode(rexW, op1, op2, reg, base, index)
	if (base & 7) == 5:
		a.em1(0x44 | (reg & 7) << 3)   # mod 01 + disp8 0: rbp/r13 need a displacement
		a.em1(scaleBits << 6 | (index & 7) << 3 | (base & 7))
		a.em1(0)
	else:
		a.em1(0x04 | (reg & 7) << 3)
		a.em1(scaleBits << 6 | (index & 7) << 3 | (base & 7))

# the same addressing [base + index << scaleBits + disp]
fn memOpScaledDisp(
	mut a Asm,
	rexW bool,
	op1 i64,
	op2 i64,
	reg i64,
	base i64,
	index i64,
	scaleBits i64,
	disp i64
):
	if disp == 0:
		a.memOpScaled(rexW, op1, op2, reg, base, index, scaleBits)
		return
	a.emRexOpcode(rexW, op1, op2, reg, base, index)
	short = disp >= -128 and disp <= 127
	a.em1((0x44 if short else 0x84) | (reg & 7) << 3)   # mod 01 (disp8) or 10 (disp32), SIB
	a.em1(scaleBits << 6 | (index & 7) << 3 | (base & 7))
	if short:
		a.em1(disp & 255)
	else:
		a.emit32(disp)

# a ModRM byte addressing [rbp+disp] for the register field `reg`
fn emRbp(mut a Asm, reg i64, disp i64):
	a.emModRm(reg, 5, -1, disp)

fn loadRaxFromRbp(mut a Asm, disp i64):
	if a.lastStoreEnd == a.code.len and a.lastStoreDisp == disp:
		return   # rax still holds what the slot was just given
	a.em2(0x48, 0x8B)
	a.emRbp(0, disp)

fn storeRaxToRbp(mut a Asm, disp i64):
	a.em2(0x48, 0x89)
	a.emRbp(0, disp)
	a.lastStoreDisp = disp
	a.lastStoreEnd = a.code.len

fn leaRaxData(mut a Asm, off i64):
	a.em3(0x48, 0x8D, 0x05)
	a.asmDisp32Data(off)

fn movqRaxXmm0(mut a Asm):
	if a.lastQmovEnd == a.code.len and a.lastLabelEnd != a.code.len and not a.lastQmovToRax:
		return   # rax holds xmm0's bits already
	a.em5(0x66, 0x48, 0x0F, 0x7E, 0xC0)
	a.lastQmovEnd = a.code.len
	a.lastQmovToRax = true

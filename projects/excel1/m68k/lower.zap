# What each 68000 instruction does, as steps of the common form (cpu/form.zap): the second half of
# the description that table.zap begins. Effective addresses are located once (a -(An) or (An)+
# changes An there), read and written through the place found, so a read-modify-write of memory
# computes its address once.

import cpu

type Lowering:
	steps cpu.Step[]
	temps i64
	next i64   # the code offset of the instruction after this one

# where an operand is: a register (0-15, 16 the user stack pointer), memory at a temporary's
# address, the CCR, the SR or an immediate in a temporary
type Place:
	reg i64 = -1
	addr i64 = -1
	isCcr bool = false
	isSr bool = false
	value i64 = -1

fn fresh(mut l Lowering):
	l.temps += 1
	l.temps - 1

# appends a step writing a new temporary, which it gives
fn put(mut l Lowering, s cpu.Step):
	t = l.fresh()
	l.steps.push(cpu.Step(..s, d = t))
	t

fn emit(mut l Lowering, s cpu.Step):
	l.steps.push(s)

fn constant(mut l Lowering, k i64) i64:
	l.put(cpu.Step(op = .Const, k))

fn getReg(mut l Lowering, r i64) i64:
	l.put(cpu.Step(op = .Get, a = r))

fn setReg(mut l Lowering, r i64, v i64, size i64 = 4):
	l.emit(cpu.Step(op = .Put, a = r, b = v, size))

fn binary(mut l Lowering, op cpu.Op, a i64, b i64, size i64 = 4) i64:
	l.put(cpu.Step(op, a, b, size))

fn unary(mut l Lowering, op cpu.Op, a i64, size i64 = 4) i64:
	l.put(cpu.Step(op, a, size))

fn addConstant(mut l Lowering, t i64, k i64) i64:
	l.binary(.Add, t, l.constant(k & 0xFFFF_FFFF))

# the step a byte move of a7 takes: 2, to keep the stack even
fn stepOf(reg i64, size i64):
	2 if size == 1 and reg == 7 else size

# the address of an indexed mode: base + displacement + the index register (a word sign-extended)
fn indexed(mut l Lowering, base i64, o Operand) i64:
	index = l.getReg(o.index)
	if not o.indexLong: index = l.unary(.Sext, index, 2)
	l.binary(.Add, l.addConstant(base, o.value), index)

# the operand's place, a -(An) or (An)+ applied
fn locate(mut l Lowering, o Operand, size i64):
	match o.mode:
		D: Place(reg = o.reg)
		A: Place(reg = 8 + o.reg)
		Usp: Place(reg = 16)
		Ccr: Place(isCcr = true)
		Sr: Place(isSr = true)
		Imm: Place(value = l.constant(o.value))
		Ind: Place(addr = l.getReg(8 + o.reg))
		PostInc:
			a = l.getReg(8 + o.reg)
			l.setReg(8 + o.reg, l.addConstant(a, stepOf(o.reg, size)))
			Place(addr = a)
		PreDec:
			a = l.addConstant(l.getReg(8 + o.reg), -stepOf(o.reg, size))
			l.setReg(8 + o.reg, a)
			Place(addr = a)
		Disp: Place(addr = l.addConstant(l.getReg(8 + o.reg), o.value))
		Index: Place(addr = l.indexed(l.getReg(8 + o.reg), o))
		AbsW, AbsL: Place(addr = l.constant(o.value))
		PcDisp: Place(addr = l.put(cpu.Step(op = .Code, k = o.value)))
		PcIndex: Place(addr = l.indexed(l.put(cpu.Step(op = .Code, k = 0)), o))
		_: Place()

# the address an effective address names (LEA, PEA, JMP, JSR)
fn addressOf(mut l Lowering, o Operand):
	l.locate(o, 4).addr

fn fetch(mut l Lowering, p Place, size i64):
	if p.reg >= 0: return l.getReg(p.reg)
	if p.addr >= 0: return l.put(cpu.Step(op = .Load, a = p.addr, size))
	if p.isCcr: return l.put(cpu.Step(op = .GetCcr))
	if p.isSr: return l.put(cpu.Step(op = .GetSr))
	p.value

fn store(mut l Lowering, p Place, v i64, size i64):
	if p.reg >= 8:
		l.setReg(p.reg, v)
	elif p.reg >= 0:
		l.setReg(p.reg, v, size)
	elif p.addr >= 0:
		l.emit(cpu.Step(op = .Store, a = p.addr, b = v, size))
	elif p.isCcr:
		l.emit(cpu.Step(op = .PutCcr, a = v))
	elif p.isSr:
		l.emit(cpu.Step(op = .PutSr, a = v))

fn flag(mut l Lowering, f i64, t i64):
	l.emit(cpu.Step(op = .FlagSet, a = t, k = f))

fn setNz(mut l Lowering, r i64, size i64):
	l.emit(cpu.Step(op = .FlagN, a = r, size))
	l.emit(cpu.Step(op = .FlagZ, a = r, size))

# N and Z of the result, V and C clear: the logical operations' and the moves' flags
fn logicFlags(mut l Lowering, r i64, size i64):
	l.setNz(r, size)
	zero = l.constant(0)
	l.flag(cpu.flagV, zero)
	l.flag(cpu.flagC, zero)

# the flags of d + s = r (or of d - s = r): C and V, X too unless a compare's, N, and Z or a
# Z kept (ADDX, SUBX, NEGX)
fn arithmeticFlags(
	mut l Lowering,
	isSub bool,
	d i64,
	s i64,
	r i64,
	size i64,
	hasX bool,
	keepsZ bool
):
	carry = l.put(cpu.Step(op = .CarrySub if isSub else .CarryAdd, a = d, b = s, c = r, size))
	l.flag(cpu.flagC, carry)
	if hasX: l.flag(cpu.flagX, carry)
	l.flag(
		cpu.flagV,
		l.put(cpu.Step(op = .OverSub if isSub else .OverAdd, a = d, b = s, c = r, size))
	)
	l.emit(cpu.Step(op = .FlagN, a = r, size))
	l.emit(cpu.Step(op = .FlagZAnd if keepsZ else .FlagZ, a = r, size))

fn xBit(mut l Lowering) i64:
	l.binary(.And, l.binary(.Shr, l.put(cpu.Step(op = .GetCcr)), l.constant(4)), l.constant(1))

fn pushValue(mut l Lowering, v i64):
	sp = l.addConstant(l.getReg(15), -4)
	l.setReg(15, sp)
	l.emit(cpu.Step(op = .Store, a = sp, b = v, size = 4))

fn popValue(mut l Lowering, size i64):
	sp = l.getReg(15)
	v = l.put(cpu.Step(op = .Load, a = sp, size))
	l.setReg(15, l.addConstant(sp, size))
	v

# The steps of an instruction, its temporaries numbered from `firstTemp`, with how many it used.
pub fn lower(i Inst, firstTemp i64) (cpu.Step[], i64):
	l = Lowering(steps = [], temps = firstTemp, next = i.at + i.length)
	l.lowerInto(i)
	(l.steps, l.temps)

fn lowerInto(mut l Lowering, i Inst):
	match i.kind:
		Move, Movea, Moveq, Lea, Pea, Clr, Exg, Swap, Ext, Link, Unlk, Movem, Movep: l.lowerMove(i)
		Add, Adda, Addx, Sub, Suba, Subx, Cmp, Cmpa, Cmpm, Neg, Negx: l.lowerArithmetic(i)
		And, Or, Eor, Not, Tst, Tas, Mulu, Muls: l.lowerLogic(i)
		Btst, Bchg, Bclr, Bset: l.lowerBit(i)
		Asl, Asr, Lsl, Lsr, Rol, Ror, Roxl, Roxr: l.lowerShift(i)
		Divu, Divs, Abcd, Sbcd, Nbcd, Chk, Trapv: l.lowerHelper(i)
		_: l.lowerFlow(i)

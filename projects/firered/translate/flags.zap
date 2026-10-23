# Which flags each instruction must compute: those a later instruction reads before another
# writes them (most instructions set the flags, few read them).

import arm

pub flagN = 8
pub flagZ = 4
pub flagC = 2
pub flagV = 1
pub allFlags = 15

# the flags a condition reads
pub fn condReads(cond i64) i64:
	match cond:
		0, 1: flagZ
		2, 3: flagC
		4, 5: flagN
		6, 7: flagV
		8, 9: flagC | flagZ
		10, 11: flagN | flagV
		12, 13: flagZ | flagN | flagV
		_: 0

pub fn isArithmetic(kind i64) bool:
	(kind >= 2 and kind <= 7) or kind == arm.aluCmp or kind == arm.aluCmn

pub fn readsCarry(kind i64) bool:
	kind in [5, 6, 7]

# whether the second operand's shift gives a carry out (else a logical operation keeps C)
pub fn shifterCarries(b arm.Operand) bool:
	match b:
		Imm(_, rot): rot != 0
		Reg(_, shift, amount): not (shift == 0 and amount == 0)
		RegShift: true

# the flags the instruction reads and those it writes
pub fn flagUse(i arm.Instr) (i64, i64):
	reads = condReads(i.cond)
	writes = 0
	match i.op:
		Alu(kind, sets, _, _, b):
			if readsCarry(kind): reads |= flagC
			match b:
				Reg(_, shift, _) and shift == arm.shiftRrx: reads |= flagC
				RegShift: reads |= flagC
				_: pass
			if sets:
				writes = flagN | flagZ
				if isArithmetic(kind): writes |= flagC | flagV
				elif b.shifterCarries(): writes |= flagC
		Mul(sets, _, _, _, _):
			if sets: writes = flagN | flagZ
		MulLong(_, _, sets, _, _, _, _):
			if sets: writes = flagN | flagZ
		ReadPsr: reads |= allFlags
		WritePsr(saved, mask, _):
			if not saved and (mask >> 3) & 1 == 1: writes = allFlags
		_: pass
	(reads, writes)

# The flags live after each instruction of the function: the union over the ways out of it of
# what is read before being written. A conditional instruction's writes may not happen, so they
# keep what is live; a way out of the function (a return, a call by a register) reads nothing.
pub fn liveAfter(f Function) i64[]:
	n = f.instrs.len
	before = zeros(n)
	after = zeros(n)
	uses = f.instrs.map(.flagUse())
	successors = (0..n).map(f.successorsOf(it))
	changed = true
	while changed:
		changed = false
		for k in n - 1..-1 step -1:
			out = 0
			for s in successors[k]:
				out |= before[s]
			reads, writes = uses[k]
			kills = writes if f.instrs[k].cond == arm.always else 0
			inn = reads | (out & ~kills)
			if out != after[k] or inn != before[k]:
				after[k] = out
				before[k] = inn
				changed = true
	after

# the instructions that may run after instruction k, within the function
pub fn successorsOf(function Function, k i64) i64[]:
	i = function.instrs[k]
	out = []
	falls = i.cond != arm.always or not i.writesPc()
	if falls and k + 1 < function.instrs.len and function.instrs[k + 1].at == i.next():
		out.push(k + 1)
	if i.op is Branch(target, false):
		if function.instrIndex(target) is t and target in function.labels: out.push(t)
	if function.tables.get(i.at) is cases:
		for c in cases:
			if function.instrIndex(c) is t: out.push(t)
	out

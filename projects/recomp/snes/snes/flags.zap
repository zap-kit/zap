# Which flags each instruction computes.

pub flagN = 8
pub flagV = 4
pub flagZ = 2
pub flagC = 1
pub allFlags = 15

# The flags live after each instruction: all of them. Each instruction first polls for an interrupt,
# and one entered there pushes the status register, so the flags are the cartridge's at every
# instruction boundary (a flag left uncomputed as dead showed in the stale stack bytes).
pub fn liveAfter(f Function) i64[]:
	fill(f.instrs.len, allFlags)

# the instructions of the function that may run after instruction k, -1 for a way out of it
pub fn waysOn(f Function, k i64) i64[]:
	i = f.instrs[k]
	out = []
	for t in f.successorKeys(i):
		out.push(f.index.get(t) ?? -1)
	if i.name in ["rts", "rtl", "rti", "stp", "brk", "cop"] or i.at in f.unresolved: out.push(-1)
	out

# the keys code may go on at after instruction i: the next instruction, a branch's or a jump's
# target, a dispatch's cases
pub fn successorKeys(f Function, i Instr) i64[]:
	out = []
	k = i.keyOf()
	if i.fallsThrough(): out.push(key(i.next(), f.afterOf(k)))
	if i.name in conditionalBranches or i.name == "bra" or i.name == "brl":
		out.push(key(i.target(), i.widths))
	if (i.name == "jmp" or i.name == "jml") and (i.mode == "w" or i.mode == "l"):
		out.push(key(i.jumpTargetOf(), i.widths))
	if f.dispatches.get(i.at) is d and not d.calls:
		for t in d.targets:
			out.push(key(t, i.widths))
	out

# whether the instruction may go on to the one after it
pub fn fallsThrough(i Instr) bool:
	not (i.name in ["rts", "rtl", "rti", "stp", "brk", "cop", "jmp", "jml", "bra", "brl"])

# a jump's target: a long one's, else in the jump's bank
pub fn jumpTargetOf(i Instr) i64:
	i.value if i.mode == "l" else (i.at & 0xFF_0000) | i.value

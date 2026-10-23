# The flow analysis the recompiler needs: from a set of entry points, following each instruction's
# successors, which bytes are code (apart from the data between functions), each function's entry,
# and whether an instruction hands back to the driver (a trap, a return, a dynamic jump, or a
# branch out of the code found) rather than flowing on inside the recompiled function.

pub type Flow:
	code {i64: Inst}   # the instruction at each code address
	order i64[]   # the code addresses in rising order
	entries i64[]   # the addresses a Bsr or Jsr calls, and the given entries: function starts

# the successors an instruction flows to inside the code (not a call's target, not a dynamic jump):
# the fallthrough, a branch's target
fn successors(i Inst) i64[]:
	match i.kind:
		Bra: [i.target] if i.target >= 0 else []
		Jmp: [i.src.value] if i.src.mode == .PcDisp else []
		Bcc:
			[i.target, i.at + i.length]
		Dbcc:
			[i.target, i.at + i.length]
		Bsr, Jsr, Rts, Rte, Rtr, Trap, Illegal, Fline, Stop:
			[i.at + i.length] if i.kind == .Bsr or i.kind == .Jsr else []
		Aline:
			[i.at + i.length]
		_: [i.at + i.length]

# the call target of an instruction, -1 for none: a Bsr, or a Jsr to a static address
fn callTarget(i Inst):
	if i.kind == .Bsr: return i.target
	if i.kind == .Jsr and i.src.mode == .PcDisp: return i.src.value
	-1

# The code reached from the entries, following branches and calls, within [base, base + length).
pub fn analyze(code u8[], base i64, length i64, givenEntries i64[]) Flow:
	found {i64: Inst} = {}
	entries i64[] = []
	work = givenEntries.copy()
	for e in givenEntries:
		if e not in entries: entries.push(e)
	while not work.isEmpty:
		at = work.pop() ?? break
		if at < base or at >= base + length or at in found: continue
		i = decode(code, at)
		if i.row < 0 and i.kind == .Illegal and i.word != 0x4AFC: continue   # data, not an instruction
		found[at] = i
		for s in i.successors():
			if s not in found: work.push(s)
		call = i.callTarget()
		if call >= base and call < base + length:
			if call not in entries: entries.push(call)
			if call not in found: work.push(call)
	Flow(code = found, order = found.keys().sorted(), entries = entries.sorted())

# whether the instruction at `at` hands back to the driver (the recompiled function returns `at`):
# a trap, a return, a dynamic jump, a call, or a branch leaving the code found
pub fn isHandoff(f Flow, i Inst) bool:
	match i.kind:
		Aline, Trap, Illegal, Fline, Stop, Rts, Rte, Rtr, Bsr, Jsr: true
		Jmp: i.src.mode != .PcDisp or i.target not in f.code
		Bra: i.target not in f.code
		Bcc, Dbcc: i.target not in f.code or i.at + i.length not in f.code
		_: i.at + i.length not in f.code

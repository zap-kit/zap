# A function of the cartridge as a Zap function. One without jumps inside it is its statements
# in order; any other is a loop over a match of its labels, each arm the instructions from that
# label to the next, its cycles counted, and an arm that a jump reaches from below also runs
# the hardware's events that are due (an interrupt, a line drawn). The arm `_` takes a jump to
# an address that is no label: the return, when it is where the function was called from, or
# the function there, called.

import arm

# a function's name: t (Thumb) or a (ARM), then its address
pub fn functionName(k i64) str:
	"{"t" if k & 1 == 1 else "a"}{k & ~1:08x}"

# whether the function needs its labels: a jump inside it, a table, a branch to its start
fn isDispatched(f Function):
	f.labels.len > 1 or not f.tables.isEmpty or f.instrs.any(.branchesTo(f.entry))

fn branchesTo(i arm.Instr, at i64):
	match i.op:
		Branch(target, false): target == at
		_: false

# the labels that are instructions of the function, by address
fn armLabels(f Function):
	out {i64: bool} = {}
	for k, i in f.instrs:
		if i.at in f.labels or (k > 0 and f.instrs[k - 1].next() != i.at): out[i.at] = true
	out

# the labels a jump reaches from an instruction at or after them: the heads of loops
fn loopHeads(f Function):
	out {i64: bool} = {}
	for i in f.instrs:
		if i.op is Branch(target, false) and target <= i.at and target in f.labels:
			out[target] = true
		if f.tables.get(i.at) is cases:
			for c in cases:
				if c <= i.at: out[c] = true
	out

# the cycles an instruction takes (Thumb from the cartridge with its prefetch), and those a jump
# to a label adds (the pipeline filled again); the memory's own are counted by gba's loads and
# stores
cyclesEach = 1
cyclesJump = 2

# The Zap text of the function.
pub fn emitFunction(code Code, entries {i64: bool}, f Function, traced bool) str[]:
	live = f.liveAfter()
	dispatched = f.isDispatched()
	e = FnText(
		lines = [],
		temps = 0,
		dispatched,
		thumb = f.thumb,
		usesEntry = dispatched,
		flagsRead = 0,
		flagsWritten = 0
	)
	labels = f.armLabels() if dispatched else {}
	heads = f.loopHeads()
	depth = 4 if dispatched else 1
	k = 0
	while k < f.instrs.len:
		start = k
		k += 1
		while k < f.instrs.len and not (f.instrs[k].at in labels):
			k += 1
		at = f.instrs[start].at
		if dispatched: e.put(3, "{hex(key(at, f.instrs[start].thumb))}:")
		e.put(depth, "gba.cycles += {cyclesEach * (k - start) + cyclesJump}")
		if at in heads: e.put(depth, "if gba.cycles >= gba.nextEvent: gba.catchUp()")
		for j in start..k:
			e.instr(depth, code, entries, f, j, live[j])
		last = f.instrs[k - 1]
		if last.cond == arm.always and last.writesPc(): continue
		if dispatched and f.instrIndex(last.next()) != none:
			e.put(depth, "pc = {hex(key(last.next(), last.thumb))}")
		else:
			e.put(depth, "cpu.undefinedAt({hex(last.next())})")
	for flag in [flagN, flagZ, flagC, flagV]:
		if e.flagsWritten & flag != 0 and e.flagsRead & flag == 0:
			e.lines = withoutEmptyIfs(
				e.lines.filter(not .trimmed().startsWith("{flagName(flag)} = "))
			)
			e.flagsWritten &= ~flag
	out = ["{"pub " if f.entry == romBase else ""}fn {functionName(key(f.entry, f.thumb))}():"]
	if traced: out.push("\tgba.entered({hex(key(f.entry, f.thumb))})")
	if e.usesEntry: out.push("\tentry = cpu.r14")
	for flag in [flagN, flagZ, flagC, flagV]:
		if (e.flagsRead | e.flagsWritten) & flag == 0: continue
		out.push("\t{flagName(flag)} = false")
	if dispatched:
		out.push("\tpc u32 = {hex(key(f.entry, f.thumb))}")
		out.push("\tloop:")
		out.push("\t\tmatch pc:")
	out.extend(e.lines)
	if dispatched:
		out.extend(
			[
				"\t\t\t_:",
				"\t\t\t\tif pc | 1 == entry | 1: return",
				"\t\t\t\tback = cpu.r14",
				"\t\t\t\tif not call(pc): cpu.unwind = pc",
				"\t\t\t\tif cpu.unwind != 0:",
				"\t\t\t\t\tif cpu.unwind | 1 == entry | 1: cpu.unwind = 0",
				"\t\t\t\t\treturn",
				"\t\t\t\tpc = back"
			]
		)
	out

fn depthOf(line str):
	n = 0
	while n < line.len and line[n] == '	':
		n += 1
	n

# the lines without an `if` whose body went
fn withoutEmptyIfs(lines str[]):
	out = []
	for k, line in lines:
		empty = line.trimmed().startsWith("if ") and line.endsWith(":") and
			(k + 1 == lines.len or depthOf(lines[k + 1]) <= depthOf(line))
		if not empty: out.push(line.copy())
	out

# One instruction; a condition puts it in an `if`, left out when it holds nothing.
fn instr(
	mut fnText FnText,
	depth i64,
	code Code,
	entries {i64: bool},
	f Function,
	k i64,
	live i64
):
	i = f.instrs[k]
	if i.cond == 15: return
	readBefore = fnText.flagsRead
	mark = fnText.lines.len
	inner = depth if i.cond == arm.always else depth + 1
	if i.cond != arm.always: fnText.put(depth, "if {fnText.condText(i.cond)}:")
	match i.op:
		Alu: fnText.alu(inner, i, live)
		Mul, MulLong: fnText.mulOf(inner, i, live)
		Load: fnText.load(inner, code, i)
		Store: fnText.store(inner, i)
		Block: fnText.block(inner, i)
		Swap: fnText.swap(inner, i)
		Branch(target, link): fnText.branch(inner, entries, f, i, target, link)
		Exchange(m): fnText.exchange(inner, entries, f, i, m)
		Software(n): fnText.put(inner, "gba.swi({n if i.thumb else n >> 16})")
		ReadPsr(d, saved):
			value = "cpu.spsr" if saved
				else "cpu.psr({fnText.readFlag(flagN)}, {fnText.readFlag(flagZ)}, {fnText.readFlag(flagC)}, {fnText.readFlag(flagV)})"
			fnText.put(inner, "{regTarget(d)} = {value}")
		WritePsr(saved, mask, b): fnText.writePsr(inner, i, saved, mask, b, live)
		Undefined: fnText.put(inner, "cpu.undefinedAt({hex(i.at)})")
	if i.cond != arm.always and fnText.lines.len == mark + 1:
		fnText.lines.pop()
		fnText.flagsRead = readBefore

fn writePsr(
	mut fnText FnText,
	depth i64,
	i arm.Instr,
	saved bool,
	mask i64,
	b arm.Operand,
	live i64
):
	value = fnText.operandValue(i, b)
	if saved:
		fnText.put(depth, "cpu.setSpsr({value}, {mask})")
		return
	if (mask >> 3) & 1 == 1:
		for k, flag in [flagN, flagZ, flagC, flagV]:
			if live & flag != 0: fnText.setFlag(depth, flag, "({value} >> {31 - k}) & 1 == 1")
	if mask & 1 == 1: fnText.put(depth, "cpu.setControl({value})")

# the function a key names, called: by its name when it is one, else through the dispatcher
fn callText(entries {i64: bool}, k i64):
	"{functionName(k)}()" if k in entries else "call({hex(k)})"

fn branch(
	mut fnText FnText,
	depth i64,
	entries {i64: bool},
	f Function,
	i arm.Instr,
	target i64,
	link bool
):
	k = key(target, i.thumb)
	if link:
		fnText.put(depth, "cpu.r14 = {hex(key(i.next(), i.thumb))}")
		fnText.put(depth, callText(entries, k))
		return
	if target in f.labels and f.instrIndex(target) != none:
		fnText.put(depth, "pc = {hex(k)}")
		fnText.put(depth, "continue")
		return
	fnText.farCall(depth, entries, k)

# a jump to another function: called, then on to where lr said when it jumped
fn farCall(mut fnText FnText, depth i64, entries {i64: bool}, k i64):
	back = fnText.temp("r")
	fnText.put(depth, "{back} = cpu.r14")
	fnText.put(depth, callText(entries, k))
	fnText.usesEntry = true
	fnText.put(depth, "if cpu.unwind != 0:")
	fnText.put(depth + 1, "if cpu.unwind | 1 == entry | 1: cpu.unwind = 0")
	fnText.put(depth + 1, "return")
	fnText.jump(depth, back)

fn exchange(
	mut fnText FnText,
	depth i64,
	entries {i64: bool},
	f Function,
	i arm.Instr,
	m i64
):
	match f.known.get(i.at):
		v:
			if (v & ~1) in f.labels and f.instrIndex(v & ~1) != none and
				fnText.dispatched:
				fnText.put(depth, "pc = {hex(v)}")
				fnText.put(depth, "continue")
			else:
				fnText.farCall(depth, entries, v)
		none: fnText.jump(depth, i.reg(m))

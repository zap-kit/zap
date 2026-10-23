# The jumps through a variable that no dispatch of the cfg names, as the NMI's `jmp ($001C)`: they
# go where the program stored a constant in the variable (an `lda #`, `ldx #` or `ldy #` and then
# a store of that register to it, the direct page taken at 0), each target that is code a function
# of its own.

# The dispatches of the program's unresolved `jmp (w)`, from the constants stored in their
# variables; none for a jump whose variable no constant is stored in.
pub fn storedDispatches(code Code, p Program) Dispatch[]:
	stored = p.storedConstants()
	out = []
	seen {i64: bool} = {}
	for f in p.functions:
		for i in f.instrs:
			if i.mode != "(w)" or not (i.at in f.unresolved) or i.at in seen: continue
			seen[i.at] = true
			targets = (stored.get(i.value) ?? [])
				.map((i.at & 0xFF_0000) | it)
				.filter(code.isCode(it) and not code.isData[romOffset(it)])
				.sorted()
			if not targets.isEmpty:
				out.push(Dispatch(at = canonical(i.at), calls = false, targets))
	out

# The 16-bit constants stored in each variable of bank 0's work RAM, from what the registers may
# hold at each store: within a function, and from the constants its callers and the functions
# that jump to it hold (run over the program until they settle).
fn storedConstants(p Program):
	atEntry {i64: {str: i64[]}} = {}
	changed = true
	while changed:
		changed = false
		for f in p.functions:
			held = f.registerConstants(f.entryOf(atEntry))
			for k, i in f.instrs:
				for t in f.leavingTo(i):
					before {str: i64[]} = {}
					if atEntry.get(t) is known: before = known.copy()
					if mergeInto(before, held[k]):
						atEntry[t] = before
						changed = true
	out {i64: i64[]} = {}
	for f in p.functions:
		held = f.registerConstants(f.entryOf(atEntry))
		for k, i in f.instrs:
			if not (i.name in ["sta", "stx", "sty"]) or not (i.mode == "w" or i.mode == "d"):
				continue
			if i.mode == "w" and i.value >= 0x2000: continue
			values = held[k].get(i.name[2..3]) ?? continue
			list = (out.get(i.value) ?? []).copy()
			for v in values:
				if v != unknown and not (v in list): list.push(v)
			out[i.value] = list
	out

unknown = -1

# what the registers may hold at the function's entry: anything, and what its callers give it
fn entryOf(f Function, atEntry {i64: {str: i64[]}}):
	out {str: i64[]} = {"a": [unknown], "x": [unknown], "y": [unknown]}
	if atEntry.get(f.entryKey()) is given: mergeInto(out, given)
	out

# the keys of the functions instruction i enters, the registers as they are before it: a call or
# a jump to one, a branch or the way on out of this function
fn leavingTo(f Function, i Instr):
	out = []
	direct = i.mode == "w" or i.mode == "l" or isRelative(i.mode)
	if i.name in ["jsr", "jsl", "jmp", "jml", "bra", "brl"] or i.name in conditionalBranches:
		if direct:
			t = key(i.target() if isRelative(i.mode) else i.jumpTargetOf(), i.widths)
			if not (t in f.index) or i.name == "jsr" or i.name == "jsl": out.push(t)
	if i.fallsThrough() and not (i.name == "jsr" or i.name == "jsl"):
		next = key(i.next(), f.afterOf(i.keyOf()))
		if not (next in f.index): out.push(next)
	out

# the instructions that leave a register no constant, but its load of a 16-bit immediate
writesA = ["lda", "pla", "txa", "tya", "tdc", "tsc", "xba", "adc", "sbc", "and", "ora", "eor"]
writesX = ["ldx", "plx", "tax", "tyx", "tsx", "inx", "dex"]
writesY = ["ldy", "ply", "tay", "txy", "iny", "dey"]

# The constants each register may hold before each instruction, unknown among them when it may
# hold anything else; a register missing is one no way reaches yet.
fn registerConstants(f Function, entry {str: i64[]}):
	before = []
	for _ in f.instrs:
		empty {str: i64[]} = {}
		before.push(empty)
	first = f.index.get(f.entryKey()) ?? return before
	before[first] = entry.copy()
	work = [first]
	while work.pop() is k:
		after = f.instrs[k].afterConstants(before[k])
		for s in f.waysOn(k):
			if s < 0: continue
			if mergeInto(before[s], after): work.push(s)
	before

fn afterConstants(i Instr, held {str: i64[]}):
	out = held.copy()
	if i.name in ["jsr", "jsl", "mvn", "mvp"]:
		for r in ["a", "x", "y"]:
			out[r] = [unknown]
		return out
	r = "a" if i.name in writesA or i.mode == "A"
		else "x" if i.name in writesX
		else "y" if i.name in writesY
		else ""
	if r.isEmpty: return out
	out[r] = [i.value] if i.name.startsWith("ld") and isImmediate(i.mode) and i.size == 3
		else [unknown]
	out

# the values of `from` added to `into`: whether it changed
fn mergeInto(mut into {str: i64[]}, from {str: i64[]}):
	changed = false
	for r, values in from:
		list = (into.get(r) ?? []).copy()
		if not (r in into): changed = true
		for v in values:
			if not (v in list):
				list.push(v)
				changed = true
		into[r.copy()] = list
	changed

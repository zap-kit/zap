# A function of the cartridge as a Zap function over the cpu module's registers and the console's
# memory. One without jumps inside it is its statements in order; any other is a loop over a match
# of its labels (code's keys), each arm the instructions from that label to the next. Each
# instruction first polls once the console has an interrupt due (entered there), then runs its bus
# cycles (cycles.zap) with what it does.
#
# A call pushes its return address and calls the function; the function's return pulls it into
# cpu.ret, and the caller goes on when it is the address after the call, else returns too (a
# return past the function that made it, until the one it returns to). A jump to another function
# calls it and returns, the address it returned to going up the same way, or on at a label of
# this function where a phk and pea pushed it.

# a function's name: f, its address, the widths it starts in
pub fn functionName(k i64) str:
	w = widthsOf(k)
	"f{addressOf(k):06x}{"e" if w.e else ""}{"m" if w.m else ""}{"x" if w.x else ""}"

# the text of one function as it is written
pub type FnText:
	lines str[]
	temps i64   # the temporaries named so far
	dispatched bool   # a loop over a match of its labels, else straight statements
	patches {i64: Patch}   # by the address of the instruction each changes (game.zap)
	name str
	returnText str = "return"   # how the code it is in leaves (the interpreter's give `cpu.leaving`)

	fn put(depth i64, line str):
		lines.push("{"\t".repeat(depth)}{line}")

	fn temp(prefix str):
		temps += 1
		"{prefix}{temps}"

	# One instruction: its flow here, what it does in emitops; a branch taken costs an internal cycle
	# more (two in emulation mode across a page).
	fn instr(depth i64, p Program, f Function, i Instr, live i64):
		if i.name in conditionalBranches:
			self.put(depth, "if {conditionText(i.name)}:")
			self.takeBranch(depth + 1, p, f, i)
			return
		match i.name:
			"bra": self.takeBranch(depth, p, f, i)
			"brl": self.goTo(depth, p, f, i.target(), i.widths)
			"jmp", "jml", "jsr", "jsl":
				if i.mode == "w" or i.mode == "l":
					if i.name == "jsr" or i.name == "jsl":
						self.call(depth, p, f, i)
					else:
						self.goTo(depth, p, f, i.jumpTargetOf(), i.widths)
				else:
					self.indirect(depth, p, f, i)
			"rts":
				self.put(depth, "cpu.returnShort({hex(i.bank(), 2)}, {i.widths.widthBits()})")
				self.put(depth, "console.idle()")
				self.put(depth, "return")
			"rtl":
				self.put(depth, "cpu.returnLong({i.widths.widthBits()})")
				self.put(depth, "return")
			"rti":
				self.put(depth, "cpu.returnInterrupt()")
				self.put(depth, "return")
			"plp":
				self.put(
					depth,
					"if cpu.pullStatus({f.afterOf(i.keyOf()).statusWidths()}, {i.nextText()}):"
				)
				self.leave(depth + 1, f)
			_: self.operation(depth, i, live)

	# the lines the instruction's patch adds before it (game.zap: RetryBefore)
	mut fn patchedBefore(depth i64, f Function, i Instr):
		if self.patches.get(i.at) is RetryBefore(_, _, condition, label):
			k = key(label, i.widths)
			if not (k in f.index): fail("patch table: no label 0x{label:06X} in {self.name}")
			self.put(depth, "if {condition}:")
			self.put(depth + 1, "pc = {hex(k, 8)}")
			self.put(depth + 1, "continue")

	# the lines its patch adds after it (After)
	mut fn patchedAfter(depth i64, i Instr):
		if self.patches.get(i.at) is After(_, _, added):
			for line in added:
				self.put(depth, line)

	mut fn takeBranch(depth i64, p Program, f Function, i Instr):
		self.put(depth, "console.idle()")
		if i.crossesPage(): self.put(depth, "console.idle()")
		self.goTo(depth, p, f, i.target(), i.widths)

	mut fn goTo(depth i64, p Program, f Function, at i64, w Widths):
		k = key(at, w)
		if k in f.index:
			self.put(depth, "pc = {hex(k, 8)}")
			self.put(depth, "continue")
			return
		self.tailCall(depth, p, f, at, w)

	mut fn tailCall(depth i64, p Program, f Function, at i64, w Widths):
		self.put(depth, p.callText(at, w))
		self.leave(depth, f)

	# a return to where cpu.ret says: on at a label a phk and pea made, else out of the function
	mut fn leave(depth i64, f Function):
		for k in f.returns.keys().sorted():
			self.put(depth, "if cpu.ret == {hex(addressOf(k), 6)}:")
			self.put(depth + 1, "pc = {hex(k, 8)}")
			self.put(depth + 1, "continue")
		self.put(depth, "return")

	# the return address a call pushes: the program bank for a long one (then an internal cycle and
	# its last fetch), the address of the call's last byte
	mut fn pushReturn(depth i64, i Instr):
		if i.name == "jsl":
			self.put(depth, "cpu.push8({i.bankByteText()})")
			self.put(depth, "console.idle()")
			self.put(depth, "console.fetch(1, {i.atText()})")
		self.put(depth, "cpu.push16({"u16.wrap(nextAt - 1)" if i.symbolic else hex((i.next() - 1) & 0xFFFF, 4)})")

	# A call returned: past this function, it leaves too; in other widths than the flow assumed (a
	# function that returns in widths of its own), the code after the call goes on interpreted.
	mut fn afterCall(depth i64, f Function, i Instr):
		self.put(depth, "if cpu.ret != {hex(i.next(), 6)}:")
		self.leave(depth + 1, f)
		w = f.afterOf(i.keyOf()).widthBits()
		self.put(depth, "if cpu.widthsNow != {w} and cpu.goOnInterpreted({hex(i.next(), 6)}):")
		self.leave(depth + 1, f)

	mut fn call(depth i64, p Program, f Function, i Instr):
		self.pushReturn(depth, i)
		self.put(depth, p.callText(i.jumpTargetOf(), i.widths))
		self.afterCall(depth, f, i)

	# A jump or a call through memory: the address read, then a match over the cases the cfg's
	# dispatch names, any other through the dispatcher.
	mut fn indirect(depth i64, p Program, f Function, i Instr):
		calls = i.name == "jsr"
		t = self.indirectTargetLines(depth, i)
		fallback = "cpu.go({t}, {i.widths.widthBits()})"
		if f.dispatches.get(i.at) is d:
			self.put(depth, "match {t}:")
			seen {i64: bool} = {}
			for c in d.targets:
				if c in seen: continue
				seen[c] = true
				k = key(c, i.widths)
				if not calls and not d.calls and k in f.index:
					self.put(depth + 1, "{hex(c, 6)}:")
					self.put(depth + 2, "pc = {hex(k, 8)}")
					self.put(depth + 2, "continue")
				else:
					self.put(depth + 1, "{hex(c, 6)}: {p.callText(c, i.widths)}")
			self.put(depth + 1, "_: {fallback}")
		else:
			self.put(depth, fallback)
		if calls:
			self.afterCall(depth, f, i)
		else:
			self.leave(depth, f)

	# The lines that read where a jump or call through memory goes, into a temporary it names: a
	# jsr (a,x) pushes its return between its operand's fetches, then adds X.
	mut fn indirectTargetLines(depth i64, i Instr):
		t = self.temp("t")
		if i.name == "jsr":
			self.pushReturn(depth, i)
			self.put(depth, "console.fetch(1, {i.atText()})")
			self.put(depth, "console.idle()")
		self.put(depth, "{t} u32 = {i.indirectTarget()}")
		t

# the address a jump or call through memory reads, as the instruction's mode makes it
fn indirectTarget(i Instr):
	bank = "(at & 0xFF_0000)" if i.symbolic else hex(i.at & 0xFF_0000, 6)
	v = i.valueText()
	match i.mode:
		"(w,x)": "{bank} | u32(cpu.read16In({bank}, {v} + u32(cpu.x)))"
		"(w)": "{bank} | u32(cpu.readData16Bank0({v}))"
		_: "cpu.read24Bank0({v})"

fn hex(v i64, digits i64):
	match digits:
		2: "0x{v:02X}"
		4: "0x{v:04X}"
		6: "0x{v:06X}"
		_: "0x{v:08X}"

# the first instruction of each run that no jump lands inside: a label, one the instruction
# before does not go on to, or one an instruction elsewhere goes on to (a sep or rep reached in
# two widths)
fn blockStarts(f Function):
	starts bool[] = zeros(f.instrs.len)
	for k, i in f.instrs:
		if k == 0 or keyOf(i) in f.labels:
			starts[k] = true
			continue
		before = f.instrs[k - 1]
		starts[k] = not before.fallsThrough() or
			key(before.next(), f.afterOf(before.keyOf())) != keyOf(i)
	for k, i in f.instrs:
		if not i.fallsThrough(): continue
		if f.index.get(key(i.next(), f.afterOf(i.keyOf()))) is n and n != k + 1: starts[n] = true
	starts

# the labels a jump reaches from an instruction at or after them: the heads of loops
fn loopHeads(f Function):
	out {i64: bool} = {}
	for i in f.instrs:
		for k in f.successorKeys(i):
			if k in f.index and addressOf(k) <= i.at and k != key(i.next(), f.afterOf(i.keyOf())):
				out[k] = true
	out

# The Zap text of the function.
pub fn emitFunction(p Program, f Function) str[]:
	live = f.liveAfter()
	starts = f.blockStarts()
	heads = f.loopHeads()
	dispatched = starts.count(true) > 1 or f.instrs[0].keyOf() != f.entryKey() or
		f.entryKey() in heads
	e = FnText(
		lines = [],
		temps = 0,
		dispatched,
		patches = p.patches.copy(),
		name = functionName(f.entryKey())
	)
	depth = 4 if dispatched else 1
	k = 0
	while k < f.instrs.len:
		start = k
		k += 1
		while k < f.instrs.len and not starts[k]:
			k += 1
		first = f.instrs[start].keyOf()
		if dispatched: e.put(3, "{hex(first, 8)}:")
		for j in start..k:
			i = f.instrs[j]
			e.put(
				depth,
				"if console.cycles >= console.eventDue and cpu.poll({hex(i.at, 6)}, {i.widths.statusWidths()}): return"
			)
			for line in i.leadCycles():
				e.put(depth, line)
			e.patchedBefore(depth, f, i)
			e.instr(depth, p, f, i, live[j])
			e.patchedAfter(depth, i)
		last = f.instrs[k - 1]
		if not last.fallsThrough(): continue
		next = key(last.next(), f.afterOf(last.keyOf()))
		if next in f.index:
			e.put(depth, "pc = {hex(next, 8)}")
		else:
			e.tailCall(depth, p, f, addressOf(next), widthsOf(next))
	out = ["fn {e.name}():", "	if cpu.tracing: cpu.entered({hex(addressOf(f.entryKey()), 6)})"]
	if dispatched:
		out.push("\tpc u32 = {hex(f.entryKey(), 8)}")
		out.push("\tloop:")
		out.push("\t\tmatch pc:")
	out.extend(e.lines)
	if dispatched:
		out.push("\t\t\t_:")
		out.push("\t\t\t\tcpu.noLabel(pc, \"{e.name}\")")
		out.push("\t\t\t\treturn")
	out

fn conditionText(name str):
	match name:
		"bcc": "not cpu.c"
		"bcs": "cpu.c"
		"beq": "cpu.z"
		"bne": "not cpu.z"
		"bmi": "cpu.n"
		"bpl": "not cpu.n"
		"bvc": "not cpu.v"
		_: "cpu.v"

# the function at the address called in the widths: by its name when the program has it, else
# through the dispatcher
fn callText(p Program, at i64, w Widths):
	k = key(at, w)
	if k in p.index: return "{functionName(k)}()"
	"cpu.go({hex(at, 6)}, {w.widthBits()})"

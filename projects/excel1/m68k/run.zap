# The 68000 run by interpreting its instructions where they lie in memory: each decoded and
# lowered once, then its steps run (cpu/interpret.zap). The translated code's reference, and a
# way to run code before it is translated.

import cpu

type Decoded:
	steps cpu.Step[]
	temps i64
	next u32
	at i64   # where it was decoded

pub mut pc u32 = 0
pub mut executed = 0
pub mut limit = -1   # the instructions to run before stopping, -1 for no limit
pub mut breakAt = -1   # an address to stop at
pub mut watchAt = -10   # an address whose writes are told
mut decoded Decoded[] = []
# by an even address's half: its instruction's index in decoded, -1 when not decoded
mut slots = fill(cpu.memSize / 2, i32(-1))
mut temporaries = fill(64, u32(0))
# the addresses of the last instructions run, a ring, and of the last jumps (from, to)
pub mut recent = fill(32, u32(0))
mut jumps = fill(64, u32(0))
mut jumpCount = 0
mut lastAt u32 = 0
mut lastNext u32 = 0

fn decodedIndex(at u32):
	key = i64(at & 0xFF_FFFF)
	if key >= cpu.memSize: return decodeNew(at)
	slot = i64(slots[key >> 1])
	if slot >= 0:
		if decoded[slot].at != key:
			cpu.stop("slot of {key:x} holds the instruction of {decoded[slot].at:x}")
		return slot
	index = decodeNew(at)
	slots[key >> 1] = i32(index)
	cpu.codePages[key >> 8] = true
	cpu.codePages[(key + 9).min(cpu.memSize - 1) >> 8] = true
	index

fn decodeNew(at u32):
	i = decode(cpu.mem, at & 0xFF_FFFF)
	steps, temps = i.lower(0)
	decoded.push(Decoded(steps, temps, next = at + u32(i.length), at = at & 0xFF_FFFF))
	decoded.len - 1

# forgets the instructions decoded in a range of memory (code loaded or changed there)
pub fn forgetDecoded(from i64, length i64):
	first = (from - 10).max(0) >> 1
	last = ((from + length) >> 1).min(slots.len)
	for i in first..last:
		slots[i] = -1

# a write to a page of decoded code: what was decoded there and just before it forgotten
pub fn codeWritten(at i64):
	if at >= watchAt - 3 and at < watchAt + 4:
		eprint("write at {at:x} from {pc:x}: {cpu.read32(u32(watchAt)):x}")
	page = at & ~255
	forgetDecoded(page, 256)

# Runs one instruction at pc.
pub fn step():
	if (pc & 0xFF_FFFF) >= cpu.memSize:
		rom = cpu.onRomCall
		pc = rom(pc)
		return
	index = decodedIndex(pc)
	d = decoded[index]
	if d.temps > temporaries.len: temporaries = zeros(d.temps * 2)
	recent[executed & 31] = pc
	if pc != lastNext:
		jumps[jumpCount & 63 & ~1] = lastAt
		jumps[(jumpCount & 63 & ~1) + 1] = pc
		jumpCount += 2
	lastAt = pc
	executed += 1
	next = d.next
	lastNext = next
	# a copy: the steps may run code that decodes more (a trap's hook)
	steps = d.steps.copy()
	match cpu.execute(steps, temporaries, 0):
		Next: pc = next
		Jump(target): pc = u32.wrap(target)
		JumpTo(address): pc = address
		Aline(word):
			trap = cpu.onAline
			pc = trap(word, next)
		Exception(vector):
			raise = cpu.onException
			pc = raise(vector, next)
		Stop(status): cpu.stop("STOP #{status:x} at {pc:x}")

# the recompiled code's turn at an address: it runs from there while its code holds the address,
# and gives the address it hands back at (the address itself when no recompiled code holds it)
pub mut recompiled fn(u32) u32 = (at): at

# Runs from `start` until the code goes to `stop` (a return address pushed by the caller): the
# recompiled code where it holds pc, the interpreter for the instruction it hands back at.
pub fn interpret(start u32, stop i64):
	pc = start
	while pc != stop:
		if executed == limit or pc == breakAt:
			eprint(stateText())
			cpu.stop("stopped after {executed} instructions at {pc:x}")
		run = recompiled
		pc = run(pc)
		step()

# the last instructions run, oldest first, and the registers
pub fn stateText() str:
	lines = []
	for k in 0..32:
		at = recent[(executed + k) & 31]
		i = decode(cpu.mem, at & 0xFF_FFFF)
		lines.push("  {at:06x}: {i.text()}")
	for k in 0..32:
		at = (jumpCount + 2 * k) & 63
		lines.push("  jump {jumps[at]:06x} -> {jumps[at + 1]:06x}")
	r = (0..8).map("d{it}={cpu.register(it):x}").join(" ")
	a = (0..8).map("a{it}={cpu.register(8 + it):x}").join(" ")
	cached = decoded[decodedIndex(pc)]
	lines.push("  cached at {pc:x}: next {cached.next:x} {cached.steps}")
	lines.push("  {r}")
	lines.push("  {a} sr={cpu.sr():x}")
	lines.join("\n")

# n instructions from `at` in memory, as text
pub fn listing(at i64, n i64) str:
	lines = []
	p = at
	loop n:
		i = decode(cpu.mem, p)
		lines.push("  {p:06x}: {i.text()}")
		p += i.length
	lines.join("\n")

# The A-line traps: the dispatch tables in memory (0x400 the Operating System's 256, 0xC00 the
# Toolbox's 512), each entry an address in the ROM's range until a program patches it, and the
# Toolbox written in Zap behind those addresses. An Operating System trap takes its arguments in
# registers (A0, D0) and gives its result in D0 (and A0 when bit 8 of its word is set), the flags
# set by D0's word; a Toolbox trap takes Pascal's: arguments pushed in order over the result's
# room, popped by the trap.

import cpu

osTableAt u32 = 0x400
toolTableAt u32 = 0xC00
pub romBase u32 = 0x40_0000
pub romSize u32 = 0x2_0000
osRomAt u32 = romBase + 0x1_0000   # where the ROM's routine for Operating System trap n "lies"
toolRomAt u32 = romBase + 0x1_1000   # and Toolbox trap n's
pub returnToZap u32 = romBase + 0x1_F000   # the address code returns to when Zap called it
osDispatchReturn u32 = romBase + 0x1_F004   # where a patched OS trap returns into the dispatcher

# what runs the machine's code from an address until it returns to returnToZap: the interpreter
# or the translated code, as the program chose
pub mut runCode fn(u32) = (_): pass

# Calls the code at `at` as a subroutine, from Zap: its return address pushed, run until it
# returns.
pub fn callCode(at u32):
	cpu.push32(returnToZap)
	run = runCode
	run(at)

# ---------- Pascal's arguments and results ----------

pub fn popWord() u32:
	cpu.pop16()

pub fn popInt() i64:
	i16.wrap(i64(cpu.pop16()))

pub fn popLong() u32:
	cpu.pop32()

# a BOOLEAN argument: a word with the value in its high byte
pub fn popBool() bool:
	cpu.pop16() & 0xFF00 != 0

pub fn resultLong(v u32):
	cpu.write32(cpu.a7, v)

pub fn resultWord(v i64):
	cpu.write16(cpu.a7, u32.wrap(v))

pub fn resultBool(b bool):
	cpu.write16(cpu.a7, 0x100 if b else 0)

# ---------- the dispatch ----------

# the trap's number in its table: 0-255 the Operating System's, 256 + n Toolbox trap n
fn trapIndex(word i64):
	if word & 0x800 != 0: return 256 + (word & 0x3FF)
	word & 0xFF

fn tableEntry(index i64):
	if index < 256: return osTableAt + u32(index * 4)
	toolTableAt + u32((index - 256) * 4)

fn romAddress(index i64):
	if index < 256: return osRomAt + u32(index * 4)
	toolRomAt + u32((index - 256) * 4)

pub fn initTrapTables():
	for i in 0..256 + 512:
		cpu.write32(tableEntry(i), romAddress(i))

# GetTrapAddress and SetTrapAddress: trap n of the table its word names
pub fn trapAddress(word i64) u32:
	cpu.read32(tableEntry(trapIndex(word)))

pub fn setTrapAddress(word i64, at u32):
	cpu.write32(tableEntry(trapIndex(word)), at)

pub mut trapCount = 0
pub mut traceTraps = false

# An A-line trap at the address before `next`: where the code goes on.
pub fn aline(word i64, next u32) u32:
	index = trapIndex(word)
	patched = cpu.read32(tableEntry(index))
	isAutoPop = word & 0xC00 == 0xC00
	if patched != romAddress(index):
		# a program's own routine: called as the ROM's would be, returning after the trap (or,
		# auto-popped, to the address under it)
		if index < 256:
			osFrame(next)
		elif not isAutoPop:
			cpu.push32(next)
		return patched
	back = cpu.pop32() if isAutoPop else next
	runTrap(word, index, back)

# The trap's Zap routine, run: where the code goes on (normally `back`).
fn runTrap(word i64, index i64, back u32):
	trapCount += 1
	if traceTraps: eprint("trap {word:x} {trapName(word)} from {back:x}")
	if index < 256:
		savedA0 = cpu.a0
		savedA1 = cpu.a1
		savedD1 = cpu.d1
		savedD2 = cpu.d2
		go = osTrap(index, word, back)
		if traceTraps:
			for zone in [cpu.read32(sysZoneAt), cpu.read32(applZoneAt)]:
				fault = zoneFault(zone)
				if fault != "": cpu.stop("after {trapName(word)}: zone {zone:x}: {fault}")
		if word & 0x100 == 0 and not returnsA0(index): cpu.a0 = savedA0
		cpu.a1 = savedA1
		cpu.d1 = savedD1
		cpu.d2 = savedD2
		cpu.setCcr(0)
		cpu.cn = cpu.d0 & 0x8000 != 0
		cpu.cz = cpu.d0 & 0xFFFF == 0
		return go
	toolTrap(index - 256, word, back)

# the Operating System traps whose results come in A0 whatever bit 8 says
fn returnsA0(index i64):
	match index:
		0x1A, 0x1E, 0x22, 0x26, 0x28, 0x46, 0x48, 0x55: true
		_: false

# The stack the ROM's dispatcher leaves under a patched Operating System trap, which patches read
# (Excel's end as the dispatcher does): the address after the trap, 4 bytes, A2, D2 and D1 saved,
# A1 and A0 saved, and the return into the dispatcher.
fn osFrame(next u32):
	cpu.push32(next)
	cpu.push32(0)
	cpu.push32(cpu.a2)
	cpu.push32(cpu.d2)
	cpu.push32(cpu.d1)
	cpu.push32(cpu.a1)
	cpu.push32(cpu.a0)
	cpu.push32(osDispatchReturn)

# a patched Operating System trap's return into the dispatcher: the registers back as it saved
# them (A0 kept as the routine left it), the flags of D0's word, on after the trap
fn osFrameEnd():
	cpu.pop32()
	cpu.a1 = cpu.pop32()
	cpu.d1 = cpu.pop32()
	cpu.d2 = cpu.pop32()
	cpu.a2 = cpu.pop32()
	cpu.pop32()
	cpu.setCcr(0)
	cpu.cn = cpu.d0 & 0x8000 != 0
	cpu.cz = cpu.d0 & 0xFFFF == 0
	cpu.pop32()

# A routine of the ROM called by its address (a trap's address taken with GetTrapAddress and
# called with JSR): its trap run, then a return to the address on the stack.
pub fn romCall(at u32) u32:
	if at == osDispatchReturn: return osFrameEnd()
	if at >= osRomAt and at < toolRomAt:
		index = i64(at - osRomAt) / 4
		osTrap(index, 0xA000 | index, 0)
		return cpu.pop32()
	if at >= toolRomAt and at < toolRomAt + 512 * 4:
		index = i64(at - toolRomAt) / 4
		back = cpu.pop32()
		return toolTrap(index, 0xA800 | index, back)
	cpu.stop("the code went to {at:x} in the ROM, which holds nothing there")
	0

# A Toolbox trap called as the ROM's own routines call it, through the trap table: a program's
# patch at the table's entry is called with the Pascal arguments, and true returned; false while
# the entry is still the ROM's, for the caller to do the work in Zap.
pub fn callPatched(word i64, args (u32, i64)[]) bool:
	at = trapAddress(word)
	if at == romAddress(trapIndex(word)): return false
	callPascal(at, args, 0)
	true

# what the machine was doing, for a stop's message: set by the program
pub mut describe fn() str = (): ""

pub fn unimplemented(word i64, back u32) u32:
	tell = describe
	eprint(tell())
	cpu.stop("trap {word:x} {trapName(word)} is not written yet (called before {back:x})")
	back

# An exception (TRAP, CHK, a division by zero, an illegal word): the program's handler in the
# vector table when it set one, else the machine stops.
pub fn exception(vector i64, next u32) u32:
	handler = cpu.read32(u32(vector * 4))
	if handler != 0:
		cpu.push32(next)
		cpu.push16(cpu.sr())
		return handler
	tell = describe
	eprint(tell())
	eprint("vectors: {(0..12).map("{cpu.read32(u32(it * 4)):x}").join(" ")}")
	cpu.stop("exception {vector} with no handler, before {next:x}")
	next

# A Pascal function of the machine's code called from Zap: room for its result (0, 2 or 4
# bytes), then its arguments (each a value and its size, 2 or 4) pushed in order; its result.
pub fn callPascal(at u32, args (u32, i64)[], resultSize i64) u32:
	if resultSize > 0: cpu.a7 -= u32(resultSize)
	for (v, size) in args:
		if size == 2:
			cpu.push16(v)
		else:
			cpu.push32(v)
	callCode(at)
	match resultSize:
		2: cpu.pop16()
		4: cpu.pop32()
		_: 0

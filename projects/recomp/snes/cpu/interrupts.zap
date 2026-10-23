# The interrupts as the recompiled code takes them: where it polls (an instruction's start, once the
# console has something due) or waits (WAI), the hardware brought up to now there and a due NMI or
# IRQ entered as a call of its handler, whose RTI returns to the code it interrupted.
#
# A handler may instead leave that code for good: DKC's NMI handlers reset the stack pointer, do
# the frame's work and end in a WAI loop of their own. The calls under the handler are then dead,
# so when such a handler waits, every function returns (cpu.ret is `unwinding`, each poll and wait
# answers true) up to `reset`, which waits there instead: the native stack stays as deep as one
# frame's work.
#
# A handler whose RTI goes elsewhere than the code it interrupted (a task switch: the handler
# swapped the stack, Zelda's and SMW's do) unwinds the same way, and `reset` goes on at the address
# the RTI took, in the widths it pulled.

import recomp.snes.console

# where the code goes on when an interrupt is entered (bank << 16 | pc) and the widths it runs in
# (the status register's M and X bits): what the interrupt pushes
mut resumeAt u32 = 0
mut resumeWidths u8 = 0x30

# the stack pointer after each interrupt entered and not returned from pushed its frame, the
# outermost first; whether a write of the stack pointer dropped the innermost's frame
mut interruptStacks u16[] = []
mut leftForGood = false
mut switched = false   # the unwinding goes on at resumeAt, no wait first

# cpu.ret while the functions return to `reset`: no address
pub unwinding u32 = 0xFFFF_FFFF

# The console powered on with the program's functions, then the reset vector's code entered in
# emulation mode, as the CPU starts; when a handler that left the code it interrupted waits, the
# wait goes on here.
pub fn reset(move given Hooks):
	hooks = given
	if args.hasFlag("--interpret"):
		hooks.call = never
		hooks.callExact = never
	traceFrom = i64.parse(args.option("--trace") ?? "") ?? -1
	tracing = traceFrom >= 0
	stepsFrom = i64.parse(args.option("--steps") ?? "") ?? -1
	console.pollsEach = stepsFrom >= 0
	console.powerOn()
	console.hooks = console.Hooks(nmi = enterNmi, irq = enterIrq, irqAllowed = irqEnabled)
	if not actOnState(): go(console.read16(0xFFFC), 7)   # a --load goes on from its state
	loop:
		if ret != unwinding:
			# a return past the reset code (an rts used as a jump): the code goes on there
			at = ret
			ret = 0
			interpret(at, widthsNow, false)
			continue
		at = resumeAt
		widths = resumeWidths
		ret = 0
		interruptStacks = []
		leftForGood = false
		if switched:
			switched = false
		else:
			console.waitForInterrupt()
			if ret == unwinding: continue
		interpret(at, 7 if e else u32(widths >> 4) & 3, false)

# `--interpret`: no translated function runs, the interpreter runs everything (its check: the
# routes played so match Mesen 2 as the translated code does)
fn never(at u32, widths u32) bool:
	false

# At an instruction's start (the code at `at`, in widths): the interrupt the cycles before saw
# entered. Whether the code returns, unwinding.
pub fn poll(at u32, widths u8) bool:
	resumeAt = at
	resumeWidths = widths
	if console.stateArmed:
		if actOnState(): return true
		if not console.isInterruptWanted(): return false   # polled for the state alone
	console.catchUp()
	if ret == unwinding: return true
	stepped(at)
	false

# WAI, the code going on at `at` once an interrupt has been entered. Whether the code returns,
# unwinding: a handler that left the code it interrupted is waiting.
pub fn wait(at u32, widths u8) bool:
	resumeAt = at
	resumeWidths = widths
	if leftForGood:
		ret = unwinding
		return true
	console.waitForInterrupt()
	ret == unwinding

# txs and tcs: a stack pointer above the innermost interrupt's frame drops it. Above the
# outermost's is not enough: the title's first NMI comes with the stack at 02FA, its handler moves
# it to 01FF and waits, and each NMI after, entered at 01FB, does the same; had they nested, the
# native stack would grow by a frame's work every frame.
pub fn setStack(to u16):
	s = to
	if not interruptStacks.isEmpty and to > interruptStacks[len - 1]:
		leftForGood = true

fn irqEnabled():
	not irqDisabled

fn enterNmi():
	interrupt(0xFFFA if e else 0xFFEA)

fn enterIrq():
	interrupt(0xFFFE if e else 0xFFEE)

# An interrupt: a read of the code it stops at and an internal cycle, the program bank, the
# address the code goes on at and the status pushed, the handler the vector names called once a
# halted CPU (a WAI's) has idled out; its RTI returns there, or the program unwinds and goes on
# where it returned (above).
fn interrupt(vector u32):
	if ret == unwinding: return
	enter(vector, resumeAt, resumeWidths, true)

# brk and cop at `at`, in the widths, their signature byte fetched: the interrupt they make, its
# RTI returning to the instruction after them. Whether the code returns, unwinding.
pub fn softwareInterrupt(at u32, cop bool, widths u8) bool:
	vector u32 = (0xFFF4 if cop else 0xFFFE) if e else (0xFFE4 if cop else 0xFFE6)
	enter(vector, (at & 0xFF_0000) | ((at + 2) & 0xFFFF), widths, false)
	ret == unwinding

# An interrupt's entry, the code going on at `at` in the widths once its handler returns: a
# hardware one first reads the code it stops and idles (a brk or cop has fetched its two bytes).
fn enter(vector u32, at u32, widths u8, hardware bool):
	before = ret
	if hardware:
		console.fetch(1, at)
		console.idle()
	if not e: push8(u8.wrap(at >> 16))
	push16(u16.wrap(at))
	push8(status(widths))
	irqDisabled = true
	decimal = false
	handler = readData16Bank0(vector)
	if console.isHalted(): console.haltedSteps()
	interruptStacks.push(s)
	go(handler, 7 if e else u32(widths >> 4) & 3)   # the widths of the code it stopped
	if ret == unwinding: return
	if ret != at:
		resumeAt = ret
		resumeWidths = u8((widthsNow << 4) & 0x30)
		switched = true
		ret = unwinding
		return
	interruptStacks.pop()
	ret = before
	resumeAt = at
	resumeWidths = widths

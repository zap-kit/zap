# The code no translated function covers, run an instruction at a time by the interpreter's
# functions (snes/interpret.zap writes them from the same translation): code the game writes into
# RAM, a target of a jump through memory the preparation never saw, a task an interrupt resumes in
# the middle of a function. At every instruction where a translated function starts in the widths
# the code is in, that function runs instead: the interpreter only covers the gaps.

import recomp.snes.console

# what an interpreted instruction gives when a return took the code past it (cpu.ret where)
pub leaving u32 = 0xFFFF_FFFE

# The widths (bits e, m, x) the code goes on in where the translation does not know them: set by
# every return, plp, rep, sep and xce, and by the interpreter.
pub mut widthsNow u32 = 7

# Runs the code at `at` in `widths`. Nested (called as a function by translated code): until a
# return goes past it, cpu.ret then where. Else (the code a task switch or a wait resumes, with
# no caller): on wherever the returns go, until the program unwinds.
pub fn interpret(at u32, widths u32, nested bool):
	pc = at
	w = widths
	native = not nested
	loop:
		if native and hooks.callExact(pc, w):
			if nested or ret == unwinding: return
			pc = ret
			w = widthsNow
			continue
		native = true
		if console.cycles >= console.eventDue and poll(pc, u8((w << 4) & 0x30)): return
		widthsNow = w
		next = hooks.step(pc, w)
		w = widthsNow
		if next != leaving:
			pc = next
			continue
		if nested or ret == unwinding: return
		pc = ret

# A call or jump the interpreted code makes: the function translated in those widths, else the
# code there interpreted.
pub fn goFrom(at u32, widths u32):
	if hooks.callExact(at, widths): return
	interpret(at, widths, true)

# A translated function's code from `next` on, run interpreted in the widths the code is really in
# (a call returned in others than the translation assumed): true, so the function leaves after.
pub fn goOnInterpreted(next u32) bool:
	interpret(next, widthsNow, true)
	true

# the widths the code an interrupt stopped runs in
fn currentWidths() u32:
	7 if e else u32(resumeWidths >> 4) & 3

# the `count` operand bytes after the opcode at `at`, little-endian, in its bank (no time: the
# fetches count it)
pub fn operandAt(at u32, count i64) u32:
	v u32 = 0
	for k in 0..count:
		v |= u32(console.read8((at & 0xFF_0000) | ((at + 1 + u32(k)) & 0xFFFF))) << u32(8 * k)
	v

# a branch's target in its bank: the offset (8 bits, 16 for brl and per) from the address after it
pub fn branchTarget(at u32, operand u32, size i64) u32:
	signBit = 0x8000 if size == 3 else 0x80
	signedOffset = (i64(operand & 0xFFFF) ^ signBit) - signBit
	(at & 0xFF_0000) | u32((i64(at) + size + signedOffset) & 0xFFFF)

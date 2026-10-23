# The ARM7TDMI's registers, as the recompiled functions read and write them: r0 to r14 (the
# program counter is where the code is, known when translating), the status register's control
# bits and the registers each mode banks. The flags live in each function (cpu.psr reads them).

pub mut r0 u32 = 0
pub mut r1 u32 = 0
pub mut r2 u32 = 0
pub mut r3 u32 = 0
pub mut r4 u32 = 0
pub mut r5 u32 = 0
pub mut r6 u32 = 0
pub mut r7 u32 = 0
pub mut r8 u32 = 0
pub mut r9 u32 = 0
pub mut r10 u32 = 0
pub mut r11 u32 = 0
pub mut r12 u32 = 0
pub mut r13 u32 = 0
pub mut r14 u32 = 0

# the mode (bits 0 to 4), Thumb (5), FIQ and IRQ disabled (6, 7)
pub mut control u32 = 0x1F
pub mut spsr u32 = 0

pub modeUser u32 = 0x10
pub modeIrq u32 = 0x12
pub modeSupervisor u32 = 0x13
pub modeSystem u32 = 0x1F
pub irqDisabled u32 = 0x80

# the banked registers of each mode, by its bank (0 user and system, 1 IRQ, 2 supervisor, 3 the
# others): r13, r14, spsr
mut bankedSp u32[4] = [0, 0, 0, 0]
mut bankedLr u32[4] = [0, 0, 0, 0]
mut bankedSpsr u32[4] = [0, 0, 0, 0]

fn bankOf(mode u32):
	match mode:
		0x10, 0x1F: 0
		0x12: 1
		0x13: 2
		_: 3

# The control bits written (msr cpsr_c): a change of mode puts the old mode's r13, r14 and spsr
# away and takes the new one's.
pub fn setControl(v u32):
	before = bankOf(control & 0x1F)
	after = bankOf(v & 0x1F)
	control = v & 0xFF
	if before == after: return
	bankedSp[before] = r13
	bankedLr[before] = r14
	bankedSpsr[before] = spsr
	r13 = bankedSp[after]
	r14 = bankedLr[after]
	spsr = bankedSpsr[after]

# the stack pointer of a mode other than the current one, as the BIOS sets them when it starts
pub fn setBankedSp(mode u32, v u32):
	if bankOf(mode) == bankOf(control & 0x1F):
		r13 = v
	else:
		bankedSp[bankOf(mode)] = v

# the status register of the flags and the control bits
pub fn psr(n bool, z bool, c bool, v bool) u32:
	(u32(1) << 31 if n else 0) | (u32(1) << 30 if z else 0) | (u32(1) << 29 if c else 0) |
		(u32(1) << 28 if v else 0) | control

# the saved status register written: the fields of the mask (c x s f as bits 0 to 3)
pub fn setSpsr(v u32, mask i64):
	keep u32 = 0
	for i in 0..4:
		if (mask >> i) & 1 == 0: keep |= u32(0xFF) << (8 * i)
	spsr = (spsr & keep) | (v & ~keep)

# 1 for a flag that is set, as the carry adds it
pub fn bit(c bool) u32:
	1 if c else 0

# the shifts by a register: its low byte, which may pass 31
pub fn shiftLeft(v u32, n u32) u32:
	0 if n >= 32 else v << n

pub fn shiftRight(v u32, n u32) u32:
	0 if n >= 32 else v >> n

pub fn shiftArithmetic(v i32, n u32) u32:
	u32(v >> n.min(31))

pub fn rotate(v u32, n u32) u32:
	v.rotateRight(i64(n & 31))

# the carry out of those shifts; a count of 0 keeps the carry
pub fn carriesLeft(v u32, n u32, c bool) bool:
	if n == 0: return c
	if n > 32: return false
	(v >> (32 - n)) & 1 == 1

pub fn carriesRight(v u32, n u32, c bool) bool:
	if n == 0: return c
	if n > 32: return false
	(v >> (n - 1)) & 1 == 1

pub fn carriesArithmetic(v u32, n u32, c bool) bool:
	if n == 0: return c
	if n >= 32: return v >> 31 == 1
	(v >> (n - 1)) & 1 == 1

pub fn carriesRotate(v u32, n u32, c bool) bool:
	if n == 0: return c
	(v >> ((n - 1) & 31)) & 1 == 1

# What the recompiled program gives the hardware: the function at an address (its key, bit 0 set
# for Thumb) called; false when there is none.
pub type Hooks:
	call fn(u32) bool
	stop fn(str) = stopHere   # the hardware's: the reason with what the game was doing

fn noCall(at u32):
	eprint("no function to call at 0x{at:08X}: the recompiled program has not started")
	false

fn stopHere(why str):
	fail(why)

pub mut hooks = Hooks(call = noCall)

# A return past the function that made it, to a caller further up (code that jumps into another
# function's frame, and returns from there): each function on the way returns, until the one
# called from that address.
pub mut unwind u32 = 0

# A jump out of a function without labels to `at`: the function there called, which must come
# back to where this one returns; no function there is a return further up.
pub fn far(at u32, entry u32):
	back = r14
	if not hooks.call(at): unwind = at
	if unwind != 0:
		if unwind | 1 == entry | 1: unwind = 0
		return
	if back | 1 != entry | 1:
		hooks.stop("the jump to 0x{at:08X} came back to 0x{back:08X}, not to where its function returns (0x{entry:08X})")

# the instruction at the address is undefined: no recompiled code runs it
pub fn undefinedAt(at i64):
	hooks.stop("an undefined instruction at 0x{at:08X}")

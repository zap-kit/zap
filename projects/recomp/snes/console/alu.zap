# The CPU's multiplier and divider (4202-4206, results 4214-4217) as the hardware runs them, one
# step a CPU cycle: a product in 8, a quotient in 16, a read before they end giving the partial
# result, a write while one runs not starting another (Mesen 2's AluMulDiv, step by step).

mut mulA u8 = 0xFF
mut dividend u16 = 0xFFFF
mut divResult u16 = 0       # 4214-4215: the quotient, and the multiplier's shifting operand
mut mulOrRemainder u16 = 0  # 4216-4217: the product, or the remainder
mut aluShift u32 = 0
mut multSteps = 0
mut divSteps = 0
mut aluCycle i64 = 0        # the CPU cycle the unit has run to

fn aluFields(mut f StateFile):
	mulA = f.byte(mulA)
	dividend = f.word(dividend)
	divResult = f.word(divResult)
	mulOrRemainder = f.word(mulOrRemainder)
	aluShift = f.long(aluShift)
	multSteps = f.int(multSteps)
	divSteps = f.int(divSteps)
	aluCycle = f.int(aluCycle)

# The steps due by now: a read lands a cycle earlier in its CPU cycle than a write.
fn aluRun(reading bool):
	now = cpuCycles - (1 if reading else 0)
	steps = now - aluCycle
	aluCycle = now
	while steps > 0 and (multSteps > 0 or divSteps > 0):
		steps -= 1
		if multSteps > 0:
			multSteps -= 1
			if divResult & 1 != 0: mulOrRemainder = u16.wrap(mulOrRemainder + aluShift)
			aluShift <<= 1
			divResult >>= 1
		if divSteps > 0:
			divSteps -= 1
			aluShift >>= 1
			divResult <<= 1
			if mulOrRemainder >= aluShift:
				mulOrRemainder = u16.wrap(mulOrRemainder - aluShift)
				divResult |= 1

fn aluRead(off u32):
	aluRun(true)
	match off:
		0x4214: u8.wrap(divResult)
		0x4215: u8.wrap(divResult >> 8)
		0x4216: u8.wrap(mulOrRemainder)
		_: u8.wrap(mulOrRemainder >> 8)

fn aluWrite(off u32, v u8):
	aluRun(true)
	running = divSteps > 0 or multSteps > 0   # one that ends on this cycle still blocks
	aluRun(false)
	match off:
		0x4202: mulA = v
		0x4203:
			mulOrRemainder = 0
			if not running:
				multSteps = 8
				divResult = (u16(v) << 8) | mulA
				aluShift = v
			elif divSteps == 0 and multSteps == 0:
				divResult = (u16(v) << 8) | mulA   # the last cycle's write: the operands only
		0x4204: dividend = (dividend & 0xFF00) | u16(v)
		0x4205: dividend = (dividend & 0xFF) | (u16(v) << 8)
		_:
			mulOrRemainder = dividend
			if not running:
				divSteps = 16
				aluShift = u32(v) << 16

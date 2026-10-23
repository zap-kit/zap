# A function of the image called as the Windows x64 convention calls it: the first four arguments
# in rcx, rdx, r8, r9 or xmm0..xmm3 by their place, the rest on the stack after the 32 bytes of
# home space, the stack 16-byte aligned at the call; the result in rax or xmm0. The run steps one
# instruction at a time (decoded once, cached by address) until the function returns to the
# address the call pushed, a stub asks the caller (Stop.Paused), the step budget is spent, or an
# instruction cannot run, which names its address and bytes.

pub type Arg:
	Int(v u64)
	Single(x f32)
	Double(x f64)

pub type Stop:
	Returned
	Paused(at u64)

# the return address of a call from outside: never mapped, so nothing runs there
pub returnAddress u64 = 0x7FFF_0000_0000

# the index in the cache of the instruction at rip, decoded once
fn instructionAt(mut m Machine) i64 ? str:
	if m.cacheAt.get(m.rip) is i: return i
	code = []
	for k in 0..15:
		code.push(u8.wrap(m.mem.read(m.rip + u64(k), 1)))
	if not m.mem.fault.isEmpty:
		m.mem.fault = ""
		if code.isEmpty: return "0x{m.rip:x}: no code"
	d = Instr(at = m.rip)
	try d.decodeInto(code)
	m.cacheAt[m.rip] = m.cache.len
	m.cache.push(d)
	m.cache.len - 1

fn exec(mut m Machine, d Instr):
	if d.sse: return m.execSse(d)
	m.execInteger(d)

# the stub at rip run, as a function that returns to its caller; Paused when it asks the caller
fn runStub(mut m Machine, s Stub) (Stop?) ? str:
	match s:
		Returns(rax, xmm0):
			m.regs[0] = rax
			m.setXmm(0, xmm0, 0)
		Pause: return .Paused(m.rip)
		Crt(name):
			if not m.runCrt(name): return "0x{m.rip:x}: the import {name} was called"
	m.jump(m.pop())
	none

# Runs from rip until the call returns or a stub pauses it.
pub fn run(mut m Machine) Stop ? str:
	loop:
		if m.rip == returnAddress: return Stop.Returned
		if m.branched:
			m.branched = false
			if m.stubs.get(m.rip) is s:
				if try m.runStub(s) is stop: return stop
				continue
		if m.steps >= m.budget: return "the budget of {m.budget} steps is spent at 0x{m.rip:x}"
		d = m.cache[try m.instructionAt()]
		if m.trace: print("{d.at:x}  {d.textOf()}")
		m.rip = d.at + u64(d.len)
		try m.exec(d)
		m.steps += 1
		if not m.mem.fault.isEmpty:
			why = m.mem.fault.copy()
			m.mem.fault = ""
			return "0x{d.at:x} {d.textOf()}: {why}"

# A paused stub's answer: rax and xmm0 set and the stub returned from; then `run` goes on.
pub fn answer(mut m Machine, rax u64, xmm0 u64):
	m.regs[0] = rax
	m.setXmm(0, xmm0, 0)
	m.jump(m.pop())

# The registers and stack set for a call of `address` with these arguments, the steps counted from 0.
pub fn prepareCall(mut m Machine, address u64, args Arg[]):
	slots = args.len.max(4)
	sp = stackTop - 0x100 - u64((8 * slots + 15) / 16 * 16)
	ints = [1, 2, 8, 9]
	for k, arg in args:
		bits = match arg:
			Int(v): v
			Single(x): x.toBits()
			Double(x): x.toBits()
		if k >= 4:
			m.mem.write(sp + u64(8 * k), 8, bits)
			continue
		match arg:
			Int: m.regs[ints[k]] = bits
			_: m.setXmm(k, bits, 0)
	m.regs[4] = sp
	m.push(returnAddress)
	m.jump(address)
	m.steps = 0

# Calls the function at `address` and runs it.
pub fn call(mut m Machine, address u64, args Arg[]) Stop ? str:
	m.prepareCall(address, args)
	m.run()

# the result as a single, a double, an integer
pub fn resultSingle(m Machine) f32:
	f32.fromBits(u32.wrap(m.lo(0)))

pub fn resultDouble(m Machine) f64:
	f64.fromBits(m.lo(0))

pub fn resultInt(m Machine) u64:
	m.regs[0]

# where machineOfCode puts its code
pub codeBase u64 = 0x40_0000_0000

# A machine of no image with `code` at codeBase, for code written by hand.
pub fn machineOfCode(code u8[]) Machine:
	m = machineFor(noImage())
	m.mem.open(codeBase, 0x1_0000)
	m.mem.put(codeBase, code)
	m

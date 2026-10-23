# Runs one function of a Windows x86-64 executable in the emulator (recomp/x64) and prints what it
# returns: rax, and xmm0 as a single and as a double. The arguments are given in their order, each
# an integer (rcx, rdx, r8, r9 by place, then the stack) or a float (xmm0..xmm3 by place):
#
#   zap run projects/recomp/tools/x64run.zap <exe> <address> [--int n]... [--float x]... [--double x]...
#       [--trace]          each instruction as it runs
#       [--disasm n]       the n instructions from the address, not run
#       [--budget n]       the instructions the run may take (1,000,000)
#
# e.g. zap run projects/recomp/tools/x64run.zap C:/tools/skyrim-input/SkyrimSE.exe 0x140aabb90 --float 1 --float 2

import recomp.x64

fn number(s str):
	if s.startsWith("0x"): return i64.parse(s) ?? fail("not a number: {s}")
	if s.startsWith("-0x"): return -(i64.parse(s[1..]) ?? fail("not a number: {s}"))
	i64.parse(s) ?? fail("not a number: {s}")

fn disassemble(mut m x64.Machine, at u64, count i64):
	pc = at
	loop count:
		code u8[] = m.mem.bytes(pc, 15)
		d = x64.decode(pc, code) ?? fail
		shown = x64.bytesText(code[..d.len])
		print("{pc:x}  {shown:<30} {d.textOf()}")
		pc += u64(d.len)

words = args
if words.len < 2:
	print("usage: x64run <exe> <address> [--int n]... [--float x]... [--double x]... [--trace] [--disasm n] [--budget n]")
	exit(2)
image = x64.openImage(words[0]) ?? fail
m = x64.machineFor(image)
address = u64(number(words[1]))
callArgs x64.Arg[] = []
k = 2
while k < words.len:
	w = words[k]
	match w:
		"--trace": m.trace = true
		"--int":
			k += 1
			callArgs.push(.Int(u64.wrap(number(words[k]))))
		"--float":
			k += 1
			callArgs.push(.Single(f32.parse(words[k]) ?? fail("not a float: {words[k]}")))
		"--double":
			k += 1
			callArgs.push(.Double(f64.parse(words[k]) ?? fail("not a float: {words[k]}")))
		"--budget":
			k += 1
			m.budget = number(words[k])
		"--disasm":
			k += 1
			m.disassemble(address, number(words[k]))
			exit(0)
		_: fail("unknown argument {w}")
	k += 1
stop = m.call(address, callArgs) ?? fail
if stop is Paused(at): fail("stopped at the stub at 0x{at:x}")
rax = m.resultInt()
print("rax  = 0x{rax:x} ({i64(rax)})")
print("xmm0 = 0x{m.lo(0):016x} (single {m.resultSingle()}, double {m.resultDouble()})")
print("steps {m.steps}")

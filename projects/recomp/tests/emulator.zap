# The x86-64 emulator (recomp/x64) on code written by hand and on its float semantics: the decoder
# against Intel's syntax, the calling convention, the stack, the stubs, the step budget and the
# faults; the SSE results by the manual's rules. Nothing here needs an executable.

import recomp.x64

# the text of the instruction of these bytes at `at`, or its error
fn textAt(at u64, code u8[]):
	padded = code.copy()
	while padded.len < 15:
		padded.push(0)
	match x64.decode(at, padded):
		error: error
		d: d.textOf()

test "instructions decode as Intel's syntax writes them":
	expect textAt(0, [0x48, 0x83, 0xEC, 0x18]) == "sub rsp, 0x18"
	expect textAt(0x1_40aa_bbb7, [0xF3, 0x0F, 0x58, 0x1D, 0x41, 0xD8, 0xD7, 0x00]) ==
		"addss xmm3, dword ptr [0x141829400]"
	expect textAt(0, [0x0F, 0x29, 0x34, 0x24]) == "movaps xmmword ptr [rsp], xmm6"
	expect textAt(0, [0x48, 0xC7, 0x84, 0x24, 0x98, 0, 0, 0, 0, 0, 0, 0]) ==
		"mov qword ptr [rsp + 0x98], 0x0"
	expect textAt(0, [0x66, 0x0F, 0x3A, 0x0A, 0xC1, 0x09]) == "roundss xmm0, xmm1, 0x9"
	expect textAt(0, [0x41, 0x8B, 0x44, 0x24, 0x08]) == "mov eax, dword ptr [r12 + 0x8]"
	expect textAt(0, [0x0F, 0xB6, 0xC1]) == "movzx eax, cl"
	expect textAt(0, [0x66, 0x0F, 0xFE, 0xC1]) == "paddd xmm0, xmm1"
	expect textAt(0, [0xF3, 0x48, 0x0F, 0x2C, 0xC0]) == "cvttss2si rax, xmm0"

test "an instruction the decoder does not know is refused with its address and bytes":
	expect textAt(0x1000, [0x0F, 0x0E]) == "0x1000: unknown instruction 0f 0e 00 00"
	expect "VEX" in textAt(0x1000, [0xC5, 0xF8, 0x77])

# the function of these bytes called with these arguments: rax (signed), or the error
fn ran(code u8[], args x64.Arg[]):
	m = x64.machineOfCode(code)
	match m.call(x64.codeBase, args):
		error: error
		_: "{i64(m.resultInt())}"

test "integer code runs: addresses, loops and flags, division, the stack's arguments":
	# lea eax, [rcx + rdx*2 + 5]
	expect ran([0x8D, 0x44, 0x51, 0x05, 0xC3], [.Int(3), .Int(4)]) == "16"
	# the sum 1..n by a loop counting down
	sum u8[] = [0x31, 0xC0, 0x85, 0xC9, 0x7E, 0x06, 0x01, 0xC8, 0xFF, 0xC9, 0x75, 0xFA, 0xC3]
	expect ran(sum, [.Int(10)]) == "55"
	expect ran(sum, [.Int(u64.wrap(-3))]) == "0"
	# mov rax, rcx; cqo; idiv r8
	expect ran(
		[0x48, 0x89, 0xC8, 0x48, 0x99, 0x49, 0xF7, 0xF8, 0xC3],
		[.Int(u64.wrap(-7)), .Int(0), .Int(2)]
	) ==
		"-3"
	# mov eax, [rsp + 0x28]: the fifth argument
	expect ran([0x8B, 0x44, 0x24, 0x28, 0xC3], [.Int(1), .Int(2), .Int(3), .Int(4), .Int(99)]) ==
		"99"

test "SSE code runs on the argument registers":
	# mulss xmm0, xmm1; addss xmm0, xmm2
	m = x64.machineOfCode([0xF3, 0x0F, 0x59, 0xC1, 0xF3, 0x0F, 0x58, 0xC2, 0xC3])
	_ = m.call(x64.codeBase, [.Single(1.5), .Single(2.0), .Single(0.25)]) ?? fail
	expect m.resultSingle() == 3.25

test "a call reaches a stub, which returns or pauses for the caller":
	# call codeBase + 0x100; add eax, 1; ret
	code u8[] = [0xE8, 0xFB, 0x00, 0x00, 0x00, 0x83, 0xC0, 0x01, 0xC3]
	m = x64.machineOfCode(code)
	m.stubs[x64.codeBase + 0x100] = .Returns(41, 0)
	_ = m.call(x64.codeBase, []) ?? fail
	expect m.resultInt() == 42
	m.stubs[x64.codeBase + 0x100] = .Pause
	stop = m.call(x64.codeBase, []) ?? fail
	expect stop is Paused(at) and at == x64.codeBase + 0x100
	m.answer(7, 0)
	_ = m.run() ?? fail
	expect m.resultInt() == 8

test "a run stops at its budget and at memory nothing maps":
	expect ran([0xEB, 0xFE], []) == ("the budget of 1000000 steps is spent at 0x4000000000")
	# mov rax, [0x10]
	expect ran([0x48, 0x8B, 0x04, 0x25, 0x10, 0, 0, 0, 0xC3], []) ==
		("0x4000000000 mov rax, qword ptr [0x10]: read of unmapped memory at 0x10")

test "a NaN operand gives the first source's NaN, quiet; an invalid operation the default NaN":
	quiet u32 = 0x7FC0_0001
	signaling u32 = 0x7F80_0001
	one = f32(1.0).toBits()
	infinity u32 = 0x7F80_0000
	expect x64.arith32(x64.opAdd, quiet, one) == quiet
	expect x64.arith32(x64.opMul, one, signaling) == quiet
	expect x64.arith32(x64.opSub, signaling, 0x7FC0_0002) == quiet
	expect x64.arith32(x64.opSub, infinity, infinity) == x64.defaultNaN32
	expect x64.arith32(x64.opSqrt, 0, f32(-4.0).toBits()) == x64.defaultNaN32
	expect x64.arith64(x64.opDiv, 0, 0) == x64.defaultNaN64

test "min and max give the second operand for a NaN or two zeros":
	one = f32(1.0).toBits()
	nan u32 = 0x7FC0_0000
	negativeZero u32 = 0x8000_0000
	expect x64.arith32(x64.opMin, nan, one) == one
	expect x64.arith32(x64.opMin, one, nan) == nan
	expect x64.arith32(x64.opMin, negativeZero, 0) == 0
	expect x64.arith32(x64.opMax, 0, negativeZero) == negativeZero

test "conversions to integers round to nearest even or truncate, the indefinite out of range":
	expect x64.toInteger(2.5, 4, false) == 2
	expect x64.toInteger(3.5, 4, false) == 4
	expect x64.toInteger(-2.5, 4, false) == 0xFFFF_FFFE
	expect x64.toInteger(-2.7, 8, true) == ~u64(1)
	expect x64.toInteger(3e9, 4, true) == 0x8000_0000
	expect x64.toInteger(0.0 / 0.0, 8, true) == u64(1) << 63

test "an integer to a single rounds once":
	expect x64.intToSingle(16_777_217) == 0x4B80_0000
	expect x64.intToSingle(9_223_372_036_854_775_807) == 0x5F00_0000
	# halfway plus a bit lost if it went through a double first
	expect x64.intToSingle((1 << 62) + (1 << 38) + 1) == 0x5E80_0001

test "rounding keeps the sign of a zero":
	expect x64.roundTo(2.5, 0) == 2.0
	expect x64.roundTo(-0.5, 0).toBits() == (-0.0).toBits()
	expect x64.roundTo(0.5, 2) == 1.0
	expect x64.roundTo(-0.3, 2).toBits() == (-0.0).toBits()
	expect x64.roundTo(-2.5, 1) == -3.0

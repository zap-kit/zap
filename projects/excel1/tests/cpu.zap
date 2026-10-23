# The 68000's instructions run through their steps (the interpreter of the common form): results
# and flags as the 68000 Programmer's Reference Manual gives them.

import cpu
import m68k

origin u32 = 0x1000

# runs the code of the hex words from origin to its end, the stack at 0x8000
fn run(words str):
	n = words.len / 2
	for i in 0..n:
		cpu.mem[origin + i] = u8(words[2 * i].hexValue() * 16 + words[2 * i + 1].hexValue())
	m68k.forgetDecoded(origin, n)
	cpu.a7 = 0x8000
	m68k.interpret(origin, origin + n)

# the flags as text: X N Z V C, a letter where set, a dash where not
fn flags():
	c = cpu.ccr()
	out = []
	for (i, letter) in [(4, 'x'), (3, 'n'), (2, 'z'), (1, 'v'), (0, 'c')]:
		out.push(letter if c >> i & 1 != 0 else '-')
	str(out)

fn reset():
	cpu.d0 = 0
	cpu.d1 = 0
	cpu.d2 = 0
	cpu.d3 = 0
	cpu.a0 = 0
	cpu.a1 = 0
	cpu.a6 = 0
	cpu.setCcr(0)

test "moves set N and Z, clear V and C":
	reset()
	cpu.setCcr(0x13)
	run("70ff")   # moveq #-1,d0
	print("{cpu.d0:x} {flags()}")
	run("7000")
	print("{cpu.d0:x} {flags()}")
	prints """
		ffffffff xn---
		0 x-z--
		"""

test "add and sub at each size: carry, overflow, extend":
	reset()
	cpu.d0 = 0x1234_7FFF
	cpu.d1 = 1
	run("d041")   # add.w d1,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0
	run("5300")   # subq.b #1,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 5
	cpu.d1 = 7
	run("b081")   # cmp.l d1,d0
	print("{cpu.d0:x} {flags()}")
	prints """
		12348000 -n-v-
		ff xn--c
		5 xn--c
		"""

test "addx and negx keep a zero result's Z only":
	reset()
	cpu.d0 = 0xFFFF_FFFF
	cpu.d1 = 0
	cpu.setCcr(0x14)   # X and Z set
	run("d380")   # addx.l d0,d1: 0 + ffffffff + 1
	print("{cpu.d1:x} {flags()}")
	cpu.d2 = 5
	cpu.setCcr(0)
	run("4482")   # neg.l d2
	print("{cpu.d2:x} {flags()}")
	prints """
		0 x-z-c
		fffffffb xn--c
		"""

test "shifts and rotations":
	reset()
	cpu.d0 = 0x4001
	run("e548")   # lsl.w #2,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0x8000_0001
	run("e280")   # asr.l #1,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0x81
	run("e318")   # rol.b #1,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0x8000
	cpu.setCcr(0x10)
	run("e350")   # roxl.w #1,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0x4000
	run("e340")   # asl.w #1,d0: the sign changes
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0x1234
	cpu.d1 = 0
	run("e368")   # lsl.w d1,d0: by zero
	print("{cpu.d0:x} {flags()}")
	prints """
		4 x---c
		c0000000 xn--c
		3 x---c
		1 x---c
		8000 -n-v-
		1234 -----
		"""

test "multiplications and divisions":
	reset()
	cpu.d0 = 105
	run("80fc000a")   # divu.w #10,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = u32.wrap(-7)
	run("81fcfffd")   # divs.w #-3,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0x10_0000
	run("80fc0001")   # divu.w #1,d0: overflows
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 3
	run("c1fcfffe")   # muls.w #-2,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0xFFFF
	run("c0fc0002")   # mulu.w #2,d0
	print("{cpu.d0:x} {flags()}")
	prints """
		5000a -----
		ffff0002 -----
		100000 ---v-
		fffffffa -n---
		1fffe -----
		"""

test "the decimal instructions add and subtract binary-coded digits and set the flags":
	reset()
	cpu.d0 = 0x19
	cpu.d1 = 0x28
	run("c101")   # abcd d1,d0
	print("{cpu.d0:x} {flags()}")
	cpu.d0 = 0x10
	cpu.d1 = 0x01
	cpu.setCcr(0)
	run("8101")   # sbcd d1,d0
	print("{cpu.d0:x} {flags()}")
	prints """
		47 -----
		9 -----
		"""

test "movem to the stack and back, words sign-extended":
	reset()
	cpu.d0 = 1
	cpu.d1 = 2
	cpu.a0 = 3
	run("48e7c0804cdf0301")   # movem.l d0-d1/a0,-(a7); movem.l (a7)+,d0/a0-a1
	print("{cpu.d0:x} {cpu.a0:x} {cpu.a1:x} {cpu.a7:x}")
	cpu.d0 = 0x8001
	run("48a780004c9f0002")   # movem.w d0,-(a7); movem.w (a7)+,d1
	print("{cpu.d1:x} {cpu.a7:x}")
	prints """
		1 2 3 8000
		ffff8001 8000
		"""

test "a dbf loop, link and unlk, bsr and rts":
	reset()
	run("7003528151c8fffc")   # moveq #3,d0; addq.l #1,d1; dbf d0,-4
	print("{cpu.d0:x} {cpu.d1}")
	cpu.a6 = 0x1234
	run("4e56fff02c0e4e5e")   # link a6,#-16; move.l a6,d6; unlk a6
	print("{cpu.a6:x} {cpu.d6:x} {cpu.a7:x}")
	run("61047405600476074e75")   # bsr +4; moveq #5,d2; bra +4; moveq #7,d3; rts
	print("{cpu.d2} {cpu.d3} {cpu.a7:x}")
	prints """
		ffff 4
		1234 7ffc 8000
		5 7 8000
		"""

test "bits, ext, swap, scc":
	reset()
	cpu.d0 = 0x80
	run("4880")   # ext.w d0
	print("{cpu.d0:x} {flags()}")
	run("48c0")   # ext.l d0
	run("4840")   # swap d0
	print("{cpu.d0:x} {flags()}")
	cpu.d1 = 0
	run("08c1001f")   # bset #31,d1
	print("{cpu.d1:x} {flags()}")
	run("0801001f")   # btst #31,d1
	print(flags())
	run("57c2")   # seq d2
	print("{cpu.d2:x}")
	prints """
		ff80 -n---
		ff80ffff -n---
		80000000 -nz--
		-n---
		0
		"""

test "suba from the stack pointer":
	reset()
	run("203c00000b789fc0224f")   # move.l #$b78,d0; suba.l d0,a7; movea.l a7,a1
	print("{cpu.d0:x} {cpu.a7:x} {cpu.a1:x}")
	prints "b78 7488 7488"

test "addi and andi of longs":
	reset()
	cpu.d1 = 0x4_6D40
	run("06810000007c0281fffffff0")   # addi.l #$7c,d1; andi.l #$fffffff0,d1
	print("{cpu.d1:x}")
	prints "46db0"

fn fakeTrap(word i64, next u32):
	saved = cpu.d1
	cpu.a0 = 0x4_6D40
	cpu.d1 = saved
	next

test "a trap between register moves and arithmetic":
	reset()
	cpu.d1 = 0x73E2_0000
	cpu.onAline = fakeTrap
	run("a11e2448220a06810000007c0281fffffff0")   # trap; movea.l a0,a2; move.l a2,d1; addi; andi
	print("{cpu.d1:x}")
	prints "46db0"

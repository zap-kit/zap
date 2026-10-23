# The translator on code written here: a function's flow, its jump table, the flags it computes
# and the Zap it is written as.

import arm
import translate

# a cartridge of the halfwords (and words) from 0x08000100, zeros before
fn cartridge(halfwords u16[]):
	rom u8[] = zeros(0x100)
	for h in halfwords:
		rom.pushU16le(h)
	rom.extend(zeros(16))
	translate.Code(rom, decoder = arm.newDecoder())

# a switch on r0 through a table of three cases, as agbcc writes it, and its default
switchCode u16[] = [
	0x2802,   # cmp r0, #2
	0xD813,   # bhi 0x0800012C
	0x0080,   # lsls r0, r0, #2
	0x4902,   # ldr r1, [pc, #8]: the table's address
	0x1840,   # adds r0, r0, r1
	0x6800,   # ldr r0, [r0]
	0x4687,   # mov pc, r0
	0x0000,
	0x0114,
	0x0800,   # the table's address
	0x0120,
	0x0800,
	0x0124,
	0x0800,
	0x0128,
	0x0800,   # the table
	0x2001,
	0x4770,   # 0x120: movs r0, #1; bx lr
	0x2002,
	0x4770,
	0x2003,
	0x4770,
	0x4770   # 0x12C: bx lr
]

test "a switch's table gives its cases, each a label":
	code = cartridge(switchCode)
	f = code.explore(0x0800_0100, true, {})
	print("{f.instrs.map("{.at - 0x0800_0100:X}").join(" ")}, clean {f.isClean}")
	expect (f.tables.get(0x0800_010C) ?? []) == [134_218_016, 134_218_020, 134_218_024]
	expect f.labels.keys().sorted().map("{it:X}") ==
		["8000100", "8000120", "8000124", "8000128", "800012C"]
	prints """
		0 2 4 6 8 A C 20 22 24 26 28 2A 2C, clean true
		"""

test "only the flags read are computed":
	# push {r4, lr}; movs r0, #1; cmp r0, #0; beq 0x0800010C; adds r0, r0, #1; pop {r4, pc}
	code = cartridge([0xB510, 0x2001, 0x2800, 0xD000, 0x3001, 0xBD10])
	f = code.explore(0x0800_0100, true, {})
	lines = code.emitFunction({}, f, false)
	flags = ["nf", "zf", "cf", "vf"]
	expect lines.map(str(.trimmed())).filter(l: flags.any(l.startsWith(it))) ==
		["zf = false", "zf = t2 == 0"]
	expect lines[0] == "fn t08000100():"

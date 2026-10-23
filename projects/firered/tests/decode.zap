# The decoder against encodings whose assembly is known (the ARM7TDMI's manual, GNU as).

import arm

decoder = arm.newDecoder()

fn thumbText(first i64, second i64):
	decoder.decodeThumb(u16(first), u16(second), 0x0800_0000).text()

fn armText(word i64):
	decoder.decodeArm(u32(word), 0x0800_0000).text()

test "thumb instructions read as their assembly" for (first, second, text) in [
	(0x4770, 0, "bx lr"),
	(0xB510, 0, r"stmdb sp!, {r4, lr}"),
	(0xBD10, 0, r"ldmia sp!, {r4, pc}"),
	(0xB500, 0, r"stmdb sp!, {lr}"),
	(0x2001, 0, "movs r0, #1"),
	(0x0089, 0, "movs r1, r1, lsl #2"),
	(0x0E00, 0, "movs r0, r0, lsr #24"),
	(0x0800, 0, "movs r0, r0, lsr #32"),
	(0x1C08, 0, "adds r0, r1, #0"),
	(0x1888, 0, "adds r0, r1, r2"),
	(0x4240, 0, "rsbs r0, r0, #0"),
	(0x4348, 0, "muls r0, r1, r0"),
	(0x4684, 0, "mov r12, r0"),
	(0x4801, 0, "ldr r0, [pc, #4]"),
	(0x5C08, 0, "ldrb r0, [r1, r0]"),
	(0x5E08, 0, "ldrsh r0, [r1, r0]"),
	(0x8848, 0, "ldrh r0, [r1, #2]"),
	(0x9001, 0, "str r0, [sp, #4]"),
	(0xA801, 0, "add r0, sp, #4"),
	(0xB082, 0, "sub sp, sp, #8"),
	(0xC80E, 0, r"ldmia r0!, {r1-r3}"),
	(0xD0FE, 0, "beq 0x08000000"),
	(0xE7FE, 0, "b 0x08000000"),
	(0xDF0B, 0, "swi #0xB"),
	(0xF000, 0xF802, "bl 0x08000008"),
	(0xF7FF, 0xFFFE, "bl 0x08000000"),
	(0xDE00, 0, "undefined"),
	(0xF800, 0, "undefined")
]:
	expect thumbText(first, second) == text

test "arm instructions read as their assembly" for (word, text) in [
	(0xE12F_FF1E, "bx lr"),
	(0xE3A0_0301, "mov r0, #0x4000000"),
	(0xE3A0_00FF, "mov r0, #0xFF"),
	(0xE281_0001, "add r0, r1, #1"),
	(0xE091_0102, "adds r0, r1, r2, lsl #2"),
	(0xE1A0_0231, "mov r0, r1, lsr r2"),
	(0xE1A0_0061, "mov r0, r1, rrx"),
	(0x0A00_0000, "beq 0x08000008"),
	(0xEBFF_FFFE, "bl 0x08000000"),
	(0xE59F_0004, "ldr r0, [pc, #4]"),
	(0xE5B1_0004, "ldr r0, [r1, #4]!"),
	(0xE491_0004, "ldr r0, [r1], #4"),
	(0xE751_0002, "ldrb r0, [r1, -r2]"),
	(0xE1D1_00B2, "ldrh r0, [r1, #2]"),
	(0xE1D1_00D1, "ldrsb r0, [r1, #1]"),
	(0xE1C1_00B0, "strh r0, [r1]"),
	(0xE92D_400F, r"stmdb sp!, {r0-r3, lr}"),
	(0xE8BD_400F, r"ldmia sp!, {r0-r3, lr}"),
	(0xE10F_0000, "mrs r0, cpsr"),
	(0xE14F_0000, "mrs r0, spsr"),
	(0xE129_F000, "msr cpsr_fc, r0"),
	(0xE321_F01F, "msr cpsr_c, #0x1F"),
	(0xE000_0291, "mul r0, r1, r2"),
	(0xE020_3291, "mla r0, r1, r2, r3"),
	(0xE081_0392, "umull r0, r1, r2, r3"),
	(0xE0C1_0392, "smull r0, r1, r2, r3"),
	(0xE102_0091, "swp r0, r1, [r2]"),
	(0xE350_0000, "cmp r0, #0"),
	(0x1351_0001, "cmpne r1, #1"),
	(0xEF00_0000, "swi #0x0"),
	(0xE600_0010, "undefined")
]:
	expect armText(word) == text

test "the canonical text assembles back to the same instruction":
	a = arm.newAssembler()
	for text in [
		"adds r0, r1, r2, lsl #2",
		"ldr r0, [r1], #-0x10",
		r"ldmib r3!, {r0, r5-r7}^",
		"msr spsr_f, #0xF0000000"
	]:
		i = a.assemble(text, 0x0800_0000, false, 4)
		print(i.text())
	prints r"""
		adds r0, r1, r2, lsl #2
		ldr r0, [r1], #-0x10
		ldmib r3!, {r0, r5-r7}^
		msr spsr_f, #0xF0000000
		"""

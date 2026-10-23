# The recompiler: the flow analysis finds the code reached from a segment's entries, and the
# emitter writes each lowered step as the Zap that performs exactly what the interpreter runs
# (cpu/interpret.zap, tested in tests/cpu.zap). A generated program that runs the recompiled code
# and the interpreter over the same bytes and compares their machine state is written by
# projects/excel1/recomp.zap's own run against the prepared disks; here the two pieces are checked directly.

import m68k

# moveq #5,d0; moveq #0,d1; moveq #3,d2; loop: add.l d2,d1; dbf d0,loop; not.l d1; lsl.l #1,d1;
# illegal (the sentinel a run stops at)
program = [
	u8(0x70),
	0x05,
	0x72,
	0x00,
	0x74,
	0x03,
	0xD2,
	0x82,
	0x51,
	0xC8,
	0xFF,
	0xFC,
	0x46,
	0x81,
	0xE3,
	0x89,
	0x4A,
	0xFC
]

test "the flow analysis finds the reachable code, the loop among it, the illegal a handoff":
	flow = m68k.analyze(program, 0, program.len, [0])
	# every instruction but the sentinel is reached; the dbf's target (6) and fallthrough (12) too
	print("{flow.order}")
	print("{6 in flow.code} {12 in flow.code}")
	# the dbf flows on inside the function; the illegal hands back to the driver
	print("{flow.isHandoff(m68k.decode(program, 8))}")
	print("{flow.isHandoff(m68k.decode(program, 16))}")
	prints """
		[0, 2, 4, 6, 8, 12, 14, 16]
		true true
		false
		true
		"""

# the Zap a single instruction recompiles to (its arm's lines after the address label)
fn recompiled(bytes u8[]):
	flow = m68k.analyze(bytes, 0, bytes.len, [0])
	source = flow.emitFunction("seg", [])
	# the body of the first arm (address 0): the lines between "0:" and the next arm
	lines = source.lines()
	out = []
	inArm = false
	for line in lines:
		if line.trimmed() == "0:":
			inArm = true
			continue
		if inArm:
			if line.trimmed().endsWith(":") and "=" not in line: break
			out.push(line.trimmed())
	out.join("\n")

test "a moveq recompiles to the move and the logical flags the interpreter sets":
	# moveq #5,d0
	print(recompiled([0x70, 0x05, 0x4A, 0xFC]))
	prints """
		t[0] = u32.wrap(5)
		cpu.setRegister(0, cpu.merged(cpu.register(0), t[0], 4))
		cpu.cn = cpu.msb(t[0], 4) != 0
		cpu.cz = t[0] & cpu.sizeMask(4) == 0
		t[1] = u32.wrap(0)
		cpu.setFlagBit(1, t[1] != 0)
		cpu.setFlagBit(0, t[1] != 0)
		pc = u32(2)
		"""

test "an add.l recompiles to the add, the carry, overflow, extend, N and Z the interpreter sets":
	# add.l d1,d0
	print(recompiled([0xD0, 0x81, 0x4A, 0xFC]))
	prints """
		t[0] = cpu.register(1)
		t[1] = cpu.register(0)
		t[2] = t[1] + t[0]
		cpu.setRegister(0, cpu.merged(cpu.register(0), t[2], 4))
		t[3] = cpu.msb(t[1] & t[0] | (t[1] | t[0]) & ~t[2], 4)
		cpu.setFlagBit(0, t[3] != 0)
		cpu.setFlagBit(4, t[3] != 0)
		t[4] = cpu.msb((t[1] ^ t[2]) & (t[0] ^ t[2]), 4)
		cpu.setFlagBit(1, t[4] != 0)
		cpu.cn = cpu.msb(t[2], 4) != 0
		cpu.cz = t[2] & cpu.sizeMask(4) == 0
		pc = u32(2)
		"""

# The cartridge's object windows that the widescreen widens (recomp.snes's console/wide.zap): the
# 16-bit constants its display culls and its placed-object scanners compare a position against,
# found where DKC1Recomp's widescreen notes place them (their blocks' addresses, read for the
# method; the code is not taken). The translation writes a call of console.widenLeft or widenSpan
# in place of such a constant, which returns it unchanged unless the scene is drawn wide; the
# cycles the instruction takes are the same either way.

import recomp.snes.snes

# a window's left edge moved out, from a block's first instruction
fn left(from i64, literal i64):
	snes.Patch.Immediate(from, literal, "console.widenLeft")

# a window's width grown
fn span(from i64, literal i64):
	snes.Patch.Immediate(from, literal, "console.widenSpan")

# The instructions the translation changes by what they are: the banana writer's asl that takes
# the x-high bit of its 16-bit x, bit 8 where it took the sign; the vertical rope's cull key and
# its upper-OAM merge (wide/scene.zap); the placed-object group's retry of its children
# (wide/retry.zap).
fn hooks():
	[
		snes.Patch.Carry(0xB8_BA91, "asl", r"wide.isHighBitSet({old})"),
		snes.Patch.Carry(0xB8_BAF4, "asl", r"wide.isHighBitSet({old})"),
		snes.Patch.After(
			0x80_A805,
			"sta",
			[
				"wide.noteRope(cpu.a)",
				"cpu.a = wide.ropeBias(cpu.a)",
				"cpu.n = cpu.a & 0x8000 != 0",
				"cpu.z = cpu.a == 0"
			]
		),
		snes.Patch.Operand(0x80_A892, "ora", r"wide.ropeMerge(cpu.a, {operand})"),
		snes.Patch.RetryBefore(0xBD_FB76, "ldx", "wide.type5Retry()", 0xBD_FBF5)
	]

# the shared world-sprite renderer's two windows, the placed-object scanners' left edges, spans and
# right prefetches (bank BD)
pub fn widePatches() snes.Patch[]:
	out = hooks()
	out.extend([
		left(0xB8_B918, 0x100),
		span(0xB8_B93E, 0x10F),
		left(0xB8_B9EA, 0x0F),
		left(0xB8_BA11, 0x107),
		span(0x80_A809, 0x100),
		left(0xBB_A8D4, 0x30),
		span(0xBB_A8D4, 0x160),
		left(0xBB_A904, 0x58),
		span(0xBB_A904, 0x1B0)
	])
	for at in [
		0xF5AA,
		0xF5F8,
		0xF6FF,
		0xF751,
		0xF78C,
		0xF88A,
		0xF8D5,
		0xF9A2,
		0xF9E8,
		0xFA31,
		0xFADB,
		0xFB0D,
		0xFBA5,
		0xFCCC,
		0xFD00,
		0xFE7F,
		0xFF24,
		0xFFAD
	]:
		out.push(left(0xBD_0000 + at, 0x20))
	for at in [
		0xF604,
		0xF70F,
		0xF79C,
		0xF899,
		0xF8E1,
		0xF9B6,
		0xF9F4,
		0xFA3D,
		0xFAE7,
		0xFB1D,
		0xFCD8,
		0xFD0C,
		0xFF37,
		0xFFBE
	]:
		out.push(span(0xBD_0000 + at, 0x140))
	for at in [0xF585, 0xFB80]:
		out.push(left(0xBD_0000 + at, 0x120))
	out

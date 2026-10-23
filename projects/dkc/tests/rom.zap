# The flow over the cartridge: every instruction it finds assembles back to the ROM's bytes.
#   needs: projects/dkc/rom/dkc1.sfc (the player's dump, never committed)

import cartridge
import fs
import recomp.snes.snes

test "every instruction found assembles back to its bytes":
	rom = fs.readBytes(cartridge.romPath) ?? fail("no ROM: {error}")
	code = snes.newCode(rom, snes.readCfg(cartridge.game().tablesDir))
	program = code.discover()
	wrong = []
	for f in program.functions:
		for i in f.instrs:
			off = snes.romOffset(i.at)
			again = code.decoder.assembler.assemble(i.text(), i.at)
			if again.bytes() != code.rom[off..off + i.size]:
				wrong.push("{i.at:06X} {i.text()}")
	print(code.summary(program).text())
	expect wrong.isEmpty

test "every function found translates, and the game never sets decimal mode":
	code = snes.newCode(
		fs.readBytes(cartridge.romPath) ?? fail("no ROM: {error}"),
		snes.readCfg(cartridge.game().tablesDir)
	)
	program = code.discover()
	lines = 0
	for f in program.functions:
		lines += program.emitFunction(f).len
	expect lines > program.functions.len
	expect program.decimalAt() == none

# The cartridge prepared: checked, its functions found and written recompiled into
# projects/firered/recomp/ (the program projects/firered/recomp/firered.zap), its data into projects/firered/assets/.

import arm
import fs

pub recompDir = "projects/firered/recomp"
pub assetsDir = "projects/firered/assets"
pub cartridgeFile = "projects/firered/assets/cartridge.bin"

# Prepares from the dump at romPath (traced: the code keeps the functions it last entered, for
# gba's --calls); stops the program with the reason when the dump is not FireRed's.
pub fn prepareGame(romPath str, traced bool):
	rom = fs.readBytes(romPath) ?? fail("no cartridge dump at {romPath}: {error}")
	if cartridgeProblem(rom) is why:
		fail("{romPath} is not Pokemon FireRed (USA, revision 0): {why}")
	started = clockSeconds()
	code = Code(rom, decoder = arm.newDecoder())
	program = code.discover()
	instructions = program.functions.map(.instrs.len).sum()
	print("{program.functions.len} functions, {instructions} instructions, found in {(clockSeconds() - started):.1} s")
	written = code.writeRecompiled(program, recompDir, traced)
	_ = fs.createDir(assetsDir)
	if (fs.readBytes(cartridgeFile) ?? []) != code.rom:
		fs.writeBytes(cartridgeFile, code.rom) ?? fail("cannot write {cartridgeFile}: {error}")
		written += 1
	print("{written} files written in {(clockSeconds() - started):.1} s")

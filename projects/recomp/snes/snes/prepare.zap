# The cartridge prepared: its functions found from the game's tables (or the vectors alone) and
# written recompiled into the game's recomp dir, the program <recompDir>/<name>.zap (game.zap).

import recomp.snes.cartridge

# Prepares the game from its dump; stops the program with the reason when the dump is missing.
# The dump is the game project's to check before (its size, its hash).
pub fn prepareGame(game Game):
	rom = cartridge.readRom(game.romPath) ?? fail("no ROM at {game.romPath}: {error}")
	cartridge.hirom = cartridge.readHeader(rom).hirom
	started = clockSeconds()
	code = newCode(rom, readCfg(game.tablesDir) if not game.tablesDir.isEmpty else vectorsOnly())
	program = code.discover()
	while code.addFoundEntries(program):
		program = code.discover()
	print("{code.summary(program).text()}; found in {(clockSeconds() - started):.1} s")
	program.patches = resolvePatches(program.functions, game.patches)
	written = program.writeRecompiled(game, code.decoder)
	print("{written} files written in {(clockSeconds() - started):.1} s")

# where the code sets decimal mode (sed, or sep with the D bit), none when it never does
pub fn decimalAt(p Program) i64?:
	for f in p.functions:
		for i in f.instrs:
			if i.name == "sed" or (i.name == "sep" and i.value & 0x08 != 0): return i.at
	none

# Entries the flow finds beyond the cfg's, added to it as functions: the targets of the jumps
# through variables (pointers.zap) in the jump's widths, and the code after each WAI (where a wait
# goes on once an interrupt handler that left the code it interrupted for good returns to it,
# cpu.wait). Whether any was new.
fn addFoundEntries(mut code Code, p Program):
	added = false
	for d in code.storedDispatches(p):
		if d.at in code.cfg.dispatches: continue
		w = p.widthsOfJump(d.at)
		for t in d.targets:
			code.addEntry(t, w)
		code.cfg.dispatches[d.at] = d.copy()
		added = true
	for f in p.functions:
		for i in f.instrs:
			if i.name == "wai" and not (canonical(i.next()) in p.primary):
				code.addEntry(canonical(i.next()), i.widths)
				added = true
	added

fn addEntry(mut code Code, at i64, w Widths):
	code.cfg.functions.push(CfgFunction(name = "", at, end = at, m = w.m, x = w.x))

fn widthsOfJump(p Program, at i64):
	for f in p.functions:
		for i in f.instrs:
			if canonical(i.at) == at: return i.widths
	native16

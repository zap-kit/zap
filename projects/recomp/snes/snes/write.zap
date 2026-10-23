# The recompiled program written into a dir: the functions a few hundred to a file (module game),
# the dispatcher of every function by its address and widths, and the program's entry.

import fs

functionsEach = 300

# what every file written imports: the console and the CPU, then the game's modules
fn header(game Game):
	lines = [
		"# Written by recomp.snes from the cartridge: the code is the game's, never committed.",
		"",
		"import recomp.snes.console",
		"import recomp.snes.cpu"
	]
	for m in game.imports:
		lines.push("import {m}")
	"{lines.join("\n")}\n"

# the file's text written when it differs from what is there: whether it was written
fn writeChanged(path str, text str):
	fs.writeChanged(path, text.bytes()) ?? fail("cannot write {path}: {error}")

# Writes the program's files into dir; how many changed.
pub fn writeRecompiled(p Program, game Game, decoder Decoder) i64:
	dir = game.recompDir
	generatedHeader = game.header()
	fs.createDir("{dir}/game") ?? fail("cannot make {dir}: {error}")
	texts = p.functions.map("\n{p.emitFunction(it).join("\n")}\n")
	written = fs.writeNumbered(
		"{dir}/game/functions",
		".zap",
		generatedHeader,
		texts,
		functionsEach
	) ??
		fail("cannot write {dir}: {error}")
	ops, step = decoder.interpreterTexts()
	written += fs.writeNumbered(
		"{dir}/game/interpret",
		".zap",
		generatedHeader,
		ops,
		functionsEach
	) ??
		fail("cannot write {dir}: {error}")
	if writeChanged("{dir}/game/dispatch.zap", "{p.dispatchText(generatedHeader)}{step}"):
		written += 1
	if game.writeEntry(): written += 1
	if writeChanged("{dir}/jumps.txt", p.jumpsText()): written += 1
	written

# The program's jumps and calls through memory, a line each (address, mnemonic, mode, operand),
# which tools/oracle.lua's played mode watches in Mesen 2 for where they go.
fn jumpsText(p Program):
	lines = []
	for f in p.functions:
		for i in f.instrs:
			if i.mode in ["(w,x)", "(w)", "[w]"] and i.name in ["jmp", "jml", "jsr"]:
				lines.push("{hex(i.at, 6)} {i.name} {i.mode} {hex(i.value, 4)}")
	"{lines.join("\n")}\n"

# the call of a function by its address in widths, else in the widths it starts in; a mirror in
# banks 00-3F by its address in 80-BF
fn dispatchText(p Program, generatedHeader str):
	lines = [
		generatedHeader.copy(),
		"# the function at `at` translated in `widths` (bits e, m, x); false when there is none",
		"pub fn callExact(at u32, widths u32) bool:",
		"\tmatch at | (widths << 24):"
	]
	for f in p.functions:
		lines.push("\t\t{hex(f.entryKey(), 8)}: {functionName(f.entryKey())}()")
	lines.extend(
		[
			"\t\t_: return false",
			"\ttrue",
			"",
			"# the function at `at` called in `widths`, else in those it starts in; false when there is none",
			"pub fn call(at u32, widths u32) bool:",
			"\tcallExact(at, widths) or callStart(at)",
			"",
			"fn callStart(at u32) bool:",
			"\tmatch at:"
		]
	)
	for at in p.primary.keys().sorted():
		lines.push("\t\t{hex(at, 6)}: {functionName(p.primary[at])}()")
	# a function named in the upper banks, called through its mirror below
	lines.extend(
		[
			"\t\t_:",
			"\t\t\tif at < 0x7E_0000: return callStart(at | 0x80_0000)",
			"\t\t\treturn false",
			"\ttrue"
		]
	)
	"{lines.join("\n")}\n"

# The program's entry file written (<recompDir>/<name>.zap): whether it changed. A second entry
# for the same program (a release's widescreen one) is the same game under another name.
pub fn writeEntry(game Game) bool:
	writeChanged("{game.recompDir}/{game.name}.zap", game.entryText(game.header()))

# the program's entry: the cartridge loaded, the game's setup lines, the screen, the CPU reset
fn entryText(game Game, generatedHeader str):
	lines = [
		"{generatedHeader}import game",
		"",
		"console.loadRom(console.romPath(\"{game.romPath}\", \"{fs.stem(game.romPath)}\"))"
	]
	if not game.presets.isEmpty:
		lines.push("console.presets = [{game.presets.map("\"{it}\"").join(", ")}]")
	lines.extend(game.setup.copy())
	lines.extend(
		[
			"console.openScreen()",
			"cpu.reset(cpu.Hooks(call = game.call, callExact = game.callExact, step = game.step))"
		]
	)
	"{lines.join("\n")}\n"

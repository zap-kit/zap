# The recompiled program written into a dir: the functions a few hundred to a file, the
# dispatcher of every function by its key, and the program's entry.

import fs

generatedHeader = "# Written by projects/firered/prepare.zap from the cartridge: the code is the game's, never committed.\n\nimport cpu\nimport gba\n"
functionsEach = 300

# the file's text written when it differs from what is there: whether it was written
fn writeChanged(path str, text str):
	fs.writeChanged(path, text.bytes()) ?? fail("cannot write {path}: {error}")

# Writes the program's files into dir; how many changed.
pub fn writeRecompiled(code Code, p Program, dir str, traced bool) i64:
	fs.createDir("{dir}/game") ?? fail("cannot make {dir}: {error}")
	entries {i64: bool} = {}
	for f in p.functions:
		entries[key(f.entry, f.thumb)] = true
	texts = p.functions.map("\n{code.emitFunction(entries, it, traced).join("\n")}\n")
	written = fs.writeNumbered(
		"{dir}/game/functions",
		".zap",
		generatedHeader,
		texts,
		functionsEach
	) ??
		fail("cannot write {dir}: {error}")
	if writeChanged("{dir}/game/dispatch.zap", p.dispatchText()): written += 1
	if writeChanged("{dir}/firered.zap", entryText): written += 1
	written

# the call of a function by its key, and every function's key and size in the cartridge
fn dispatchText(p Program):
	lines = [
		generatedHeader,
		"# the function whose key is `at` called (code copied to memory: its copy's in the",
		"# cartridge); false when there is none",
		"pub fn call(at u32) bool:",
		"\tmatch at:"
	]
	for f in p.functions:
		k = key(f.entry, f.thumb)
		lines.push("\t\t{hex(k)}: {functionName(k)}()")
	lines.extend(
		[
			"\t\t_:",
			"\t\t\tcopy = gba.romCopyOf(at)",
			"\t\t\tif copy == 0: return false",
			"\t\t\treturn call(copy)",
			"\ttrue"
		]
	)
	lines.push("")
	lines.push("# each function's key and the bytes from its entry to its last instruction")
	lines.push("pub functionSpans u32[] = [")
	for f in p.functions:
		span = f.instrs[len - 1].next() - f.entry if not f.instrs.isEmpty else 0
		lines.push("\t{hex(key(f.entry, f.thumb))}, {span},")
	lines.push("]")
	"{lines.join("\n")}\n"

entryText = "{generatedHeader}import game\n\ncpu.hooks = cpu.Hooks(call = game.call)\ngba.start(game.functionSpans)\ngame.a08000000()\n"

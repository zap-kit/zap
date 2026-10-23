# The environment variables and the words of ZAP_TRACE and ZAP_RUN as their declarations say them
# (`EnvVariable("NAME", "what it does")`, `TraceWord("word", "what it does")`, `RunWord(...)`,
# runtime/system/io.zap),
# read from the sources: `zap doc environment` lists those of the compiler, the runtime, std and
# the dependencies, and a build refuses a word of ZAP_TRACE that neither the compiler nor the
# program declares.

import fs

type DeclaredSetting:
	kind str   # EnvVariable, TraceWord or RunWord
	name str
	about str

settingKinds = ["EnvVariable", "TraceWord", "RunWord"]

# the declarations in a file, in its order
fn settingsIn(file str):
	text = fs.readFile(file) ?? ""
	if not settingKinds.any("{it}(" in text): return []
	toks = (lex(text, file) ?? []).filter(.kind != tkNewline)
	out = []
	for i in 0..toks.len - 5:
		t = toks[i]
		if t.kind == tkUident and t.text in settingKinds and toks[i + 1].kind == tkLparen and
			toks[i + 2].kind == tkStr and toks[i + 3].kind == tkComma and
			toks[i + 4].kind == tkStr:
			out.push(
				DeclaredSetting(
					kind = t.text.copy(),
					name = toks[i + 2].text.copy(),
					about = toks[i + 4].text.copy()
				)
			)
	out

# the declarations in the files
fn settingsInAll(files str[]):
	out = []
	for f in files:
		out.extend(settingsIn(f))
	out

# the dir of the compiler's sources, beside the runtime's
fn compilerDir():
	rt = runtimeDir()
	"{dirPrefix(rt[..rt.len - 1])}compiler"

# the compiler's sources and the runtime's: their declarations hold for every build
fn compilerAndRuntimeFiles():
	rt = runtimeDir()
	files = fs.zapFiles(compilerDir(), false)
	files.extend(runtimeFiles(rt).map(rt + it))
	files

# A word of ZAP_TRACE that no declaration of the compiler, the runtime or the program's own
# modules names ends the build, the words listed: a misspelt word would otherwise say nothing.
# A zap whose runtime is a copy without the compiler's sources beside it (build/base's, which
# reads build/runtime) cannot tell its own words, and checks none.
fn checkTraceWords(prog Program):
	given = traceVariable().value() ?? return
	if not fs.exists(compilerDir()): return
	files = compilerAndRuntimeFiles()
	for d in prog.decls:
		f = prog.nodes[d].file()
		if prog.nodes[d].mod() != "rt" and f != "" and not f.startsWith("<") and f not in files:
			files.push(f.copy())
	words = settingsInAll(files).filter(.kind == "TraceWord").map(.name.copy())
	for item in given.split(","):
		word = item[..item.indexOf("=") ?? len]
		if word != "" and word not in words:
			exit(
				2,
				"zap: ZAP_TRACE names no word '{word}': {words.sorted().join(", ")} (zap doc environment says what each does)"
			)

# `zap doc environment`'s table: the variables, then the words of ZAP_TRACE and of ZAP_RUN, each with what it
# does, as the working dir's repository (its spec and tests aside), its dependencies, std, the
# runtime and the compiler declare them; a name declared twice is shown as the first declares it
fn environmentTable():
	files = fs.zapFiles(".", false).filter("/spec/" not in it and "/tests/" not in it)
	for m in apiModules():
		if m.origin != "runtime":
			files.extend(m.files.copy())
	files.extend(compilerAndRuntimeFiles())
	found DeclaredSetting[] = []
	for s in settingsInAll(files):
		if not found.any(.kind == s.kind and .name == s.name):
			found.push(s)
	lines = []
	for kind in settingKinds:
		mine = found.filter(.kind == kind).sortedBy(.name)
		lines.push(
			"environment variables:" if kind == "EnvVariable"
			else "words of ZAP_TRACE:" if kind == "TraceWord"
			else "words of ZAP_RUN:"
		)
		width = mine.map(.name.len).max() ?? 0
		for s in mine:
			lines.push("  {s.name}{" ".repeat(width - s.name.len)}   {s.about}")
	lines.join("\n")

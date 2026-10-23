# The cache of a bench suite's measured runs: one small file in build/bench-cache/ per program,
# named by a hash of everything that decides its result, so a program that did not change is not
# built or run again. `--fresh` ignores it for Zap's programs (the rivals' keys hold their source,
# flags and compiler: no change of Zap's makes them stale), `--fresh all` for every language's.
#
# The key holds the problem and the language, the program's source (and the Cargo manifest and
# the header dirs it reads), the build command and flags, the compiler or interpreter (its
# version string; for Zap the zap executable and every source of runtime/ and std/), the
# argument, the input file, the runs and the memory limit.

import digest
import fs

cacheDir = "build/bench-cache"

# A program's measured outcome: built, its run (none when it failed), a hash of what it printed,
# which the other languages' outputs are compared against, and its executable's bytes (0 for a
# program an interpreter runs).
pub type Outcome:
	built bool
	run Run?
	output i64 = 0
	exeBytes i64 = 0

# The cache of one suite run: whether it is ignored, the zap toolchain's hash, the tools' version
# strings asked so far, and how many outcomes were read from it of the programs asked.
pub type Cache:
	fresh bool
	freshAll bool = false
	zapStamp str = ""
	toolNames str[] = []
	toolTexts str[] = []
	hits i64 = 0
	asked i64 = 0

# a text's hash, short enough to put in a key
fn textStamp(text str):
	"{text.len}:{text.hash():x}"

# the first dir of the PATH holding a zap executable (zap test puts its own first)
fn zapExePath():
	zap = "zap{exeSuffix()}"
	for dir in (env.get("PATH") ?? "").split(pathListSeparator()):
		if dir != "" and fs.exists("{dir}/{zap}"): return "{dir}/{zap}"
	zap

# whether a zap is on the PATH to build the Zap programs (a test's run on another machine has none)
pub fn hasZap() bool:
	fs.exists(zapExePath())

# The hash of the Zap toolchain: the zap executable that builds a program and the runtime and std
# sources it is built with.
fn toolchainStamp():
	"{textStamp(fs.readFile(zapExePath()) ?? "")} {fs.zapStamp(["runtime", "std"])}"

pub fn newCache(fresh bool, freshAll bool) Cache:
	Cache(fresh, freshAll, zapStamp = toolchainStamp())

# the version string of the tool that builds or runs a language's programs
fn toolVersion(mut cache Cache, ext str):
	at = cache.toolNames.indexOf(ext) ?? -1
	if at >= 0: return cache.toolTexts[at].copy()
	ask = "{python()} -V" if ext == "py" else "g++ --version" if ext == "cpp"
		else "rustc -V" if ext == "rs" else "gcc --version"
	asked = Process.output(ask)
	text = asked.out if asked.code == 0 else "?"
	cache.toolNames.push(ext.copy())
	cache.toolTexts.push(text.copy())
	text

# the files of the dirs a flag list adds to the headers' path (-Idir), as a hash
fn headersStamp(flags str):
	parts = []
	for flag in flags.split(" "):
		if flag.startsWith("-I"):
			for name in fs.list(flag[2..]) ?? []:
				parts.push("{name} {textStamp(fs.readFile("{flag[2..]}/{name}") ?? "")}")
	textStamp(parts.join("\n"))

# The key of a program's outcome: a hash of everything that decides it (see the top).
fn programKey(
	toolchain str,
	problem str,
	src str,
	flags str,
	arg str,
	input str,
	runs i64
):
	ext = extensionOf(src)
	manifest = fs.readFile("{src}.Cargo.toml") ?? ""
	modified = (fs.modified(input) ?? 0) if input != "" else 0
	parts = [
		problem.copy(),
		languageName(ext),
		textStamp(fs.readFile(src) ?? ""),
		textStamp(manifest),
		headersStamp(flags),
		buildRecipe(src, flags),
		toolchain.copy(),
		arg.copy(),
		"{input} {modified}",
		"{runs}",
		"{memoryLimitMb()}"
	]
	digest.sha1(parts.join("\n").bytes())

# the outcome a key kept, or none
fn load(key str) Outcome?:
	fields = (fs.readFile("{cacheDir}/{key}") ?? "").trimmed().split(" ")
	if fields.len != 10: return none
	nanos = try i64.parse(fields[0])
	run = Run(
		seconds = nanos / 1.0e9,
		peakBytes = try i64.parse(fields[1]),
		cycles = try i64.parse(fields[2]),
		code = try i64.parse(fields[3]),
		overMemory = fields[4] == "1",
		overTime = fields[4] == "2",
		instructions = try i64.parse(fields[7]),
		cacheMisses = try i64.parse(fields[8]),
		branchMisses = try i64.parse(fields[9])
	)
	Outcome(
		built = true,
		run,
		output = try i64.parse(fields[5]),
		exeBytes = try i64.parse(fields[6])
	)

fn save(key str, run Run, output i64, exeBytes i64):
	_ = fs.createDir(cacheDir)
	nanos = i64((run.seconds * 1.0e9).round())
	over = 1 if run.overMemory else 2 if run.overTime else 0
	_ = fs.writeFile(
		"{cacheDir}/{key}",
		"{nanos} {run.peakBytes} {run.cycles} {run.code} {over} {output} {exeBytes} {run.instructions} {run.cacheMisses} {run.branchMisses}"
	)

# Builds the program at src and measures it, unless the cache holds the outcome of this very
# program; its stdout goes to outPath. A program that failed is never kept.
pub fn outcome(
	mut cache Cache,
	problem str,
	src str,
	flags str,
	arg str,
	input str,
	runs i64,
	outPath str,
	limitSeconds f64 = 0.0
) Outcome:
	cache.asked += 1
	ext = extensionOf(src)
	toolchain = cache.zapStamp.copy() if ext == "zap" else cache.toolVersion(ext)
	limit = "" if limitSeconds <= 0.0 else " (limit {limitSeconds} s)"
	key = programKey(toolchain, problem, src, flags + limit, arg, input, runs).copy()
	ignored = cache.fresh and (ext == "zap" or cache.freshAll)
	if not ignored and load(key) is kept:
		cache.hits += 1
		return kept
	exe = build(src, flags)
	if exe == "": return Outcome(built = false, run = none)
	result = measure(exe, arg, input, outPath, runs, memoryLimitMb(), limitSeconds)
	printed = (fs.readFile(outPath) ?? "").hash()
	exeBytes = (fs.readBytes(exe) ?? []).len   # (none for an interpreter's command)
	if result is run:
		save(key, run, printed, exeBytes)
	Outcome(built = true, run = result, output = printed, exeBytes)

# the line that says how much of a suite came from the cache
pub fn cacheLine(cache Cache) str:
	"cache: {cache.hits} of {cache.asked} results reused"

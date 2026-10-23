# 13.2 Environment variables
#
# Every environment variable the compiler, the runtime, std, the engine or a program reads is
# declared once with a line saying what it does, as what a function gives: `EnvVariable("ZAP_DXC",
# "...")`, read by its `value()`. `ZAP_TRACE` is a comma-separated list of words naming the
# diagnostics asked for, a word given a value as `word=value` (`disasm=main`), each word declared
# as `TraceWord("profile", "...")` and read by its `on()` and `value()`. `ZAP_RUN` is the same
# kind of list for how an engine program runs (`headless`, `gpu=d3d12`, `audio=off`), each word
# declared as `RunWord("gpu", "...")`. The variables zap sets for the programs it starts are
# `InternalVariable("ZAP_TEST_RUN")`: read as the others, left out of the table. `zap doc
# environment` prints the declarations of the working dir's repository, its dependencies, std, the
# runtime and the compiler after this section, and `zap run`, `zap build` and `zap test` refuse a
# word of `ZAP_TRACE` that neither the compiler nor the program declares, listing the words.

import fs

fn profileWord():
	TraceWord("profile", "zap run samples the program")

fn mapWord():
	TraceWord("map", "writes the map of the functions")

test "a trace word may carry a value":
	before = env.get("ZAP_TRACE") ?? ""
	env["ZAP_TRACE"] = "map,profile=main"
	print("{profileWord().on()} {profileWord().value()} {mapWord().value()}")
	print(TraceWord("prof", "a word not given").value())
	env["ZAP_TRACE"] = before
	prints """
		true some("main") some("")
		none
		"""

test "a variable is read through its declaration":
	before = env.get("ZAP_TEST_ENV") ?? ""
	declared = EnvVariable("ZAP_TEST_ENV", "a variable of this test")
	env[declared.name] = "set"
	print(declared.value())
	env[declared.name] = before
	prints "some(\"set\")"

# The compiler's words explain a pass on stderr; `profile` makes `zap run` sample the program's
# main thread about every millisecond and list its functions by self and total time (`profile=name`
# also counts that function's callers and the addresses its samples stopped at). `map` writes
# `build/x.exe.map` beside the executable, its functions' addresses after the executable's hash:
# what reads it (`profile`, `disasm`, `zap test --only size`) refuses a map of another build.

# what running `command` with ZAP_TRACE set to `words` writes, both streams, in the test's dir
fn traced(words str, command str):
	Process.output(command, vars = ["ZAP_TRACE={words}"]).out.replace("\r\n", "\n")

fn program():
	file = "{testDir()}traced.zap"
	_ = fs.writeFile(file, "xs = [1, 2]\nprint(xs.len)\n")
	file

test "tokens lists the entry file's tokens":
	said = traced("tokens", "{zapPath()} build {program()}")
	expect "1:1   identifier       xs" in said and "1:7   int literal      1" in said

test "a word no declaration names is refused, the words listed":
	said = traced("map,nocahe", "{zapPath()} build {program()}")
	expect said.startsWith("zap: ZAP_TRACE names no word 'nocahe': ") and ", nocache, " in said

test "a program's own word is known to its build":
	file = "{testDir()}own.zap"
	_ = fs.writeFile(file, "fn drawWord() TraceWord:\n\tTraceWord(\"draws\", \"each draw\")\n\nprint(drawWord().on())\n")
	print(traced("draws", "{zapPath()} run {file}").trimmed())
	prints "true"

test "zap doc environment lists the declarations":
	said = traced("", "{zapPath()} doc environment")
	expect "  ZAP_RUNTIME " in said and "  memstats " in said and "  tokens " in said
	expect "words of ZAP_RUN:" in said and "  headless " in said and "  gpu " in said
	table = said[(said.lastIndexOf("environment variables:") ?? 0)..]
	expect "  ZAP_TEST_RUN " not in table and "  ZAP_READS " not in table

test "a run word may carry a value":
	before = env.get("ZAP_RUN") ?? ""
	env["ZAP_RUN"] = "headless,gpu=d3d12"
	print("{headlessWord().on()} {RunWord("gpu", "the backend").value()} {RunWord("audio", "no sound").value()}")
	env["ZAP_RUN"] = before
	prints """
		true some("d3d12") none
		"""

# The runtime's words are a program's: `memstats`, `memcheck` (a use after free or a second free
# stops the program at once) and `leaks` (each block never freed listed by the calls that
# allocated it, each call by its function and line).

test "memstats counts the allocations and frees at exit":
	Process.output("{zapPath()} build {program()}")
	said = traced("memstats", builtExe("traced"))
	print(said.lines()[0])
	expect "zap memstats: allocations=" in said and " peak=" in said
	prints "2"

# `ZAP_TRACE=errors=json` writes errors as JSON lines (see *Runtime errors*).

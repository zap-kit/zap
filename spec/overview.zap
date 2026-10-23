# 1. Overview
#
# The one specification of the language, for agents who write Zap and humans who review it: one
# file a section in `spec/`, the prose in comments and each rule a test, so `zap test spec` runs it
# and `zap doc <section>` prints it (`zap doc spec` lists them). Where the prose and a test
# disagree, the test says what the compiler does and the prose is corrected.
#
# Zap is a compiled, statically typed language without a garbage collector. Files end in `.zap`
# (`.zapx` with markup, 7.11); the command is `zap` (`zap run app.zap`, `zap build app.zap`). The compiler is written in Zap and
# writes native x86-64 Windows executables itself, with no C compiler, assembler or linker. Its
# reach is that of a systems language, from kernels, drivers and firmware up to engines, servers,
# tools and one-file scripts: no runtime is required, nothing is allocated behind the program's
# back, and `extern fn` reaches the operating system and foreign libraries. The workload that sets
# the priorities is a native online game: a server that runs for weeks and a client that renders
# at 60 frames per second without pauses.
#
# Goal: five measures, pushed together: the least time to compile, the most speed when running, the
# smallest executable, the least memory used and the most memory safety. Each change to the
# language, the compiler and the runtime is judged by what it does to the five, measured.
#
# Design rules:
# 1. One obvious way to do each thing, so a model generates consistently and a reviewer always
#    reads the same pattern. A second way is refused; the compiler and the formatter enforce the
#    canonical form (`zap doc refused` lists the refused forms, each with the one to write).
# 2. Correctness by default, performance opt-in: simple code always compiles; speed comes from
#    saying more, never from removing safety.
# 3. Explicit over implicit: no implicit narrowing, no hidden copy of a value that owns memory, no
#    allocation behind an operator, no exceptions: what the reviewer reads is what runs.
# 4. Native only: one backend, one executable per program; no JavaScript, no browser target.
# 5. Fast code reads plainly: the goal is to beat Rust on application code, by having fewer things
#    to be slow about (values inline, no trait-object dispatch, allocation only where asked) and
#    none of its ceremony (no lifetime syntax, no async colouring, no implicit clones). The fast
#    version reads as plainly as the simple one: no conversion chains, no typed-literal
#    workarounds, no intrinsic in sight. A trick low-level code needs becomes a named method; when
#    the idiomatic form is slow, the compiler is fixed, not the program. The programs in
#    `tests/benchmarks/` are judged on how they read as much as on how they run.
# 6. Fastest, least memory, fewest copies: every rule of the language and of its code generation
#    picks the fastest form, then the one holding the least memory, then the one making the fewest
#    copies. A value lives until its last use and no longer; nothing is copied to make a rule
#    easier to check: what the compiler cannot prove safe it refuses, the error saying what to
#    write instead, and a refusal that keeps showing up is met by a stronger proof, never by a
#    run-time check or a copy.

type User:
	name str
	age i64

fn adultNames(users User[]):
	users.filter(.age > 18).map(.name)

test "a pipeline filters and maps a list of records in one line":
	expect adultNames([User(name = "ana", age = 30), User(name = "bo", age = 9)]) == ["ana"]

# No semicolons and no `:` before types; names are camelCase (2.1); every binding is
# read; methods take `self` first (5.2).

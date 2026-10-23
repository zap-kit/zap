# Every function of the cartridge, found as flow.zap says.

import arm

pub type Program:
	functions Function[]   # by key
	index {i64: i64}   # a function's key to its place in functions

# The functions: first those the entry reaches (its calls, closed over), then the Thumb code the
# cartridge's words point at (not into a function found, nor over the literals one loads: such a
# word is data), then each explored again knowing every entry (a branch to one is a
# call).
pub fn discover(code Code) Program:
	entries {i64: bool} = {}
	covered {i64: bool} = {}   # the instructions of the functions found
	literals {i64: bool} = {}   # the words they load
	code.reach([key(romBase, false)], entries, covered, literals)
	candidates = []
	at = romBase
	while code.isInRom(at):
		w = i64(code.word(at))
		if w & 1 == 1 and code.isInRom(w - 1) and not (w in entries): candidates.push(w)
		at += 4
	for c in candidates.sorted():
		if c in entries or c - 1 in covered: continue
		f = code.explore(c - 1, true, entries)
		if f.isClean and f.endsWell() and not f.instrs.any(.at & ~3 in literals):
			code.reach([c], entries, covered, literals)
	keys = entries.keys().sorted()
	functions = []
	index {i64: i64} = {}
	for k in keys:
		index[k] = functions.len
		functions.push(code.explore(k & ~1, k & 1 == 1, entries))
	Program(functions, index)

# the functions from the keys, and those they call, added to entries, their instructions to
# covered and the words they load to literals
fn reach(
	code Code,
	start i64[],
	mut entries {i64: bool},
	mut covered {i64: bool},
	mut literals {i64: bool}
):
	work = start.copy()
	while work.pop() is k:
		if k in entries or not code.isInRom(k & ~1): continue
		entries[k] = true
		f = code.explore(k & ~1, k & 1 == 1, {})
		for i in f.instrs:
			covered[i.at] = true
			if code.literalAddress(i) is at: literals[at] = true
		for c in f.calls:
			if not (c in entries): work.push(c)
		for t in f.taken:
			if not (t in entries) and code.isInRom(t) and code.explore(t, false, {}).isCleanCode():
				work.push(t)

fn isCleanCode(function Function):
	function.isClean and function.endsWell()

# whether every way through the function leaves it by a return or a jump, as code does, rather
# than by running into what is no instruction
fn endsWell(function Function):
	not function.instrs.isEmpty and function.instrs.any(.writesPc() and .cond == arm.always)

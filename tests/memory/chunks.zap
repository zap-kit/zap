# Small blocks come from 4 MB chunks; once a peak of them is over, the chunks left wholly free
# go back to the system, and so do those of blocks another thread made. A checked run (every
# test) gives a page of its own to each block only up to its budget (runtime's guardBudget), so a
# test of many small blocks stays far below the memory cap of `zap test`; a program over that cap
# says it is out of memory.

import compare
import fs

fn names(n i64):
	(0..n).map("the name of number {it} in the list")   # longer than a short str

test "a peak of small blocks is given back":
	before = memoryCommitted()
	held = names(1_000_000)
	during = memoryCommitted()
	count = held.len
	held = []   # the strings' chunks and the list's block
	after = memoryCommitted()
	print(
		"{during - before > 40000000 and count == 1000000} {after - before < (during - before) / 4}"
	)
	prints "true true"

test "the blocks of a parallel map, freed here, go back too":
	before = memoryCommitted()
	made = 0
	loop 3:
		parts = (0..200000).parallel().map(i: "part {i}")
		made += parts.len
	print(made == 600_000 and memoryCommitted() - before < 64_000_000)
	prints "true"

test "a checked run gives pages of their own to blocks up to a budget, the rest from the heap":
	before = memoryCommitted()
	held = names(140_000)   # a page each: 573 MB
	grown = memoryCommitted() - before
	print(held.len == 140_000 and grown < 400_000_000)
	prints "true"

# small blocks held until the system gives no more: the report finds the heap's chunk full
outgrows = r"""
	held str[] = []
	loop:
		held.push("a string long enough to own its block {held.len}")
	"""

test "a program past the memory its job allows stops saying it is out of memory":
	file = "{testDir()}outgrows.zap"
	_ = fs.writeFile(file, outgrows)
	expect Process.output("{zapPath()} build {file}").code == 0
	run = compare.runMeasured(builtExe("outgrows"), "", "{testDir()}out.txt", 256)
	print("{run.code} {run.overMemory}")
	prints "3 true"

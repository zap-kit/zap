# A test program asks the zap running it to lay out a file (the runtime's zapFmt), the forms only
# types tell kept for it by a check first (lint.zap): the zap answers in its own process, its
# compiler loaded, so no zap starts for a request. What it says meanwhile goes to the request's own
# file (<asks>-<n>.said), apart from its output.

import fs

# request n at asks answered, if it is there: whether it was
fn answerAsked(asks str, n i64):
	ask = "{asks}-{n}"
	words = (fs.readFile("{ask}.ask") ?? return false).lines()
	outputTo("{ask}.said")
	sayingApart = true
	keepRuntime = true
	if words.len == 2:
		if words[0] == "lint":
			lintChecked(words[1])
		formatPath(words[1], false)
	sayingApart = false
	keepRuntime = false
	outputBack()
	_ = fs.writeFile("{ask}.done", "")
	true

# the file's program checked, its findings kept (lint.zap): their rewrites checked again as
# types tell, its lowering not made here (a backend's refusal ends the process)
fn lintChecked(file str):
	prog = notedProgram(file) ?? return
	if prog.checkNoted(true):
		keepFindings(prog.lintedFiles(), file, false, true)

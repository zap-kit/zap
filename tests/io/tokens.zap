# A benchmark program's tokens (std/compare) leave out its tests.

import compare
import fs

test "a program's tokens leave out its tests, a header laid over several lines too":
	dir = testDir()
	program = "print(1)\n"
	_ = fs.writeFile("{dir}plain.zap", program)
	_ = fs.writeFile(
		"{dir}tested.zap",
		"{program}\ntest \"cases\" for n in [\n\t1,\n\t2\n]:\n\texpect n > 0\n"
	)
	expect compare.tokenCount("{dir}tested.zap") == compare.tokenCount("{dir}plain.zap")

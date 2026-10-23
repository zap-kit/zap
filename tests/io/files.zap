# File and process utilities every console program needs.
#
# Process.run and Process.start with a program named the way paths are written everywhere else

import fs

path = "zap_test_output.txt"
_ = fs.writeFile(path, "line one\nline two\n")
match fs.readFile(path):
	content:
		print(content.len)
		for l in content.lines():
			if not l.isEmpty:
				print("> {l}")
	error: print("cannot read: {error}")
print(fs.exists(path))
_ = fs.deleteFile(path)
print(fs.exists(path))
print(args.len)
print(env.get("ZAP_TEST_ENV") ?? "unset")
print(fs.readFile("definitely_missing.txt") ?? "{error}")

test "files are written, read, appended and removed, a missing one giving NotFound":
	main()
	prints """
	    18
	    > line one
	    > line two
	    true
	    false
	    0
	    unset
	    NotFound
	    """

test "a program named with forward slashes starts":
	expect Process.run("{zapPath()} fmt tests/io/files.zap") == 0

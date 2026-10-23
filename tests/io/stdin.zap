# Stream processing from stdin: a wc-like count, CSV aggregation, a todo list driven by
# commands, and line filtering. Input comes from stdin.stdin.

mut lines = []
mut going = true
while going:
	match stdin.line():
		l: lines.push(l)
		none: going = false
mut words = 0
mut chars = 0
for l in lines:
	chars += l.len
	for w in l.split(" "):
		if w != "":
			words += 1
print("lines {lines.len} words {words} chars {chars}")

# section 1: CSV "name,dept,salary" until a blank line
mut i = 0
mut byDept {str: i64} = {}
mut headcount {str: i64} = {}
i += 1   # skip the header
while i < lines.len and lines[i] != "":
	cols = lines[i].split(",")
	dept = cols[1].trimmed()
	salary = i64.parse(cols[2].trimmed()) ?? 0
	byDept.add(dept, salary)
	headcount.add(dept, 1)
	i += 1
for d in byDept.keys().sorted():
	total = byDept.get(d) ?? 0
	n = headcount.get(d) ?? 1
	print("{d}: {n} people, total {total}, average {total / n}")
i += 1

# section 2: todo commands
mut todos = []
mut done = []
while i < lines.len and lines[i] != "":
	line = lines[i]
	if line.startsWith("add "):
		todos.push(line[4..])
		done.push(false)
	elif line.startsWith("done "):
		match i64.parse(line[5..]):
			k:
				if k >= 1 and k <= todos.len:
					done[k - 1] = true
				else:
					print("no such item: {k}")
			none: print("bad number")
	elif line == "list":
		for k, todo in todos:
			mark = "[ ]"
			if done[k]:
				mark = "[x]"
			print("{k + 1}. {mark} {todo}")
	else:
		print("unknown command: {line}")
	i += 1
i += 1

# section 3: grep-like filter and longest line
mut longest = -1
mut matches = []
while i < lines.len:
	if longest < 0 or lines[i].len > lines[longest].len:
		longest = i
	if "zap" in lines[i].lower():
		matches.push(lines[i].trimmed())
	i += 1
print("matches: {matches.join(" | ")}")
print("longest: {lines[longest].len} chars: {lines[longest]}")

test "stdin is counted, aggregated and filtered as a stream":
	stdin.feed("""
		name,dept,salary
		Ana, eng, 5200
		Bo, ops, 3100
		Cid, eng, 6100
		Dee, sales, 4000
		Eve, ops, 2900

		add buy milk
		add write the zap compiler
		list
		done 2
		done 7
		done x
		add sleep
		list
		frobnicate

		The Zap language compiles itself now.
		  a line with ZAP in capitals and trailing spaces
		nothing to see here
		the longest line of the whole input is probably this one right here

		""")
	main()
	prints """
	    lines 21 words 67 chars 342
	    eng: 2 people, total 11300, average 5650
	    ops: 2 people, total 6000, average 3000
	    sales: 1 people, total 4000, average 4000
	    1. [ ] buy milk
	    2. [ ] write the zap compiler
	    no such item: 7
	    bad number
	    1. [ ] buy milk
	    2. [x] write the zap compiler
	    3. [ ] sleep
	    unknown command: frobnicate
	    matches: The Zap language compiles itself now. | a line with ZAP in capitals and trailing spaces
	    longest: 67 chars: the longest line of the whole input is probably this one right here
	    """

test "readUntil stops before the byte it is given":
	stdin.feed(">a\n123>b\n4")
	print("[]" if (stdin.until('>') ?? "x").bytes().len == 0 else "?")
	print(stdin.until('\n') ?? "")
	stdin.line()
	print((stdin.until('>') ?? "").bytes().map(i64(it - '0')))
	print(stdin.until('\n') ?? "")
	stdin.line()
	print((stdin.until('>') ?? "").bytes().map(i64(it - '0')))
	print(stdin.until('>'))
	prints """
		[]
		>a
		[1, 2, 3]
		>b
		[4]
		none
		"""

test "stdin.all() gives the rest after the lines read":
	stdin.feed("""
		alpha
		beta
		gamma

		""")
	first = stdin.line() ?? "none"
	rest = stdin.all()
	print("first={first} rest={rest.len} lines={rest[..].count(10)}")
	print("{rest.trimmed()}")
	prints """
	    first=alpha rest=11 lines=2
	    beta
	    gamma
	    """

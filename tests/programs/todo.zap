# Interactive-style command loop over stdin: add/done/list/quit.
type Task:
	title str
	done bool
fn render(tasks Task[]):
	if tasks.isEmpty:
		print("(empty)")
		return
	i = 1
	for t in tasks:
		mark = "x"
		if not t.done:
			mark = " "
		print("{i}. [{mark}] {t.title}")
		i += 1
mut tasks = []
mut running = true
while running:
	match stdin.line():
		line:
			parts = line.trimmed().split(" ")
			cmd = parts[0]
			if cmd == "add":
				tasks.push(Task(title = line.trimmed()[4..line.len].copy(), done = false))
			elif cmd == "done":
				idx = (i64.parse(parts[1]) ?? 0) - 1
				if idx >= 0 and idx < tasks.len:
					tasks[idx].done = true
				else:
					print("no such task")
			elif cmd == "list":
				render(tasks)
			elif cmd == "quit":
				running = false
			else:
				print("unknown command: {cmd}")
		none: running = false
print("bye")

test "todo commands from stdin add, finish and list items":
	stdin.feed("""
		add buy milk
		add write code
		list
		done 1
		done 9
		list
		foo
		quit

		""")
	main()
	prints """
	    1. [ ] buy milk
	    2. [ ] write code
	    no such task
	    1. [x] buy milk
	    2. [ ] write code
	    unknown command: foo
	    bye
	    """

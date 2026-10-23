# `zap branch new | land | status`: the commands that manage a repository's branches, each with
# its worktree beside main's checkout. spec 13.1.5 states them.

# zap branch <new <name> | land <name>... | status>
pub fn branchCommand(line CommandLine):
	keepRepositoryConfig()
	names = line.operands[1..]
	match line.operands[0]:
		"new":
			if names.len != 1: line.refuseBranch("new takes one name")
			newCommand(names[0])
		"land":
			if names.isEmpty: line.refuseBranch("land takes a branch name or more")
			landCommand(names)
		"status":
			if not names.isEmpty: line.refuseBranch("status takes no name")
			statusCommand()
		_: line.refuseBranch("no subcommand {line.operands[0]}")

# the refusal with the command's usage, exit code 2
fn refuseBranch(line CommandLine, why str):
	c = commands.find(.name == line.command) ?? exit(2, why)
	exit(2, c.refused(why))

# zap branch status: each branch with a worktree beside main's checkout, then the lands running
fn statusCommand():
	main = mainCheckout("status")
	listed = 0
	for w in worktrees():
		if w.branch == "" or w.branch == mainBranch: continue
		print(branchLine(main, w))
		listed += 1
	if listed == 0: print("no branch has a worktree beside {main}")
	running = landsRunning(main)
	print("no land runs" if running.isEmpty else running.join("\n"))

# a branch's line: whether it is in main, its commits ahead of and behind main, its worktree
fn branchLine(main str, w Worktree):
	ahead = gitSays(main, "rev-list --count {mainBranch}..{w.branch}", "")
	behind = gitSays(main, "rev-list --count {w.branch}..{mainBranch}", "")
	where = "in main" if inMain(main, w.branch) else "not in main"
	state = "uncommitted changes" if hasUncommitted(w.path) else "clean"
	"{w.branch}: {where}, {ahead} ahead, {behind} behind, {state}"

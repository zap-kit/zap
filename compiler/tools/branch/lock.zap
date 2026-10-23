# The lock of zap branch land, across a repository's worktrees and sessions: held while a land takes
# its checkout and while it moves main, never through a suite (land.zap). It
# is a ref of the common git dir naming an object that holds the id of the process holding it,
# taken and handed over by git's compare-and-swap of a ref (update-ref with the old value), so two
# lands never both take it; one whose process ended is taken over.

# the ref of the lock, shared by every worktree of the repository
landLockRef = "refs/zap/land"

# the lock taken for this process, waiting while a running process holds it: the object naming it
fn takeLandLock(root str):
	mine = gitSays(root, "hash-object -w --stdin", "{processId()}\n")
	if mine == "-": exit(1, "land: git cannot write in the repository at {root}")
	absent = "0".repeat(mine.len)   # update-ref's old value for a ref that must not exist yet
	waiting = false
	while gitSays(root, "update-ref {landLockRef} {mine} {absent}", "") == "-":
		held = gitSays(root, "rev-parse --verify --quiet {landLockRef}", "")
		if held == "-": continue   # let go meanwhile
		pid = lockPid(root, held)
		if pid > 0 and processRuns(pid):
			if not waiting:
				print("land: waiting for the land of process {pid}")
				waiting = true
			sleepMs(1000)
		elif gitSays(root, "update-ref {landLockRef} {mine} {held}", "") != "-":
			print("land: took over the lock of process {pid}, which ended")
			return mine
	mine

# the process the lock object names, -1 when it names none
fn lockPid(root str, held str):
	i64.parse(gitSays(root, "cat-file blob {held}", "")) ?? -1

# the lock let go, unless another land took it over meanwhile
fn releaseLandLock(root str, mine str):
	_ = gitSays(root, "update-ref -d {landLockRef} {mine}", "")

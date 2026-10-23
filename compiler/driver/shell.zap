# The command lines zap gives the host's shell (the runtime's shellLine): Windows' cmd, or
# Linux's sh. Each helper says one thing a line does the two ways (the runtime's quoteArg and
# withVariable too, which std's programs use).

# what sends a stream nowhere: `> {nullDevice()}`
fn nullDevice():
	"nul" if onWindows() else "/dev/null"

# the line run in dir
fn inDir(dir str, line str):
	if onWindows(): return "cd /d {quoteArg(dir.replace("/", "\\"))} && {line}"
	"cd {quoteArg(dir)} && {line}"

# a path as the host's shell names it
fn hostPath(path str):
	path.replace("/", "\\") if onWindows() else path

# the process with this id ended, its children with it (on Linux each one's listed before it ends,
# as the shell a process starts in, sh -c, may stay the parent of what it runs); the kill is given
# 30 s, so a process that cannot be killed never holds the caller
fn killProcessTree(pid i64):
	line = "taskkill /T /F /PID {pid}" if onWindows()
		else "t() \{ c=$(pgrep -P $1); kill -9 $1; for k in $c; do t $k; done; }; t {pid}"
	killer = Process.start(shellLine("{line} > {nullDevice()} 2>&1"))
	_ = killer.waitWithin(30_000)

# the line that moves a file to another path, replacing what is there
fn moveLine(from str, to str):
	if onWindows(): return "move /y {quoteArg(hostPath(from))} {quoteArg(hostPath(to))} > nul"
	"mv -f {quoteArg(from)} {quoteArg(to)}"

# whether a process with this id runs
fn processRuns(pid i64):
	if onWindows():
		tasks = Process.output("tasklist /FI \"PID eq {pid}\" /NH /FO CSV").out
		return tasks.indexOf("\"{pid}\"") != none
	Process.run(shellLine("kill -0 {pid} 2> {nullDevice()}")) == 0

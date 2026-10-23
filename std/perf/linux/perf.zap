# The counted runs on Linux: the program is forked and waits at a gate (a pipe) while the
# counters are opened on it, enabled when it execs, inherited by its threads and children
# (perf_event_open, user space only, as kernel.perf_event_paranoid=2 allows); a sampler is one
# event a processor it may run on, each writing its samples (the instruction's address and the
# thread) to a ring of pages read while the program runs. The program's end is waited for on a
# pidfd with the time limit; its memory is capped by the writable memory it may map (RLIMIT_DATA,
# set in the fork: what it commits, not what the runtime only reserves, past which the system
# refuses memory as Windows' job does), and wait4 gives its exit and its peak (ru_maxrss).

import fs

extern "syscall perf_event_open" fn sysPerfEventOpen(
	attr u8[],
	pid i64,
	cpu i64,
	group i64,
	flags i64
) i64
extern "syscall pidfd_open" fn sysPidfdOpen(pid i64, flags i64) i64
extern "syscall ppoll" fn sysPpoll(fds u8[], n i64, timeout u8[], mask i64, size i64) i64
extern "syscall kill" fn sysKill(pid i64, signal i64) i64
extern "syscall prlimit64" fn sysPrlimit64(pid i64, resource i64, limit u8[], old i64) i64
extern "syscall wait4" fn sysWait4Usage(pid i64, status u8[], options i64, usage u8[]) i64

# PERF_COUNT_HW_*: the events counted, in Counts' order
eventInstructions = 1
eventCycles = 0
eventCacheMisses = 3
eventBranchMisses = 5
countedEvents = [eventInstructions, eventCycles, eventCacheMisses, eventBranchMisses]

# perf_event_attr's flags: disabled, inherit, exclude_kernel, exclude_hv, enable_on_exec; a
# sampler's also watermark (woken when its ring is half full)
countFlags = 1 | 2 | 32 | 64 | 4096
watermarkFlag = 16_384

# a sampler's ring: this many pages after its header page
ringPages = 64

closeOnExec = 0x8_0000

# RLIMIT_DATA
limitWritableMemory = 2

# What a program maps writable besides the memory it holds, over its limit: its main stack (128 MB,
# which the runtime maps whole) and its image
reservedBytes = 192 * 1_048_576

pub fn canCount() bool:
	attr = eventAttr(eventInstructions, 0)
	fd = sysPerfEventOpen(attr, 0, -1, -1, 8)   # PERF_FLAG_FD_CLOEXEC
	if rt.failed(fd): return false
	_ = rt.sysClose(fd)
	true

# a perf_event_attr of a hardware event: counted, or sampled every period events (the
# instruction's address and the thread's ids each)
fn eventAttr(event i64, period i64) u8[]:
	a = rt.zeroBytes(128)
	a.setU32le(4, 128)   # its size; type 0, PERF_TYPE_HARDWARE
	a.setU64le(8, u64.wrap(event))
	flags = countFlags
	if period > 0:
		a.setU64le(16, u64.wrap(period))
		a.setU64le(24, 3)   # PERF_SAMPLE_IP | PERF_SAMPLE_TID
		a.setU32le(48, u32.wrap(ringPages * rt.pageBytes() / 2))   # wakeup_watermark
		flags |= watermarkFlag
	else:
		a.setU64le(32, 3)   # read_format: the times enabled and running, to scale a shared counter
	a.setU64le(40, u64.wrap(flags))
	a

# A file opened for the program's stdin, or created for its stdout, closed by an exec of this
# program's own (-1 when it cannot be)
fn openStream(path str, writing bool) i64:
	flags = (0x241 if writing else 0) | closeOnExec   # O_WRONLY | O_CREAT | O_TRUNC
	fd = rt.sysOpenat(-100, rt.cstr(path), flags, 420)   # AT_FDCWD, mode 644
	-1 if rt.failed(fd) else fd

# A program forked, waiting at its gate to exec the line: its pid and the gate's end that lets it
# go (written to) or ends it (closed); (-1, -1) when it cannot start
fn startGated(line str, inputPath str, outPath str, limitMb i64) (i64, i64):
	words = rt.commandWords(line.bytes())
	if words.isEmpty: return (-1, -1)
	program = rt.programPath(words[0]) ?? return (-1, -1)
	path = rt.cstr(program)
	input = -1 if inputPath == "" else openStream(inputPath, false)
	output = -1 if outPath == "" else openStream(outPath, true)
	ends = rt.zeroBytes(8)
	if rt.failed(rt.sysPipe2(ends, closeOnExec)): return (-1, -1)
	gate = i64(ends.u32le(0))
	opener = i64(ends.u32le(4))
	opened = rt.zeroBytes(1)
	argBlock, argv = rt.cStringArray(words)
	envBlock, envp = rt.cStringArray(rt.childEnvironment([]))
	capBytes = u64.wrap(limitMb * 1_048_576 + reservedBytes)
	cap = rt.zeroBytes(16)
	cap.setU64le(0, capBytes)
	cap.setU64le(8, capBytes)
	rt.flushStdout()
	pid = rt.sysClone(17, 0, 0, 0, 0)   # SIGCHLD: a fork
	if pid == 0:
		_ = rt.sysClose(opener)
		if limitMb > 0: _ = sysPrlimit64(0, limitWritableMemory, cap, 0)
		if rt.sysRead(gate, opened, 1) != 1: _ = rt.sysExitGroup(127)
		if input >= 0: _ = rt.sysDup3(input, 0, 0)
		if output >= 0: _ = rt.sysDup3(output, 1, 0)
		_ = rt.sysExecve(path, argv, envp)
		_ = rt.sysExitGroup(127)
	rt.freePages(argBlock)
	rt.freePages(envBlock)
	for fd in [gate, input, output]:
		if fd >= 0: _ = rt.sysClose(fd)
	if rt.failed(pid):
		_ = rt.sysClose(opener)
		return (-1, -1)
	(pid, opener)

# A sampler's event on one processor and its ring: the event's descriptor, the ring's address
# (its header page, then the samples' pages)
type Ring:
	fd i64
	at i64

# the processors this program may run on (sched_getaffinity), which what it starts inherits
fn allowedProcessors() i64[]:
	mask = rt.zeroBytes(128)
	n = rt.sysSchedGetaffinity(0, 128, mask)
	(0..8 * n.max(0)).filter((mask[it / 8] >> (it % 8)) & 1 == 1)

# the rings of the event sampled every period on each processor the pid may run on; none where
# one cannot be opened
fn openRings(pid i64, event i64, period i64) Ring[]:
	attr = eventAttr(event, period)
	size = (ringPages + 1) * rt.pageBytes()
	rings = []
	for cpu in allowedProcessors():
		fd = sysPerfEventOpen(attr, pid, cpu, -1, 8)
		if rt.failed(fd): continue
		at = rt.sysMmap(0, size, 3, 1, fd, 0)   # PROT_READ | PROT_WRITE, MAP_SHARED
		if rt.failed(at):
			_ = rt.sysClose(fd)
			continue
		rings.push(Ring(fd, at))
	rings

# The samples a ring holds, their addresses added to `addresses` and the ring given back to the
# kernel (perf_event_mmap_page: data_head at 1024, data_tail at 1032; a record, its type, its
# size, then for a sample its address and ids, may wrap past the ring's end)
fn drain(ring Ring, mut addresses i64[]):
	page = rt.pageBytes()
	size = ringPages * page
	data = ring.at + page
	head = rt.wordAtAddress(ring.at + 1024)
	tail = rt.wordAtAddress(ring.at + 1032)
	record = rt.zeroBytes(8)
	word = rt.zeroBytes(8)
	while tail < head:
		copyWrapped(data, size, tail, record)
		bytes = i64(record.u16le(6))
		if bytes < 8: break
		if record.u32le(0) == 9:   # PERF_RECORD_SAMPLE
			copyWrapped(data, size, tail + 8, word)
			addresses.push(i64.wrap(word.u64le(0)))
		tail += bytes
	rt.copyToAddress(ring.at + 1032, [tail])

# into's bytes from the ring of size bytes at data, from offset at (past its end, from its start)
fn copyWrapped(data i64, size i64, at i64, mut into u8[]):
	from = at % size
	if from + into.len <= size:
		rt.copyFromAddress(into, data + from)
		return
	piece = rt.zeroBytes(1)
	for i in 0..into.len:
		rt.copyFromAddress(piece, data + (at + i) % size)
		into[i] = piece[0]

fn closeRings(rings Ring[]):
	size = (ringPages + 1) * rt.pageBytes()
	for ring in rings:
		_ = rt.sysMunmap(ring.at, size)
		_ = rt.sysClose(ring.fd)

# a counter's value, scaled up when it shared the processor's counters with others (read_format:
# the value, the times enabled and running); 0 when it was never counted
fn counterValue(fd i64) i64:
	if fd < 0: return 0
	read = rt.zeroBytes(24)
	if rt.sysRead(fd, read, 24) != 24: return 0
	value = i64.wrap(read.u64le(0))
	enabled = i64.wrap(read.u64le(8))
	running = i64.wrap(read.u64le(16))
	if running <= 0: return 0
	if running >= enabled: return value
	i64(f64(value) * f64(enabled) / f64(running))

pub fn runCounted(
	line str,
	inputPath str,
	outPath str,
	limitMb i64 = 0,
	limitSeconds f64 = 0.0,
	samplePeriod i64 = 0,
	sampleCycles bool = false
) CountedRun:
	pid, opener = startGated(line, inputPath, outPath, limitMb)
	if pid < 0: return CountedRun(code = -1)
	# a sampled run counts nothing: the counters would share the processor's few with the sampler,
	# which would then see part of the run
	counted i64[] = [] if samplePeriod > 0 else countedEvents.copy()
	counters = counted.map(e:
		fd = sysPerfEventOpen(eventAttr(e, 0), pid, -1, -1, 8)
		-1 if rt.failed(fd) else fd
	)
	rings Ring[] = [] if samplePeriod <= 0
		else openRings(pid, eventCycles if sampleCycles else eventInstructions, samplePeriod)
	t0 = clockSeconds()
	_ = rt.sysWrite(opener, [u8(1)], 1)   # the gate opened: it execs, its counters enabled
	_ = rt.sysClose(opener)
	run = CountedRun(code = -1)
	ending = waitEnd(pid, rings, limitSeconds, run.addresses)
	run.overTime = ending == endedOverTime
	run.seconds = limitSeconds if run.overTime else clockSeconds() - t0
	status = rt.zeroBytes(8)
	usage = rt.zeroBytes(144)   # a struct rusage: ru_maxrss, in KB, at byte 32
	_ = sysWait4Usage(pid, status, 0, usage)
	s = i64(status.u32le(0))
	run.code = (s >> 8) & 255 if s & 127 == 0 else 128 + (s & 127)
	run.peakBytes = i64.wrap(usage.u64le(32)) * 1024
	limit = limitMb * 1_048_576
	run.overMemory = limitMb > 0 and run.code != 0 and run.peakBytes >= limit - limit / 8
	micros = usage.i64le(8) + usage.i64le(24)   # ru_utime's and ru_stime's microseconds
	run.processorSeconds = f64(usage.i64le(0) + usage.i64le(16)) + f64(micros) / 1e6
	for ring in rings:
		drain(ring, run.addresses)
	closeRings(rings)
	if counters.len == countedEvents.len:
		values = counters.map(counterValue(it))
		run.counts = Counts(
			instructions = values[0],
			cycles = values[1],
			cacheMisses = values[2],
			branchMisses = values[3]
		)
	for fd in counters:
		if fd >= 0: _ = rt.sysClose(fd)
	run

# how a waited program ended: by itself, or killed past its time
endedItself = 0
endedOverTime = 1

# Waits for the program to end (its pidfd readable), its rings drained whenever one is half full;
# it is killed when still running at limitSeconds (0: no limit). How it ended.
fn waitEnd(pid i64, rings Ring[], limitSeconds f64, mut addresses i64[]) i64:
	pidfd = sysPidfdOpen(pid, 0)
	if rt.failed(pidfd): return endedItself   # (wait4 waits for it)
	fds = rt.zeroBytes(8 * (1 + rings.len))
	fds.setU32le(0, u32.wrap(pidfd))
	for i, ring in rings:
		fds.setU32le(8 * (i + 1), u32.wrap(ring.fd))
	for i in 0..1 + rings.len:
		fds.setU16le(8 * i + 4, 1)   # POLLIN
	deadline = clockSeconds() + (limitSeconds if limitSeconds > 0.0 else 1e7)
	ending = endedOverTime
	while true:
		left = deadline - clockSeconds()
		if left <= 0.0: break
		timeout = rt.zeroBytes(16)
		nanos = i64(left * 1e9)
		timeout.setU64le(0, u64.wrap(nanos / 1_000_000_000))
		timeout.setU64le(8, u64.wrap(nanos % 1_000_000_000))
		rt.blockingBegin()
		_ = sysPpoll(fds, 1 + rings.len, timeout, 0, 8)
		rt.blockingEnd()
		if fds.u16le(6) != 0:
			ending = endedItself
			break
		for ring in rings:
			drain(ring, addresses)
	if ending != endedItself:
		killTree(pid)
	_ = rt.sysClose(pidfd)
	ending

# the process killed with every process it started, and theirs (a pool's workers would outlive
# it), each stopped and its children listed before it goes (/proc/<pid>/task/<tid>/children)
fn killTree(pid i64):
	_ = sysKill(pid, 19)   # SIGSTOP: it starts no other meanwhile
	for c in childrenOf(pid):
		killTree(c)
	_ = sysKill(pid, 9)

# the processes the process started that run now (/proc/<pid>/task/<tid>/children)
pub fn childrenOf(pid i64) i64[]:
	found i64[] = []
	for task in fs.list("/proc/{pid}/task") ?? []:
		for child in (fs.readFile("/proc/{pid}/task/{task}/children") ?? "").split(" "):
			if i64.parse(child.trimmed()) is c:
				found.push(c)
	found

# the memory a process holds now (its resident pages, /proc/<pid>/statm's second field)
pub fn residentBytes(pid i64) i64:
	words = (fs.readFile("/proc/{pid}/statm") ?? "").split(" ")
	(i64.parse(words[1]) ?? 0) * rt.pageBytes() if words.len > 1 else 0

# The frame clock, and what every program of the engine shares from the command line: a frame
# limit (`--frames N` runs N frames and ends, for a check that needs no one at the screen), no
# vsync (`--uncapped`), the last frame saved (`--shot x.png`), what the frames cost, summed up
# at the end (`--frametimes`, printFrames), a measured run (`--bench N`) and a fixed step
# (`--step MS`: every frame lasts MS milliseconds whatever the clock says, so a scripted run draws
# the same pictures every time). A scripted run (`--frames`, `--shot`, `--replay`, `--bench`, or
# ZAP_RUN has headless) is headless: no window shown, the frames drawn offscreen, the input the
# script's (isHeadless).

import image

# kept by tick
pub type Clock:
	last f64
	fpsStart f64
	fpsFrames i64
	fps i64   # frames per second, counted over the last half second (the step's, with one)
	elapsed f64   # seconds since the clock started
	step f64   # seconds every tick lasts (`--step`), 0: the time that passed

pub fn newClock() Clock:
	now = clockSeconds()
	step = (f64.parse(args.option("--step") ?? "") ?? 0.0) / 1000.0
	Clock(last = now, fpsStart = now, fpsFrames = 0, fps = 0, elapsed = 0.0, step = step.max(0.0))

# the seconds since the last tick (at most a tenth: a stall does not make things jump), or the
# clock's fixed step
pub fn tick(mut c Clock) f32:
	now = clockSeconds()
	dt = c.step if c.step > 0.0 else (now - c.last).min(0.1)
	c.elapsed += dt
	c.last = now
	c.fpsFrames += 1
	if c.step > 0.0:
		c.fps = i64((1.0 / c.step).round())   # a picture of a stepped run shows no clock
	elif now - c.fpsStart >= 0.5:
		c.fps = i64((c.fpsFrames / (now - c.fpsStart)).round())
		c.fpsFrames = 0
		c.fpsStart = now
	f32(dt)

# ---------- what the frames cost ----------

# Each frame's interval from the one before (what the player sees) and its work, from its start
# until it was handed to the screen (the rest of the interval is waiting for it), in milliseconds.
pub type FrameTimes:
	intervals f64[] = []
	work f64[] = []
	last f64 = -1.0   # when the last frame began (seconds; -1: none yet)

# a frame that began at `began` and was handed over at `worked` (seconds)
pub fn logFrame(mut t FrameTimes, began f64, worked f64):
	if t.last >= 0.0:
		t.intervals.push((began - t.last) * 1000.0)
	t.last = began
	t.work.push((worked - began) * 1000.0)

# "name: mean, deviation, median, 95%, 99% and worst" of milliseconds
pub fn timesText(name str, ms f64[]) str:
	if ms.isEmpty: return "{name}: none"
	mean = ms.sum() / ms.len
	deviation = (ms.map((it - mean) * (it - mean)).sum() / ms.len).sqrt()
	s = ms.sorted()
	at = (q f64): s[i64(((len - 1) * q).round())]
	"{name}: mean {mean:.2} ms, deviation {deviation:.2}, median {at(0.5):.2}, 95% {at(0.95):.2}, 99% {at(0.99):.2}, worst {s[s.len - 1]:.2}"

# The summary printed: the intervals, the work, and the frames that came late (over 1.5 times the
# median interval), past the first `skip` frames (a program's first frames upload its textures).
pub fn printTimes(t FrameTimes, skip i64 = 0):
	intervals = t.intervals[skip.min(len)..]
	print(timesText("frame interval", intervals))
	print(timesText("work", t.work[skip.min(len)..]))
	if not intervals.isEmpty:
		median = intervals.sorted()[intervals.len / 2]
		late = (0..intervals.len)
			.filter(intervals[it] > median * 1.5)
			.map(it + skip + 1)
		print("late frames: {late.len} of {intervals.len}, frames {late}")

# ---------- a measured run ----------

# The frames before a measured run starts counting: pipelines made, shaders compiled on first use.
pub benchWarmUp = 60

# What a measured run spent from its warm-up's end: the clock, the processor's seconds and cycles
# (every thread), then reported past `frames` frames.
pub type Bench:
	frames i64
	seconds f64 = 0.0
	cpuSeconds f64 = 0.0
	cycles i64 = 0

fn startBench(mut b Bench):
	b.seconds = clockSeconds()
	b.cpuSeconds = processorSeconds()
	b.cycles = processorCycles()

# The lines a measured run prints (the PC port's harness prints the same): the time of the frames,
# the processor's time and cycles a frame, the memory.
fn printBench(b Bench):
	seconds = clockSeconds() - b.seconds
	cpu = processorSeconds() - b.cpuSeconds
	n = f64(b.frames.max(1))
	print("bench: {b.frames} frames in {seconds:.3} s = {(n / seconds):.1} fps, {(seconds * 1000.0 / n):.3} ms a frame")
	print("bench: cpu {cpu:.3} s ({(cpu * 1000.0 / n):.3} ms a frame, {(cpu / seconds):.2} cores)")
	print("bench: cycles {(processorCycles() - b.cycles) / b.frames.max(1)} a frame")
	print("bench: memory peak {(peakMemory() / 1048576.0):.1} MB, private {(memoryCommitted() / 1048576.0):.1} MB")

# ---------- the frames of a program ----------

# The frames a program runs: its clock, how many were shown, the limit `--frames N` sets (-1:
# none) for a run that needs no one at the screen, the seconds the frame being made covers, what
# the frames cost (kept with `--frametimes`) and a measured run (`--bench N`: after the warm-up,
# N frames as fast as they go, no vsync, then the lines printBench says; `bench` is -1 without).
pub type Frames:
	clock Clock
	count i64
	limit i64
	dt f32
	times FrameTimes = FrameTimes()
	keepTimes bool = false
	started f64 = -1.0   # when the first frame began (seconds; -1: none yet)
	began f64 = 0.0   # when this frame began
	bench i64 = -1
	measured Bench = Bench(frames = 0)

# the limit, `--frametimes` and `--bench` come from the command line
pub fn newFrames() Frames:
	bench = i64.parse(args.option("--bench") ?? "") ?? -1
	Frames(
		clock = newClock(),
		count = 0,
		limit = benchWarmUp + bench if bench >= 0 else i64.parse(args.option("--frames") ?? "") ?? -1,
		dt = 0.0,
		keepTimes = args.hasFlag("--frametimes"),
		bench,
		measured = Bench(frames = bench.max(0))
	)

# Begins the next frame: the window's messages read, the clock ticked, the GPU's frame begun
# (waiting while the window is minimized). False when the program ends instead: the window
# closed, Esc pressed (when `escEnds`), the frame limit reached (a measured run prints its lines
# then). Before the first frame, `--uncapped` (or `--bench`) turns vsync off.
pub fn nextFrame(mut w Window, mut f Frames, escEnds bool = true) bool:
	if f.started < 0.0:
		f.started = clockSeconds()
		if args.hasFlag("--uncapped") or f.bench >= 0:
			setVsync(false)
	if f.bench >= 0 and f.count == benchWarmUp:
		f.measured.startBench()
	if not w.pollEvents() or (escEnds and isKeyPressed(.Escape)) or
		(f.limit >= 0 and f.count >= f.limit):
		if f.bench >= 0 and f.count > benchWarmUp:
			f.measured.printBench()
		return false
	while not w.startFrame():
		sleepMs(16)
		if not w.pollEvents(): return false
	f.dt = f.clock.tick()
	f.began = clockSeconds()
	true

# "N frames in S s: F fps", counted from the first frame's start to now
pub fn fpsText(f Frames) str:
	framesText(f.count, 0.0 if f.started < 0.0 else clockSeconds() - f.started)

# "N frames in S s: F fps"
pub fn framesText(count i64, took f64) str:
	"{count} frames in {took:.2} s: {(count / took.max(0.001)):.0} fps"

# what the frames cost, summed up (with `--frametimes`; nothing without it), past the first `skip`
pub fn printFrames(f Frames, skip i64 = 0):
	if f.keepTimes:
		f.times.printTimes(skip)

# whether this is the last frame of a frame limit
pub fn isLastFrame(f Frames) bool:
	f.limit >= 0 and f.count == f.limit - 1

# Ends a frame the renderer drew, and shows it: on the last frame of a limit it is written to
# the `--shot` file as well.
pub fn showFrame(mut r Renderer, w Window, mut f Frames):
	if f.keepTimes:
		f.times.logFrame(f.began, clockSeconds())
	# the command line read on the last frame only: reading it makes a list of every argument
	path = (args.option("--shot") ?? "") if f.isLastFrame() else ""
	if path != "":
		r.screenshot().savePng(path) ?? eprint("cannot write {path}: {error}")
	else:
		r.endFrame()
		w.present()
	f.count += 1

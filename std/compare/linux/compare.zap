# The measured runs on Linux (the compiler's target.zap): std/perf starts the program, kills it
# past its memory (what it holds), and counts it from its first instruction: its cycles,
# instructions, cache and branch misses; where the processor's counters are not open to a user's
# program, its processor time stands for its cycles (nanoseconds: cycles at 1 GHz).

import perf

pub fn runMeasured(line str, inputPath str, outPath str, limitMb i64, limitSeconds f64 = 0.0) Run:
	input = "/dev/null" if inputPath == "" else inputPath.copy()
	counted = perf.runCounted(line, input, outPath, limitMb, limitSeconds)
	counts = counted.counts
	cycles = counts.cycles if counts.cycles > 0 else i64(counted.processorSeconds * 1e9)
	Run(
		seconds = counted.seconds,
		peakBytes = counted.peakBytes,
		cycles,
		code = counted.code,
		overMemory = counted.overMemory,
		overTime = counted.overTime,
		instructions = counts.instructions,
		cacheMisses = counts.cacheMisses,
		branchMisses = counts.branchMisses
	)

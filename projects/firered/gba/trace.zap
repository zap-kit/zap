import cpu

# The functions last entered, kept when the program was prepared with --trace: what the game
# was doing when it stopped, each with its lr and r0. `--break key,n` ends the run at the n-th
# entry of the function (its key: the address, bit 0 set for Thumb), as at the end of
# `--frames` (the dump, the hash).

mut recent u32[] = zeros(64)
mut recentLr u32[] = zeros(64)
mut recentR0 u32[] = zeros(64)
mut recentSp u32[] = zeros(64)
mut recentCount = 0
breakAt = args.optionNumbers("--break")
mut breakHits = 0

pub fn entered(k u32):
	recent[recentCount & 63] = k
	recentLr[recentCount & 63] = cpu.r14
	recentR0[recentCount & 63] = cpu.r0
	recentSp[recentCount & 63] = cpu.r13
	recentCount += 1
	if breakAt.len == 2 and i64(k) == breakAt[0]:
		breakHits += 1
		if breakHits == breakAt[1]: finish()

pub fn recentText() str:
	n = recentCount.min(64)
	(0..n).map(i:
		at = (recentCount - n + i) & 63
		"{recent[at]:08X} (lr {recentLr[at]:08X} r0 {recentR0[at]:08X} sp {recentSp[at]:08X})"
	).join("\n")

# stops the game with the reason and the functions last entered
pub fn stop(why str):
	fail("{why}\nlast functions entered:\n{recentText()}")

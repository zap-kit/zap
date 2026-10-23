# A run's input played from a script instead of read, for a run that needs no one at the screen:
# `--replay "30:move 700 400;31:ldown;40:down w"`, steps parted by `;`, each a frame, a verb and
# the verb's words. What the verbs do is the program's.

pub type ReplayStep:
	frame i64
	verb str
	words str[]

# the steps of the `--replay` script (none without one)
pub fn replaySteps() ReplayStep[]:
	out = []
	for part in (args.option("--replay") ?? "").split(";"):
		words = part.replace(":", " ").words()
		if words.len < 2: continue
		out.push(ReplayStep(
			frame = i64.parse(words[0]) ?? 0,
			verb = words[1],
			words = words[2..].map(.copy())))
	out

# word k of the step as a number, 0 when it has none
pub fn number(s ReplayStep, k i64) i64:
	(i64.parse(s.words[k]) ?? 0) if k < s.words.len else 0

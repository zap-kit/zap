# Plays a level by itself for a number of frames and prints what happened: the readers and the
# mechanics checked without a window.
#   zap run projects/lemmings/check.zap [--rating 0..3] [--level 1..30] [--frames n]

import dos.lemmings
import game

dir = args.option("--install") ?? lemmings.defaultInstall
frames = i64.parse(args.option("--frames") ?? "600") ?? 600
g = game.chosenGame(dir)
print(
	"{g.level.name}: {g.level.lemmings} lemmings, {g.level.toRescue} to save, rate {g.releaseRate}"
)
route = game.parseRoute(args.option("--route") ?? "")
loop frames:
	g.step()
	for line in g.runRoute(route):
		print(line)
	for c in g.cues:
		print("cue {c} at iteration {g.iteration}")
	g.cues.clear()
alive = g.lemmings.count(not .removed)
print("after {frames} frames: iteration {g.iteration}, released {g.released}, out {g.out}, saved {g.saved}, removed {g.removedCount}, alive {alive}")
for i, l in g.lemmings:
	if i < 5:
		print("  lemming {i}: {l.action} at {l.x}, {l.y} facing {l.dx}")

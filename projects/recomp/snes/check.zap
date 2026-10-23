# A recompiled game checked against Mesen 2 over a long run with a player's input: a route of
# random buttons (the same for a seed: held from a few frames to a second, Start now and then)
# played by both from power-on, every frame's picture and work RAM compared. Run from the
# repository root, the game prepared and built first (main.zap --build):
#
#   zap run projects/recomp/snes/check.zap <rom.sfc> <frames> [--seed n] [--every n | --self] [--exe build/<name>.exe]
#
# prints compare.zap's verdict: how many frames match, the first that does not.

import fs
import recomp.snes.mesen

buttons = ["b", "y", "a", "x", "l", "r", "up", "down", "left", "right"]

# The route's lines "frame buttons": a step every 4 to 60 frames, up to three buttons held
# (a direction and one or two others), Start one step in 25, nothing one in 6.
fn randomRoute(frames i64, seed i64):
	rng = Random(seed)
	lines = []
	frame = 1
	while frame < frames:
		held = []
		roll = rng.nextInt(0, 150)
		if roll < 6:
			held.push("start")
		elif roll >= 25:
			loop rng.nextInt(1, 4):
				name = buttons[rng.nextInt(0, len)]
				if not (name in held): held.push(name.copy())
		lines.push("{frame} {held.join(",") if not held.isEmpty else "none"}")
		frame += rng.nextInt(4, 61)
	"{lines.join("\n")}\n"

paths = args.filter(
	not .startsWith("--") and
		not (
			it in [
				args.option("--seed") ?? "",
				args.option("--exe") ?? "",
				args.option("--every") ?? ""
			]
		)
)
if paths.len < 2:
	fail("usage: zap run projects/recomp/snes/check.zap <rom.sfc> <frames> [--seed n] [--exe file]")
romPath = paths[0]
frames = i64.parse(paths[1]) ?? fail("frames: a number, not {paths[1]}")
seed = i64.parse(args.option("--seed") ?? "1") ?? 1
name = fs.stem(romPath).replace(" ", "_")
exe = args.option("--exe") ?? "build/{name}{exeSuffix()}"
base = "build/check-{name}-{seed}"
route = "{base}-route.txt"
fs.writeFile(route, randomRoute(frames, seed)) ?? fail("cannot write {route}: {error}")
# The oracle: Mesen 2's hashes, or with --self the same build interpreting every instruction
# (cpu/interpret.zap), which checks the translation alone at the build's own speed, beside it.
oracleText = "{base}-mesen.txt" if not args.hasFlag("--self") else "{base}-interpreted.txt"
playing = Process.start(
	"{exe} --headless --frames {frames} --route {route} --hashes {base}-zap.txt"
)
if args.hasFlag("--self"):
	interpreted = Process.run(
		"{exe} --headless --interpret --frames {frames} --route {route} --hashes {oracleText}"
	)
	if interpreted != 0:
		print("{exe} --interpret stopped before frame {frames} (exit {interpreted})")
else:
	every = args.option("--every") ?? "1"   # Mesen hashes every n-th frame: n times faster, as strict where it looks
	mesen.runOracle("hashes", romPath, frames, oracleText, route, {"SNESRECOMP_EVERY": every})
played = playing.wait()
if played != 0: print("{exe} stopped before frame {frames} (exit {played})")
exit(Process.run("{zapPath()} run projects/recomp/snes/compare.zap {oracleText} {base}-zap.txt"))

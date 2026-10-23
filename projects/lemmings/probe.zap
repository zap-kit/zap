# Hovers the DOS cursor over a spot of a level for a run of iterations without clicking, and keeps
# the DOS memory at each (compare.zap --mem), to read which lemming the game picks under the cursor:
#   zap run projects/lemmings/probe.zap --rating R --level L --from N --spots "x:y x:y ..."
# One spot per iteration from N, the cursor at the DOS screen's x and y (8..328, 8..200).
# --press: the spots are clicks, --every k iterations apart, after a click on panel button
# --buttons "b ..." (0-based, 2 is the climber) one per 20 clicks, each pressed before its clicks; the memory is kept at
# every iteration of the run.

import dos.lemmings
import fs
import tools

dir = args.option("--install") ?? lemmings.defaultInstall
rating = i64.parse(args.option("--rating") ?? "0") ?? 0
number = (i64.parse(args.option("--level") ?? "1") ?? 1) - 1
from = i64.parse(args.option("--from") ?? "100") ?? 100
code = "" if rating + number == 0 else lemmings.accessCode(rating * 30 + number, 100)
out = fs.join(
	currentDir(),
	"projects/lemmings/assets/oracle/{lemmings.ratings[rating]}{number + 1}/probe".lower()
)
press = args.hasFlag("--press")
every = i64.parse(args.option("--every") ?? "1") ?? 1
buttons = (args.option("--buttons") ?? "2").words().map(i64.parse(it) ?? 2)
clicks = []
dumps = []
spots = (args.option("--spots") ?? "").words()
for i, spot in spots:
	xy = spot.split(":")
	clicks.push(
		tools.Click(
			iteration = from + i * every,
			x = i64.parse(xy[0]) ?? 0,
			y = i64.parse(xy[1]) ?? 0,
			held = every,
			button = press
		)
	)
	if press and i % 20 == 0:
		b = buttons[(i / 20).min(len - 1)]
		clicks.push(
			tools.Click(iteration = from + i * every - 3, x = b * 16 + 16, y = 196, held = 1)
		)
	if not press: dumps.push(from + i * every + every - 1)
if press:
	dumps = (from - 2..from + spots.len * every).map(it)
# --plain-to n: no clicks, the memory kept from N to n
plainTo = i64.parse(args.option("--plain-to") ?? "") ?? 0
if plainTo > 0:
	dumps = (from..=plainTo).map(it)
tools.OracleRun(
	install = dir.copy(),
	out = out.copy(),
	keys = tools.levelKeys(code),
	levelFrame = tools.levelFrame(code),
	clicks,
	iterations = (from + spots.len * every + 2).max(plainTo + 1),
	dumps
).playDos()
print("memory dumps in {out}")

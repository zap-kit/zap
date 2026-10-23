# Plays a level with a route in the DOS game (tools/oracle.zap) and in this build, and compares
# the level area pixel by pixel per game iteration: prints the first iteration that differs and
# writes the pair (and where they differ) as PNGs.
#   zap run projects/lemmings/compare.zap [--route "digger@200 ..."] [--iterations n] [--fresh]
#     [--sim-route "..."] [--offset k] [--dump] [--go-on] [--rating 0..3 --level 1..30 [--code ABCDEFGHIJ]]
#   needs: C:/Games/Lemmings (the DOS game's files, never committed) and BizHawk
# The DOS game's iterations are read from its counter; the two are aligned once by content (the
# offset that makes the most of the first pictures the same) and the oracle's clicks are put at
# the iterations the offset gives. A level past the first is reached by its access code, the
# player's own, typed into the game.

import dos.lemmings
import fs
import game
import image
import tools

dir = args.option("--install") ?? lemmings.defaultInstall
route = args.option("--route") ?? ""
iterations = i64.parse(args.option("--iterations") ?? "400") ?? 400
rating = game.chosenRating()
number = game.chosenNumber()
# the level's access code, typed into the DOS game's F2 screen: the one asked for, else the
# scheme's for the level (the first level needs none)
code = args.option("--code") ??
	("" if rating + number == 0 else lemmings.accessCode(rating * 30 + number, 100))
base = fs.join(
	currentDir(),
	"projects/lemmings/assets/oracle/{lemmings.ratings[rating]}{number + 1}".lower()
)
main = lemmings.loadMainData(dir)

# a colour as the VGA DAC holds it (6 bits a channel), from either side's 8 bits
fn vga(c image.Rgba8, dos bool):
	if dos:
		return image.Rgba8(
			(i64(c.r) * 63 + 127) / 255 << 2,
			(i64(c.g) * 63 + 127) / 255 << 2,
			(i64(c.b) * 63 + 127) / 255 << 2,
			255
		)
	image.Rgba8(c.r >> 2 << 2, c.g >> 2 << 2, c.b >> 2 << 2, 255)

# the view's last two columns left out of both sides: a lemming crossing it is drawn differently by
# the DOS game (a cosmetic difference, no state)
fn blankLastColumn(mut img image.Image):
	for y in 0..img.height:
		img[img.width - 1, y] = image.Rgba8(255, 0, 255, 255)
		img[img.width - 2, y] = image.Rgba8(255, 0, 255, 255)

# the level area of a DOS picture (640 x 400, each pixel doubled), the cursor's box blanked
fn dosLevel(path str, cursor Span):
	shot = image.loadPng(path)
	out = image.Image(320, game.worldHeight, fill = image.Rgba8(0, 0, 0, 255))
	for y in 0..game.worldHeight:
		for x in 0..320:
			out[x, y] = vga(shot[x * 2, y * 2], true)
	out.blank(cursor)
	out.blankLastColumn()
	out

fn zapLevel(g game.Game, main lemmings.MainData, cursor Span):
	out = g.drawView(main, g.level.screenStart, 320)
	for y in 0..out.height:
		for x in 0..out.width:
			out[x, y] = out[x, y].vga(false)
	out.blank(cursor)
	out.blankLastColumn()
	out

# where the DOS cursor went during an iteration, in the game's cursor points
type Span:
	x0 i64
	y0 i64
	x1 i64
	y1 i64

offscreen = Span(x0 = -100, y0 = -100, x1 = -100, y1 = -100)   # no cursor over the level

# the cursor's picture (14 pixels square, its point 8 right of and below the screen's, so it
# covers the point less 15 to the point less 2, one more each side for the picture's edge) left out of both sides wherever it went
fn blank(mut img image.Image, s Span):
	for y in s.y0 - 17..s.y1 + 6:
		for x in s.x0 - 17..s.x1 + 6:
			if x >= 0 and y >= 0 and x < img.width and y < img.height:
				img[x, y] = image.Rgba8(255, 0, 255, 255)

# the cursor's span of each DOS iteration the oracle logged
fn cursorsOf(out str):
	cursors {i64: Span} = {}
	text = fs.readFile("{out}/log.txt") ?? return cursors
	for line in text.lines():
		w = line.words()
		if w.len == 9 and w[0] == "iteration":
			n = w[5..].map(i64.parse(it) ?? 0)
			cursors[i64.parse(w[1]) ?? 0] = Span(x0 = n[0], y0 = n[1], x1 = n[2], y1 = n[3])
	cursors

fn dosShot(out str, i i64):
	"{out}/dos-{i:05}.png"

# the Zap pictures of the first `n` iterations with no orders
fn plainPictures(dir str, main lemmings.MainData, n i64):
	g = game.levelGame(dir, rating, number, main)
	pictures = []
	loop n:
		g.step()
		pictures.push(g.zapLevel(main, offscreen))
	pictures

# the offset from a DOS iteration to this build's: the one that makes the most pictures the same
fn alignment(plain str, pictures image.Image[]):
	best = 0
	bestSame = -1
	dos = (20..100).map(dosLevel(dosShot(plain, it), offscreen))
	for k in -8..=8:
		same = 0
		for i, picture in dos:
			z = i + 20 + k - 1
			if z < 0 or z >= pictures.len: continue
			if picture.compare(pictures[z]).pixels == 0:
				same += 1
		if same > 0:
			print("  offset {k}: {same} the same")
		if same > bestSame:
			best = k
			bestSame = same
	print("aligned: DOS iteration d is this build's d + {best} ({bestSame} of 80 the same)")
	best

# a panel button's middle as the DOS cursor points at it
fn buttonClick(button i64, iteration i64, held i64):
	tools.Click(iteration, x = button * 16 + 16, y = 196, held)

# the oracle's clicks for the route, played here to find where its lemmings are: a skill's button
# then the lemming the order aims at, the rate buttons held, the nuke's button twice
fn clicksOf(dir str, main lemmings.MainData, routeText str, simText str, k i64):
	g = game.levelGame(dir, rating, number, main)
	r = game.parseRoute(routeText)
	played = game.parseRoute(simText)
	last = r.orders.map(.last).max() ?? 0
	clicks = []
	while g.iteration < last:
		g.step()
		for o in r.orders:
			if o.iteration != g.iteration: continue
			d = o.iteration - k
			match o.kind:
				Give(skill):
					target = g.routeTarget() ?? continue
					x, y = g.aimAt(g.lemmings[target])
					clicks.push(buttonClick(2 + skill.skillIndex(), d - 3, 1))
					clicks.push(
						tools.Click(
							iteration = d,
							x = x - g.level.screenStart + 8,
							y = y + 8,
							held = 1
						)
					)
				Faster: clicks.push(buttonClick(1, d, o.last - o.iteration + 1))
				Slower: clicks.push(buttonClick(0, d, o.last - o.iteration + 1))
				Nuke:
					clicks.push(buttonClick(11, d, 1))
					clicks.push(buttonClick(11, d + 2, 1))
				Pause(steps): fail("the oracle cannot pause yet: its clicks go by iterations")
		g.runRoute(played)
	clicks

fn runOracle(dir str, out str, clicks tools.Click[], n i64):
	over = "level over" in (fs.readFile("{out}/log.txt") ?? "")
	if (over or fs.exists(dosShot(out, n - 1))) and not args.hasFlag("--fresh"): return
	print("the DOS game plays {n} iterations into {out}")
	tools.OracleRun(
		install = dir.copy(),
		out = out.copy(),
		keys = tools.levelKeys(code),
		levelFrame = tools.levelFrame(code),
		clicks = clicks.copy(),
		iterations = n,
		# --shots "f1 f2 ...": the screens at those emulator frames kept (the menus, the result)
		shots = (args.option("--shots") ?? "").words().map(i64.parse(it) ?? 0),
		# --mem "n ...": the DOS memory at those iterations kept (mem-N.bin)
		dumps = (args.option("--mem") ?? "").words().map(i64.parse(it) ?? 0),
		lastFrame = i64.parse(args.option("--last-frame") ?? "") ?? 1_000_000_000
	).playDos()

# --sim-route "...": the orders this build gives, when the DOS click landed in another iteration
# than the route's (it lands in the one asked or the next, by where the emulator's frames fall);
# the clicks' aim follows the lemmings of this route, so the two are one recipe
simRoute = args.option("--sim-route") ?? route
plain = "{base}/plain"
runOracle(dir, plain, [], iterations if route.isEmpty else 100)
k = i64.parse(args.option("--offset") ?? "") ?? alignment(plain, plainPictures(dir, main, 100))
# the oracle's run is kept by its clicks: two sim routes that aim the same share it
clicks tools.Click[] = clicksOf(dir, main, route, simRoute, k) if not route.isEmpty else []
clickKey = clicks.map("{.iteration} {.x} {.y} {.held}").join(",")
out = plain if route.isEmpty else "{base}/route-{clickKey.hash() & 0xFFFF_FFFF:x}"
if not route.isEmpty:
	_ = fs.appendFile("{base}/routes.txt", "{out}: {route}\n")
	runOracle(dir, out, clicks, iterations)
cursors = cursorsOf(out)

g = game.levelGame(dir, rating, number, main)
r = game.parseRoute(simRoute)
matched = 0
differing = 0
for d in (1 - k).max(1)..=iterations:
	if not fs.exists(dosShot(out, d)): break
	while g.iteration < d + k:
		g.step()
		for line in g.runRoute(r):
			print(line)
	cursor = cursors[d] if d in cursors else offscreen
	dos = dosLevel(dosShot(out, d), cursor)
	zap = g.zapLevel(main, cursor)
	# --dump: this build's pictures kept beside the DOS ones (zap-NNNNN.png, by the DOS number)
	if args.hasFlag("--dump"):
		_ = zap.savePng("{out}/zap-{d:05}.png")
	diff = dos.compare(zap)
	if diff.pixels > 0:
		if differing == 0:
			print("iteration {g.iteration} (DOS {d}): {diff.pixels} pixels differ after {matched} the same")
			_ = dos.savePng("{base}/first-dos.png")
			_ = zap.savePng("{base}/first-zap.png")
			_ = dos.diff(zap).savePng("{base}/first-diff.png")
		differing += 1
		# --go-on: every differing iteration counted, not only the first
		if not args.hasFlag("--go-on"): break
		continue
	matched += 1
print("{matched} iterations the same, {differing} differ")

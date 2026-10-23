# Lists what the DOS files hold and writes pictures of them to check the readers by eye:
#   zap run projects/lemmings/inspect.zap [--install dir] [--out dir]
# writes the lemming sheets, the panel, each set's pieces and objects, and a level's terrain, and
# adlib.dat unpacked.

import dos.lemmings
import fs
import image

dir = args.option("--install") ?? lemmings.defaultInstall
out = args.option("--out") ?? "projects/lemmings/assets/inspect"

main = lemmings.loadMainData(dir)
# the AdLib driver with its music and effects, unpacked for a disassembler
adlib = lemmings.sectionsOf(
	fs.readBytes("{dir}/adlib.dat") ?? fail("cannot read adlib.dat: {error}")
)
_ = fs.writeBytes("{out}/adlib.bin", adlib[0].bytes)
print("adlib.dat: {adlib.len} section, {adlib[0].bytes.len} bytes")
for a in main.animations:
	_ = a.sheet.savePng("{out}/lem-{a.name.replace(" ", "-")}.png")
_ = main.panel.savePng("{out}/panel.png")
print("{main.animations.len} animations, panel {main.panel.width}x{main.panel.height}, {main.font.len} glyphs")

for set in 0..5:
	g = lemmings.loadGraphicsSet(dir, set, 0)
	print("set {set}: {g.pieces.len} pieces, {g.objects.len} objects")
	for i, o in g.objects:
		_ = o.sheet.savePng("{out}/set{set}-object{i}.png")
		print("  object {i}: {o.frames} frames from {o.startFrame}, preview {o.previewFrame}, triggered {o.triggered}, effect {o.effect}, sound {o.sound}, {o.width}x{o.height}")
	for i, p in g.pieces:
		_ = p.picture.savePng("{out}/set{set}-piece{i}.png")

for rating in 0..4:
	for n in 0..30:
		l = lemmings.loadLevel(dir, rating, n)
		print("{lemmings.ratings[rating]} {n + 1}: {l.name}  lemmings {l.lemmings} save {l.toRescue} rate {l.releaseRate} time {l.minutes} set {l.graphicsSet} special {l.special} pieces {l.pieces.len} objects {l.objects.len} steel {l.steel.len}")

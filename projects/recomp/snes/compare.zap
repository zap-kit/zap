# The Zap build's frames against the original's: the lines "frame screenHash wramHash" Mesen 2
# wrote (tools/oracle.lua) and those of `main.zap --hashes`, compared frame by frame. Prints the
# first frame whose work RAM differs, the first whose picture differs, and how many match. Run
# from the repository root:
#
#   zap run projects/recomp/snes/compare.zap oracle.txt zap.txt
#
# Only the frames both files have are compared (the oracle may hash every n-th, SNESRECOMP_EVERY).

import fs

type FrameHashes:
	screen str
	wram str

fn readHashes(path str):
	text = fs.readFile(path) ?? fail("cannot read {path}: {error}")
	out {i64: FrameHashes} = {}
	for row in text.lines():
		words = row.words()
		if words.len < 3: continue
		frame = i64.parse(words[0]) ?? continue
		out[frame] = FrameHashes(screen = words[1].copy(), wram = words[2].copy())
	out

fn firstText(frame i64?):
	if frame is f: return "{f}"
	"none"

paths = args.positional()
if paths.len < 2: fail("usage: zap run projects/recomp/snes/compare.zap oracle.txt zap.txt")
oracle = readHashes(paths[0])
zap = readHashes(paths[1])
mut firstWram i64? = none
mut firstScreen i64? = none
mut both = 0
mut wramSame = 0
mut screenSame = 0
frames = oracle.keys().sorted().filter(it in zap)
for frame in frames:
	o = oracle[frame]
	z = zap[frame]
	if o.wram == z.wram:
		wramSame += 1
	elif firstWram == none:
		firstWram = frame
	if o.screen == z.screen:
		screenSame += 1
	elif firstScreen == none:
		firstScreen = frame
	if o.wram == z.wram and o.screen == z.screen: both += 1
print("{frames.len} frames compared: {both} match whole, {wramSame} in work RAM, {screenSame} in the picture")
print("first work RAM difference: {firstText(firstWram)}; first picture difference: {firstText(firstScreen)}")

# The player's side: each frame shown in a window (240 x 160 scaled up), the keys read, the frames
# paced to the GBA's 59.73 a second. From the command line: `--frames N` ends after N frames,
# printing the last frame's hash with `--hash` and saving it with `--shot x.png`; `--headless` opens
# no window (nor sound); `--mute` plays no sound; `--press` holds keys from a script (presses.zap);
# `--uncapped` runs as fast as it goes; `--wav x.wav` keeps the sound; `--measure` prints the frames a second and the memory; `--dump x.bin` writes the memories (EWRAM, IWRAM, I/O,
# palette, VRAM, OAM, one after the other) at the end.

import cpu
import digest
import fs
import engine
import image

# the window, when there is one
mut displays engine.PixelWindow[] = []
mut frameLimit = -1
mut started f64 = 0.0
mut paced = true
pub mut savePath = ""

framesPerSecond = 59.7275
scale = 3

pub fn openScreen():
	frameLimit = i64.parse(args.option("--frames") ?? "") ?? -1
	paced = not args.hasFlag("--uncapped") and frameLimit < 0
	started = clockSeconds()
	if args.hasFlag("--headless"): return
	if not args.hasFlag("--mute"): openSound()
	displays.push(
		engine.openPixelWindow(
			"Pokemon FireRed (Zap)",
			screenWidth,
			screenHeight,
			scale,
			screenImage()
		)
	)

# the picture's BGR555 pixels as an image
fn screenImage():
	engine.bgr555Image(screen, screenWidth, screenHeight)

# the hash of the frame on the screen: the SHA-1 of its pixels, two bytes each
pub fn frameHash() str:
	digest.sha1(screen.rawBytes())

# A frame is done (the vertical blank began): shown, the keys read, the pace kept.
pub fn frameDone():
	if frameLimit >= 0 and frameCount >= frameLimit: finish()
	if not displays.isEmpty: displays[0].present()
	pushSound()
	if isScripted(): keysUp = scriptedKeys(frameCount)
	if flashChanged and frameCount % 60 == 0: saveFlash()
	if paced:
		due = started + frameCount / framesPerSecond
		wait = due - clockSeconds()
		if wait > 0.0: sleepMs(i64(wait * 1000.0))

fn present(mut d engine.PixelWindow):
	if not d.show(screenImage()): finish()
	readKeys()

fn readKeys():
	held = [
		engine.isKeyDown(.Char('Z')),
		engine.isKeyDown(.Char('X')),
		engine.isKeyDown(.Backspace),
		engine.isKeyDown(.Enter),
		engine.isKeyDown(.Right),
		engine.isKeyDown(.Left),
		engine.isKeyDown(.Up),
		engine.isKeyDown(.Down),
		engine.isKeyDown(.Char('S')),
		engine.isKeyDown(.Char('A'))
	]
	up = 0x3FF
	for k, down in held:
		if down: up &= ~(u32(1) << u32(k))
	keysUp = up

# the end of a run: the last frame's hash and picture when asked, the save written
fn finish():
	if args.hasFlag("--hash"): print("frame {frameCount}: {frameHash()}")
	if args.hasFlag("--measure"):
		took = clockSeconds() - started
		print("{frameCount} frames in {took:.2} s: {(frameCount / took):.0} frames a second, {peakMemory() / 1_048_576} MB at most")
	if args.hasFlag("--calls"):
		print("last functions entered: {recentText()}")
		print("IE {ioHalf(regIe):04X} IF {ioHalf(regIf):04X} IME {ioHalf(regIme)} DISPSTAT {dispstat():04X} control {cpu.control:02X} interrupts {interruptCount} line {line}")
	if args.option("--dump") is dumpPath:
		all = ewram.copy()
		all.extend(iwram)
		all.extend(io)
		all.extend(palette)
		all.extend(vram)
		all.extend(oam)
		fs.writeBytes(dumpPath, all) ?? eprint("cannot write {dumpPath}: {error}")
	if args.option("--shot") is path:
		screenImage().savePng(path) ??
			eprint("cannot write {path}: {error}")
	if flashChanged: saveFlash()
	saveSound()
	exit(0)

fn saveFlash():
	flashChanged = false
	if savePath.isEmpty: return
	fs.writeBytes(savePath, flash) ?? eprint("cannot write the save {savePath}: {error}")

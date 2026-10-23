# The picture as Mesen 2 keeps it, which its hashes read: two buffers of 512x478 BGR555 colours
# taken in turn at the end of each frame's line 0. A frame is low resolution, its lines 1-224 the
# rows 7-230 of a 256-wide buffer, until a line is drawn in high resolution (modes 5 and 6 or
# pseudo-hires, 2133 bit 3): then it is 512 wide, each line two rows from 14 (its sub and main
# pixels side by side), and what it drew before is widened in place. When the frame is shown the
# 7 rows above it and the 8 below (14 and 16 wide) are cleared; the rest of a buffer keeps what it
# held two frames before where this frame draws nothing, as Mesen's does.

pub outputWidth = 512
pub outputHeight = 478
lowRows = 239
blankAbove = 7
blankBelow = 8

outputSize = 512 * 478
mut outputs u16[] = zeros(2 * outputSize)   # the two buffers one after the other
mut shown = 0   # the buffer's start in outputs
pub mut highRes = false

fn outputPowerOn():
	outputs = zeros(2 * outputSize)
	shown = 0
	highRes = false

# whether the PPU draws this line in high resolution: modes 5 and 6, or pseudo-hires
fn isDoubleWidth():
	mode = ppuRegs[5] & 7
	mode == 5 or mode == 6 or ppuRegs[0x33] & 8 != 0

# line 0 ended: the other buffer taken, its resolution as the registers say now
fn startOutput():
	shown = outputSize - shown
	highRes = isDoubleWidth()

# the line's pixel x: its main screen's colour and, in high resolution, its sub screen's
fn outputPixel(x i64, main i64, sub i64):
	if redrawing: return
	row = line + blankAbove - 1
	if not highRes:
		outputs[shown + (row << 8) + x] = u16(main)
		return
	at = (row << 10) + (x << 1)
	even = u16(sub if isDoubleWidth() else main)
	outputs[shown + at] = even
	outputs[shown + at + 1] = u16(main)
	outputs[shown + at + 512] = even
	outputs[shown + at + 513] = u16(main)

# A write that turns high resolution on mid-frame: the rows drawn so far widened, the line's own
# up to `drawn`.
fn widenOutput(drawn i64):
	if highRes or not isDoubleWidth() or line == 0 or line >= vblankLine: return
	highRes = true
	row = line + blankAbove - 1
	if drawn > 0: widenRow(row, drawn)
	for r in row - 1..-1 step -1:
		widenRow(r, 256)

# a low-resolution row's first `count` pixels written twice each into its two wide rows (the
# wide row past them copied whole, as Mesen does)
fn widenRow(row i64, count i64):
	for x in 0..count:
		c = outputs[shown + (row << 8) + x]
		outputs[shown + (row << 10) + (x << 1)] = c
		outputs[shown + (row << 10) + (x << 1) + 1] = c
	for x in 0..512:
		outputs[shown + (row << 10) + 512 + x] = outputs[shown + (row << 10) + x]

# the frame shown: the rows above and below the picture cleared
fn clearBorders():
	width = 512 if highRes else 256
	scale = 2 if highRes else 1
	for i in 0..blankAbove * scale * width:
		outputs[shown + i] = 0
	end = lowRows * scale * width
	for i in end - blankBelow * scale * width..end:
		outputs[shown + i] = 0

# The frame's colours in the order Mesen 2 hashes them: 256x239 or 512x478 from the buffer's start.
fn outputColors():
	count = outputWidth * outputHeight if highRes else 256 * lowRows
	outputs[shown..shown + count].copy()

# the main screen's colour (BGR555) at the picture's x, y (0-255, 0-223)
fn nativeColorAt(x i64, y i64) i64:
	row = y + blankAbove
	at = (row << 8) + x if not highRes else (row << 10) + (x << 1) + 1
	outputs[shown + at]

# the main screen's colour at the picture's x, y (0-255, 0-223)
pub fn pixelAt(x i64, y i64) u32:
	rgb(nativeColorAt(x, y))

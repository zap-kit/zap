# The console a program runs in, taken over the way a terminal program needs it: keys come in as
# the bytes a terminal sends (VT sequences, UTF-8) with no line editing or echo, and what is
# written out is read as VT sequences.

extern fn SetConsoleMode(h i64, mode i64) bool
extern fn GetConsoleCP() i32
extern fn GetConsoleOutputCP() i32
extern fn SetConsoleCP(page i64) bool
extern fn SetConsoleOutputCP(page i64) bool
extern fn GetConsoleScreenBufferInfo(h i64, mut info ScreenBufferInfo) bool

# CONSOLE_SCREEN_BUFFER_INFO
extern type ScreenBufferInfo:
	sizeX i16
	sizeY i16
	cursorX i16
	cursorY i16
	attributes u16
	left i16
	top i16
	right i16
	bottom i16
	maxX i16
	maxY i16

# The console's modes and code pages before raw() changed them, put back by restore().
pub type ConsoleState:
	inMode i64
	outMode i64
	inPage i64
	outPage i64

	# Puts the console back as it was.
	fn restore():
		SetConsoleMode(rt.GetStdHandle(-10), inMode)
		SetConsoleMode(rt.GetStdHandle(-11), outMode)
		SetConsoleCP(inPage)
		SetConsoleOutputCP(outPage)

# Takes the console raw: keys as VT bytes with no echo, no line editing and no Ctrl+C of its own
# (it arrives as byte 3), output read as VT sequences, both in UTF-8. What it was is given back.
pub fn rawConsole() ConsoleState:
	inHandle = rt.GetStdHandle(-10)
	outHandle = rt.GetStdHandle(-11)
	rt.GetConsoleMode(inHandle, out inMode)
	rt.GetConsoleMode(outHandle, out outMode)
	was = ConsoleState(
		inMode,
		outMode,
		inPage = GetConsoleCP(),
		outPage = GetConsoleOutputCP()
	)
	SetConsoleMode(inHandle, 0x200)   # ENABLE_VIRTUAL_TERMINAL_INPUT alone
	# ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING | DISABLE_NEWLINE_AUTO_RETURN
	SetConsoleMode(outHandle, 0x1 | 0x4 | 0x8)
	SetConsoleCP(65_001)
	SetConsoleOutputCP(65_001)
	was

# a console's visible window, in character cells
pub type ConsoleSize:
	cols i64
	rows i64

# The visible window of the console; 80 by 24 when there is no console.
pub fn consoleSize() ConsoleSize:
	info = ScreenBufferInfo(
		sizeX = 0,
		sizeY = 0,
		cursorX = 0,
		cursorY = 0,
		attributes = 0,
		left = 0,
		top = 0,
		right = 0,
		bottom = 0,
		maxX = 0,
		maxY = 0
	)
	if not GetConsoleScreenBufferInfo(rt.GetStdHandle(-11), info):
		return ConsoleSize(cols = 80, rows = 24)
	ConsoleSize(
		cols = i64(info.right) - i64(info.left) + 1,
		rows = i64(info.bottom) - i64(info.top) + 1
	)

# The bytes of the next keys typed (or of the input a pipe gives), waiting for some; empty at the
# end of the input.
pub fn readInput(max i64 = 4096) u8[]:
	buf u8[] = zeros(max)
	got u32 = 0
	if not rt.ReadFile(rt.GetStdHandle(-10), buf, max, out got, 0): got = 0
	buf.truncate(i64(got))
	buf

# The bytes written to the console at once, after what print has buffered: a terminal program's
# frames, which must not wait in a buffer.
pub fn writeNow(bytes u8[]):
	rt.flushStdout()
	rt.writeRaw(rt.stdoutHandle, bytes)

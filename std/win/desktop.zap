# Programs run on a desktop of their own that no one sees: their windows open there, so a tool
# that drives a windowed program (an emulator scripted from inside) never shows a window, takes
# the focus or meets the user's mouse and keys.

extern "user32.dll" fn CreateDesktopW(
	name u16[],
	device i64,
	mode i64,
	flags i64,
	access i64,
	attrs i64
) i64
extern "user32.dll" fn CloseDesktop(desktop i64) bool

# Runs the command line `cmd` on the hidden desktop `desktop` (made when missing) and waits for
# it, `ms` milliseconds at most (then it is stopped, its code 1): its exit code, or the error the
# system gave when it cannot start.
pub fn runHidden(cmd str, desktop str, ms i64) i64 ? SystemError:
	name = wide(desktop)
	noAttributes u8[] = []
	# GENERIC_ALL: the program may make and draw windows there
	handle = CreateDesktopW(name, 0, 0, 0, 0x1000_0000, 0)
	if handle == 0: return lastError()
	startup = StartupInfoEx(
		reserved = none,
		desktop = name,
		title = none,
		x = 0,
		y = 0,
		xSize = 0,
		ySize = 0,
		xChars = 0,
		yChars = 0,
		fill = 0,
		flags = 0,
		show = 0,
		reserved2 = 0,
		reserved3 = none,
		stdInput = 0,
		stdOutput = 0,
		stdError = 0,
		attributeList = noAttributes
	)
	info = ProcessInformation(process = 0, thread = 0, processId = 0, threadId = 0)
	if not CreateProcessW(0, wide(cmd), 0, 0, false, 0, 0, wide(currentDir()), startup, info):
		why = lastError()
		CloseDesktop(handle)
		return why
	if WaitForSingleObject(info.process, ms) != 0:
		TerminateProcess(info.process, 1)
		WaitForSingleObject(info.process, 5000)
	rt.GetExitCodeProcess(info.process, out code)
	CloseHandle(info.thread)
	CloseHandle(info.process)
	CloseDesktop(handle)
	i64(code)

# std/win: a program on a pseudo console, its screen read as VT bytes and its keyboard written.

import win

# what the program wrote until `until` appeared or it ended, as text
fn screenUntil(mut pty win.Pty, until str) str:
	seen = []
	loop 5000:
		seen.extend(pty.read())
		if str(seen).indexOf(until) != none or pty.hasEnded(): break
		sleepMs(1)
	seen.extend(pty.read())
	str(move seen)

test "a program's output comes out of its pseudo console":
	pty = win.startPty("cmd.exe /c echo zaplink-ok", currentDir(), 80, 25) ?? fail("no pty")
	print(pty.screenUntil("zaplink-ok").indexOf("zaplink-ok") != none)
	loop 5000:
		if pty.hasEnded(): break
		sleepMs(1)
	print(pty.code)
	pty.close()
	prints """
		true
		0
		"""

test "keys written reach the program, a resize is taken":
	pty = win.startPty("cmd.exe /q /k", currentDir(), 100, 30) ?? fail("no pty")
	pty.resize(120, 40)
	pty.write("echo typed-%OS%\r".bytes())
	print(pty.screenUntil("typed-Windows_NT").indexOf("typed-Windows_NT") != none)
	pty.write("exit 7\r".bytes())
	loop 5000:
		if pty.hasEnded(): break
		sleepMs(1)
	print(pty.code)
	prints """
		true
		7
		"""

test "a command that does not exist is the system's error":
	match win.startPty("no-such-program-zaplink.exe", currentDir(), 80, 25):
		pty: print("started")
		error: print(error.code == 2)
	prints "true"

test "text as UTF-16":
	expect win.wide("aé") == [97, 233, 0]

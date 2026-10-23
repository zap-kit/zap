# What the client draws itself: the menu of sessions and the questions of a new session. A
# session's own screen is the daemon's bytes, written as they come.

import link
import win

esc = str.fromCode(27)

# the terminal as a program left it: main screen, cursor shown, no mouse or paste modes, plain text
pub fn resetTerminal():
	win.writeNow(
		"{esc}[?1049l{esc}[?25h{esc}[?1000l{esc}[?1002l{esc}[?1003l{esc}[?1006l{esc}[?2004l{esc}[0m".bytes()
	)

pub fn clearScreen():
	win.writeNow("{esc}[2J{esc}[3J{esc}[H".bytes())

# The sessions and what can be typed, the line typed so far last.
pub fn drawMenu(sessions link.SessionInfo[], note str, line str):
	out = "{esc}[2J{esc}[H{esc}[1mzaplink{esc}[0m  sessions on this PC\r\n\r\n"
	if sessions.isEmpty:
		out = "{out}  (none yet)\r\n"
	for i, s in sessions:
		attached = "  {esc}[2m{s.clients} attached{esc}[0m" if s.clients > 0 else ""
		out = "{out}  {esc}[1m{i + 1}{esc}[0m  {s.title}  {esc}[2m{s.profile}  {s.dir}{esc}[0m{attached}\r\n"
	out = "{out}\r\n  number: open   n: new   x number: close   q: quit   (Ctrl+] leaves a session)\r\n"
	if note != "":
		out = "{out}\r\n  {esc}[33m{note}{esc}[0m\r\n"
	win.writeNow("{out}\r\n> {line}".bytes())

# A question and its numbered choices, the line typed so far last.
pub fn drawQuestion(title str, choices str[], hint str, line str):
	out = "{esc}[2J{esc}[H{esc}[1m{title}{esc}[0m\r\n\r\n"
	for i, c in choices:
		out = "{out}  {esc}[1m{i + 1}{esc}[0m  {c}\r\n"
	win.writeNow("{out}\r\n  {esc}[2m{hint}{esc}[0m\r\n\r\n> {line}".bytes())

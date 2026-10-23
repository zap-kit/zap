# The client in a terminal: a menu of the daemon's sessions, the questions that open a new one
# (terminal, agent, dir), and a session attached, whose screen is the daemon's bytes and whose
# keyboard is this terminal's. Ctrl+] leaves a session for the menu; it goes on running.

import link
import net
import win

detachKey u8 = 29   # Ctrl+]

type Step:
	Menu
	Profile
	Agent
	Dir
	Inside

pub type App:
	conn net.TcpConn
	sessions link.SessionInfo[]
	profiles str[]
	agents str[]
	dirs str[]
	step Step
	typed u8[]   # the line typed so far, outside a session
	note str
	profile str
	agent str
	cols i64
	rows i64
	running bool

	# Runs until the user quits or the daemon goes.
	fn run(keys Channel<u8[]>):
		size = win.consoleSize()
		cols = size.cols
		rows = size.rows
		self.redraw()
		sizeCheck = clockMs()
		while running:
			busy = false
			if keys.tryReceive() is bytes:
				busy = true
				self.typedKeys(bytes)
			match conn.pollFrame():
				frame:
					if frame is bytes:
						busy = true
						if link.Message.fromBytes(bytes) is message: self.received(message)
				error:
					resetTerminal()
					win.writeNow(
						"\r\nzaplink: the connection to zaplinkd ended ({error})\r\n".bytes()
					)
					running = false
			if clockMs() - sizeCheck > 250:
				self.followSize()
				sizeCheck = clockMs()
			if not busy: sleepMs(4)

	fn send(message link.Message):
		_ = conn.sendFrame(message.toBytes())

	fn typedKeys(bytes u8[]):
		if step == .Inside:
			at = bytes.indexOf(detachKey) ?? return self.send(.Input(bytes.copy()))
			if at > 0: self.send(.Input(bytes[..at].copy()))
			self.send(.Detach)
			step = .Menu
			resetTerminal()
			self.redraw()
			return
		for b in bytes:
			if b == 13:
				line = str(typed.copy()).trimmed().copy()
				typed.clear()
				self.answer(line)
			elif b == 127 or b == 8:
				while not typed.isEmpty and (typed.pop() ?? 0) & 0xC0 == 0x80:
					pass
			elif b == 3:
				running = false
			elif b == 27:
				step = .Menu
				typed.clear()
			elif b >= 32:
				typed.push(b)
		if running and step != .Inside: self.redraw()

	fn answer(line str):
		note = ""
		match step:
			Menu: self.menuAnswer(line)
			Profile:
				profile = profiles[self.chosen(line, len, 1) - 1].copy()
				step = .Agent
			Agent:
				n = self.chosen(line, agents.len + 1, 2.min(agents.len + 1))
				agent = "" if n == 1 else agents[n - 2].copy()
				step = .Dir
			Dir:
				dir = dirs[self.chosen(line, len, 1) - 1].copy() if line == "" or
					i64.parse(line) != none
					else line
				self.send(.Create(profile.copy(), agent.copy(), dir, cols, rows))
				step = .Menu
			_: pass

	# the number typed, kept within 1..count; the default for an empty line or a word
	fn chosen(line str, count i64, default i64):
		n = i64.parse(line) ?? default
		n.clamp(1, count.max(1))

	fn menuAnswer(line str):
		if line == "q":
			running = false
		elif line == "n":
			step = .Profile
		elif line.startsWith("x ") and i64.parse(line[2..]) is n and n >= 1 and n <= sessions.len:
			self.send(.CloseSession(sessions[n - 1].id))
		elif i64.parse(line) is n and n >= 1 and n <= sessions.len:
			self.send(.Attach(sessions[n - 1].id, cols, rows))
		elif line != "":
			note = "type a session's number, n, x and a number, or q"

	fn received(move message link.Message):
		match message:
			Sessions(list):
				sessions = list
				if step != .Inside: self.redraw()
			Attached(id):
				step = .Inside
				clearScreen()
			Output(bytes):
				if step == .Inside: win.writeNow(bytes)
			Ended(id, code):
				if step == .Inside:
					resetTerminal()
					step = .Menu
					note = "the session ended (exit code {code})"
					self.redraw()
			Refused(reason):
				note = reason
				if step != .Inside: self.redraw()
			Welcome(newProfiles, newAgents, newDirs):
				profiles = newProfiles
				agents = newAgents
				dirs = newDirs
			_: pass

	# a new size of this terminal goes to the session, or redraws the menu
	fn followSize():
		size = win.consoleSize()
		if size.cols == cols and size.rows == rows: return
		cols = size.cols
		rows = size.rows
		if step == .Inside:
			self.send(.Resize(cols, rows))
		else:
			self.redraw()

	fn redraw():
		line = str(typed.copy())
		match step:
			Menu: drawMenu(sessions, note, line)
			Profile: drawQuestion(
				"New session: the terminal",
				profiles,
				"Enter: 1   Esc: back",
				line
			)
			Agent:
				choices = ["none, the terminal alone"]
				for a in agents:
					choices.push(a.copy())
				drawQuestion(
					"New session in {profile}: the agent",
					choices,
					"Enter: {2.min(choices.len)}   Esc: back",
					line
				)
			Dir: drawQuestion(
				"New session: the dir",
				dirs,
				"Enter: 1, or type a path   Esc: back",
				line
			)
			_: pass

# Connects to the daemon and gives it the token; why it could not.
pub fn connect(host str, port i64, token str) App ? str:
	conn = net.tcpConnect(host, port) ??
		return "cannot reach zaplinkd at {host}:{port} ({error})"
	_ = conn.sendFrame(link.Message.Hello(token.copy(), "zaplink").toBytes())
	frame = conn.receiveFrame() ?? return "zaplinkd closed the connection"
	message = link.Message.fromBytes(frame) ?? return "zaplinkd sent what this client cannot read"
	match message:
		Welcome(profiles, agents, dirs):
			App(
				conn,
				sessions = [],
				profiles,
				agents,
				dirs,
				step = .Menu,
				typed = [],
				note = "",
				profile = "",
				agent = "",
				cols = 80,
				rows = 24,
				running = true
			)
		Refused(reason): reason
		_: "zaplinkd answered out of turn"

# The keys typed, as they come, to the channel; stops at the end of the input.
pub fn readKeys(keys Channel<u8[]>):
	out = keys
	loop:
		bytes = win.readInput()
		if bytes.isEmpty: break
		if not out.send(bytes): break
	out.close()

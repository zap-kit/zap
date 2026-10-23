# The daemon's one loop: it accepts clients, reads their messages, moves each session's output to
# the clients attached to it and their keys to the session, and tells every client when the list
# of sessions changes. Nothing waits on one source: the listener, the connections and the pseudo
# consoles are polled in turn.

import fs
import link
import net
import win

type Session:
	info link.SessionInfo
	pty win.Pty
	cols i64
	rows i64

type Client:
	id i64
	conn net.TcpConn
	known bool   # gave the token
	attached i64   # the session's id, -1 for none
	cols i64
	rows i64

pub type Hub:
	config Config
	profiles Profile[]
	token str
	sessions Session[]
	clients Client[]
	nextId i64

	# The listener on the config's address; why it cannot listen.
	fn listen():
		net.tcpListen(config.port, config.host)

	# Serves the listener's clients while running holds 1.
	fn serve(listener net.TcpListener, running Atomic):
		while running.load() == 1:
			busy = false
			if listener.poll() is conn:
				clients.push(
					Client(
						id = self.newId(),
						conn,
						known = false,
						attached = -1,
						cols = 80,
						rows = 24
					)
				)
				busy = true
			busy = self.readClients() or busy
			busy = self.pumpSessions() or busy
			if not busy: sleepMs(4)

	fn newId():
		nextId += 1
		nextId - 1

	# every message the clients have sent; whether there was any. A client whose connection failed
	# is dropped.
	mut fn readClients():
		busy = false
		k = 0
		while k < clients.len:
			match clients[k].conn.pollFrame():
				frame:
					if frame is bytes:
						busy = true
						if link.Message.fromBytes(bytes) is message:
							self.handle(k, message)
					k += 1
				error:
					self.dropClient(k)
		busy

	fn dropClient(k i64):
		was = clients[k].attached
		clients.remove(k)
		if was != -1: self.broadcastSessions()

	# each session's new output to its clients, and the ones that ended; whether there was output
	fn pumpSessions():
		busy = false
		s = 0
		while s < sessions.len:
			out = sessions[s].pty.read()
			if not out.isEmpty:
				busy = true
				self.sendAttached(sessions[s].info.id, .Output(out))
			if sessions[s].pty.hasEnded():
				id = sessions[s].info.id
				self.sendAttached(id, .Ended(id, sessions[s].pty.code))
				self.detachAll(id)
				sessions.remove(s)
				self.broadcastSessions()
			else:
				s += 1
		busy

	fn handle(k i64, message link.Message):
		if not clients[k].known:
			if message is Hello(given, client) and given == token:
				clients[k].known = true
				self.send(
					k,
					.Welcome(
						profiles.map(.name.copy()),
						config.agents.map(.name.copy()),
						config.dirs.copy()
					)
				)
				self.send(k, .Sessions(self.sessionList()))
			else:
				self.send(k, .Refused("wrong token"))
			return
		match message:
			Create(profile, agent, dir, cols, rows): self.create(k, profile, agent, dir, cols, rows)
			Attach(id, cols, rows): self.attach(k, id, cols, rows)
			Detach:
				clients[k].attached = -1
				self.broadcastSessions()
			Input(bytes): self.input(k, bytes)
			Resize(cols, rows):
				clients[k].cols = cols
				clients[k].rows = rows
				self.fitSession(clients[k].attached, cols, rows)
			CloseSession(id):
				if self.sessionAt(id) is s:
					sessions[s].pty.close()
			_: pass

	fn create(k i64, profileName str, agentName str, dir str, cols i64, rows i64):
		profile = profiles.find(.name == profileName) ?? profiles[0]
		where = dir if dir != "" else (profile.dir if profile.dir != "" else currentDir())
		if not fs.exists(where):
			self.send(k, .Refused("no such dir: {where}"))
			return
		pty = win.startPty(profile.command, where, cols, rows) ??
			return self.send(k, .Refused("cannot start {profile.command}: error {error.code}"))
		agentLabel = ""
		if config.agents.find(.name == agentName) is agent:
			pty.write("{agent.command}\r".bytes())
			agentLabel = agent.name.copy()
		id = self.newId()
		title = "{agentLabel if agentLabel != "" else profile.name} - {fs.fileName(fs.normalize(where))}"
		info = link.SessionInfo(
			id,
			title,
			profile = profile.name.copy(),
			agent = agentLabel,
			dir = where.copy(),
			clients = 0
		)
		sessions.push(Session(info, pty, cols, rows))
		config.useDir(where)
		self.attach(k, id, cols, rows)

	# the client attached to the session, whose screen is drawn again for it
	fn attach(k i64, id i64, cols i64, rows i64):
		s = self.sessionAt(id) ?? return self.send(k, .Refused("no session {id}"))
		clients[k].attached = id
		clients[k].cols = cols
		clients[k].rows = rows
		self.send(k, .Attached(id))
		# a resize makes the pseudo console send its whole screen again; one row less first, so it
		# does so even when the size stays
		sessions[s].pty.resize(cols, (rows - 1).max(1))
		sessions[s].cols = -1
		self.fitSession(id, cols, rows)
		self.broadcastSessions()

	mut fn input(k i64, bytes u8[]):
		s = self.sessionAt(clients[k].attached) ?? return
		sessions[s].pty.write(bytes)
		# the client typing last sets the size
		self.fitSession(sessions[s].info.id, clients[k].cols, clients[k].rows)

	fn fitSession(id i64, cols i64, rows i64):
		s = self.sessionAt(id) ?? return
		if sessions[s].cols == cols and sessions[s].rows == rows: return
		sessions[s].pty.resize(cols, rows)
		sessions[s].cols = cols
		sessions[s].rows = rows

	fn sessionAt(id i64) i64?:
		for s, session in sessions:
			if session.info.id == id: return s
		none

	fn detachAll(id i64):
		for mut client in clients:
			if client.attached == id: client.attached = -1

	fn sessionList():
		sessions.map(s:
			info = s.info.copy()
			info.clients = clients.count(.attached == s.info.id)
			info
		)

	mut fn broadcastSessions():
		list = self.sessionList()
		for k, client in clients:
			if client.known: self.send(k, .Sessions(list.copy()))

	mut fn sendAttached(id i64, message link.Message):
		bytes = message.toBytes()
		for client in clients:
			if client.attached == id: _ = client.conn.sendFrame(bytes)

	mut fn send(k i64, message link.Message):
		_ = clients[k].conn.sendFrame(message.toBytes())

pub fn startHub() Hub:
	Hub(
		config = loadConfig(),
		profiles = loadProfiles(),
		token = loadToken(),
		sessions = [],
		clients = [],
		nextId = 1
	)

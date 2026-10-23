# A small MMO server and its clients in one program: three clients connect, each sends
# thousands of typed messages (moves, chat, attacks) as binary frames, the server keeps the
# world in a map, answers with JSON snapshots, and prints a deterministic summary at the end. Every
# message, frame, name and snapshot is an allocation: the suite runs this with freed memory
# poisoned, so a dangling byte would show.

import net

clients = 3
messagesPerClient = 3000
snapshotEvery = 100

type Message:
	Hello(id i64, name str)
	Move(id i64, dx i64, dy i64)
	Say(id i64, text str)
	Attack(id i64, target i64)
	Bye(id i64)

type Player:
	name str
	x i64
	y i64
	hp i64
	inbox str[]
	kills i64

type Snapshot:
	tick i64
	players i64
	names str[]

# ---------- framing ----------
# A message travels as `m.toBytes()` inside a frame (`conn.sendFrame`), and comes back out
# with `conn.receiveFrame()` and `Message.fromBytes`: the compiler writes the encoding.

type FrameReader:
	frames i64
	bytes i64

	fn next(mut conn net.TcpConn):
		frame = try conn.read()
		frames += 1
		bytes = bytes + frame.len + 4
		decode(frame)

# A client's next frame, none once the connection closed, and the message in it, none when it
# holds none: what a client sends never stops the server.
fn read(mut conn net.TcpConn) u8[]?:
	use noStops
	conn.receiveFrame() ?? none

fn decode(frame u8[]):
	use noStops
	Message.fromBytes(frame)

# ---------- the client ----------

fn client(id i64, port i64):
	match net.tcpConnect("127.0.0.1", port):
		c:
			conn = move c
			_ = conn.sendFrame(Message.Hello(id, "player{id}").toBytes())
			for i in 0..messagesPerClient:
				kind = (i + id) % 7
				m = Message.Move(id, (i % 3) - 1, ((i / 3) % 3) - 1)
				if kind == 3:
					m = .Say(id, "msg {i} from {id}: {"x".repeat(i % 40)}")
				elif kind == 5:
					m = .Attack(id, (id % clients) + 1)
				_ = conn.sendFrame(m.toBytes())
				if (i + 1) % snapshotEvery == 0:
					# the server answers every batch with a snapshot line; read it and go on
					_ = conn.receiveLine()
			_ = conn.sendFrame(Message.Bye(id).toBytes())
			conn.close()
		error: eprint("client {id}: cannot connect")

# ---------- the server ----------

type World:
	players {i64: Player}
	log str[]
	tick i64
	frames i64
	chat i64

	# a player that changes is taken out of the map, changed and put back
	fn apply(move m Message):
		tick += 1
		match move m:
			Hello(id, name): players[id] = Player(
				name,
				x = 0,
				y = 0,
				hp = 100,
				inbox = [],
				kills = 0
			)
			Move(id, dx, dy):
				if players.remove(id) is mut p:
					moved = move p
					moved.x = (moved.x + dx + 64) % 64
					moved.y = (moved.y + dy + 64) % 64
					players[id] = moved
			Say(id, text):
				chat += 1
				for key in players.keys():
					if key != id:
						if players.remove(key) is mut p:
							heard = move p
							heard.inbox.push(text.copy())
							if heard.inbox.len > 50:
								heard.inbox = heard.inbox[25..].copy()
							players[key] = heard
			Attack(id, target):
				if players.remove(target) is mut p:
					hit = move p
					hit.hp -= 7
					if hit.hp <= 0:
						hit.hp = 100
						log.push("{hit.name} respawns")
						if players.remove(id) is mut a:
							killer = move a
							killer.kills += 1
							players[id] = killer
					players[target] = hit
			Bye(id):
				log.push("player {id} leaves")
				return false
		true

	fn snapshot():
		names = []
		for key in players.keys().sorted():
			if players.get(key) is p:
				names.push(p.name.copy())
		Snapshot(tick, players = players.len, names).toJson()

fn serve(mut world World, mut conn net.TcpConn):
	reader = FrameReader(frames = 0, bytes = 0)
	going = true
	batch = 0
	while going:
		match reader.next(conn):
			m:
				going = world.apply(m)
				batch += 1
				if batch == snapshotEvery:
					_ = conn.sendLine(world.snapshot())
					batch = 0
			none: going = false
	conn.close()
	reader

# how long the server waits for a client: one that never comes fails the test instead of hanging it
waitMs = 60_000

if args.len > 2 and args[0] == "client":
	client(i64.parse(args[1]) ?? 1, i64.parse(args[2]) ?? 0)
	return
# a free port from the system: runs side by side never share one
match net.tcpListen(0):
	listener:
		world = World(players = {}, log = [], tick = 0, frames = 0, chat = 0)
		bytes = 0
		# one client at a time, so the summary does not depend on who connected first
		for id in 1..=clients:
			child = Process.start("\"{exePath()}\" client {id} {listener.port()}")
			match listener.accept(within = waitMs):
				c:
					conn = move c
					reader = world.serve(conn)
					world.frames += reader.frames
					bytes += reader.bytes
				error: print("accept failed")
			if child.waitWithin(waitMs) == none: print("client {id} still runs")
		print("frames {world.frames}, bytes {bytes}, chat {world.chat}, ticks {world.tick}")
		for key in world.players.keys().sorted():
			if world.players.get(key) is p:
				print("{p.name}: at {p.x},{p.y} hp {p.hp} kills {p.kills} inbox {p.inbox.len}")
		print("log entries {world.log.len}, last: {world.log.last ?? "-"}")
		print(world.snapshot())
	error: print("cannot listen")

test "the server and its clients exchange framed messages and JSON snapshots":
	main()
	prints r"""
	    frames 9006, bytes 308890, chat 1287, ticks 9006
	    player1: at 63,0 hp 37 kills 0 inbox 33
	    player2: at 0,62 hp 100 kills 0 inbox 29
	    player3: at 0,63 hp 100 kills 28 inbox 0
	    log entries 31, last: player 3 leaves
	    {"tick":9006,"players":3,"names":["player1","player2","player3"]}
	    """

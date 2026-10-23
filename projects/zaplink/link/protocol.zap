# What the daemon and its clients say to each other: one Message per frame (net's sendFrame),
# written with toBytes and read with fromBytes.

import fs

pub defaultPort = 7781

# a session as the clients list it
pub type SessionInfo:
	id i64
	title str
	profile str
	agent str
	dir str
	clients i64   # how many clients are attached to it

pub type Message:
	# client to daemon
	Hello(token str, client str)
	Create(profile str, agent str, dir str, cols i64, rows i64)
	Attach(id i64, cols i64, rows i64)
	Detach
	Input(bytes u8[])
	Resize(cols i64, rows i64)
	CloseSession(id i64)
	# daemon to client
	Welcome(profiles str[], agents str[], dirs str[])
	Sessions(list SessionInfo[])
	Attached(id i64)
	Output(bytes u8[])
	Ended(id i64, code i64)
	Refused(reason str)

# where zaplink keeps its token, its config and its recent dirs
pub fn stateDir() str:
	fs.join(env.get("LOCALAPPDATA") ?? currentDir(), "zaplink")

pub fn tokenPath() str:
	fs.join(stateDir(), "token")

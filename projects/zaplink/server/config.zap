# The daemon's config (the agents a session can start, the recent dirs, where it listens) and
# its token, kept in the state dir; written with the defaults the first time.

import fs
import link
import win

# a program typed into a session's terminal once it starts
pub type Agent:
	name str
	command str

pub type Config:
	host str   # the interface listened on: the loopback one unless a client comes from elsewhere
	port i64
	agents Agent[]
	dirs str[]   # the recent dirs, the last used first

	fn save():
		_ = fs.createDir(link.stateDir())
		_ = fs.writeFile(configPath(), self.toJson())

	# dir first among the recent ones, kept to twenty
	fn useDir(dir str):
		kept = [windowsPath(dir)]
		for d in dirs:
			if windowsPath(d) != kept[0] and kept.len < 20: kept.push(windowsPath(d))
		dirs = kept
		self.save()

fn configPath():
	fs.join(link.stateDir(), "config.json")

pub fn loadConfig() Config:
	if fs.readFile(configPath()) is text:
		if Config.fromJson(text) is config: return config
	config = Config(
		host = "127.0.0.1",
		port = link.defaultPort,
		agents = [
			Agent(name = "claude", command = "claude"),
			Agent(name = "opencode", command = "opencode"),
			Agent(name = "codex", command = "codex")
		],
		dirs = [windowsPath(currentDir())]
	)
	config.save()
	config

# a dir as Windows writes it: backslashes, no "." or ".." parts, no slash at the end
pub fn windowsPath(path str) str:
	fs.normalize(path).replace("/", "\\")

# the token a client must give: the one kept, or a new one written for the clients of this user
pub fn loadToken() str:
	if fs.readFile(link.tokenPath()) is kept:
		if kept.trimmed().len >= 32: return kept.trimmed().copy()
	token = win.secureRandom(16).map("{it:02x}").join("")
	_ = fs.createDir(link.stateDir())
	_ = fs.writeFile(link.tokenPath(), token)
	token

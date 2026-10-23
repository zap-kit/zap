# The system's handles a std type holds (a file, a socket) are closed once: when the value goes,
# or earlier by close(); a copy, which would close it twice, is refused.

import fs
import net

fn readThenForget(path str):
	f = fs.open(path) ?? return -1
	f.len

test "a file not closed is closed when it goes":
	_ = fs.writeFile("{testDir()}handles-test.txt", "abc")
	print(readThenForget("{testDir()}handles-test.txt"))
	if fs.deleteFile(
		"{testDir()}handles-test.txt"
	) is error: print("{error}") else: print("deleted")
	prints """
		3
		deleted
		"""

test "a file closed early is not closed again":
	_ = fs.writeFile("{testDir()}handles-early.txt", "abcd")
	f = fs.open("{testDir()}handles-early.txt") ?? fail("{error}")
	f.close()
	if fs.deleteFile(
		"{testDir()}handles-early.txt"
	) is error: print("{error}") else: print("deleted")
	f.close()
	prints "deleted"

fn listenAndForget():
	listener = net.tcpListen(0) ?? return -1
	listener.port()

test "a listener not closed frees its port when it goes":
	port = listenAndForget()
	if net.tcpListen(port) is again:
		print(again.port() == port)
	prints "true"

# Memory the system hands out, reached through std/win's bounded view: each write and read is
# checked against the view's length, and the program's side against its list's.

import win

extern fn VirtualAlloc(address i64, size i64, kind i64, protect i64) i64
extern fn VirtualFree(address i64, size i64, kind i64) bool

# a page of the system's memory, read and write (MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE)
fn page():
	VirtualAlloc(0, 4096, 0x3000, 4)

test "values written to foreign memory are read back":
	at = page()
	m = win.memoryAt(at, 64)
	floats f32[] = [1.5, -2.0, 4.25]
	m.write(0, floats)
	m.write(12, [u32(7), 9])
	back f32[] = [0.0, 0.0, 0.0]
	m.read(0, back)
	print("{back} {m.bytes(12, 8)} {m.loadWord(12)}")
	m.part(32, 16).copyFrom(0, m.part(0, 12))
	again f32[] = [0.0, 0.0, 0.0]
	m.read(32, again)
	print(again)
	m.write(60, floats[2..3])
	print(m.bytes(60, 4) == floats[2..3].rawBytes())
	VirtualFree(at, 0, 0x8000)
	prints """
		[1.5, -2, 4.25] [7, 0, 0, 0, 9, 0, 0, 0] 38654705671
		[1.5, -2, 4.25]
		true
		"""

test "a write past the view's end stops the program" stops IndexOutOfBounds:
	import win
	extern fn VirtualAlloc(address i64, size i64, kind i64, protect i64) i64
	m = win.memoryAt(VirtualAlloc(0, 4096, 0x3000, 4), 8)
	m.write(4, [u32(1), 2])

test "a part beyond the view stops the program" stops IndexOutOfBounds:
	import win
	extern fn VirtualAlloc(address i64, size i64, kind i64, protect i64) i64
	m = win.memoryAt(VirtualAlloc(0, 4096, 0x3000, 4), 8)
	print(m.part(4, 8).len)

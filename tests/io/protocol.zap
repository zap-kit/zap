# A small binary protocol: typed messages encoded into bytes and decoded back, with a length
# prefix, the way a game server frames packets on a socket.
type Message:
	Move(id i64, x i64, y i64)
	Say(id i64, text str)
	Quit(id i64)

fn putU32(mut out u8[], v i64):
	u = u32.wrap(v)   # a negative value travels as its two's complement
	out.push(u & 255)
	out.push((u >> 8) & 255)
	out.push((u >> 16) & 255)
	out.push((u >> 24) & 255)

fn getU32(bytes ref u8[], at i64) i64:
	(
		bytes[at] | (u32(bytes[at + 1]) << 8) | (u32(bytes[at + 2]) << 16) | (
			u32(bytes[at + 3]) << 24
		)
	)

fn putStr(mut out u8[], s str):
	putU32(out, s.len)
	for i in 0..s.len:
		out.push(s[i])

fn getStr(bytes ref u8[], at i64) str:
	n = getU32(bytes, at)
	chars = []
	for i in 0..n:
		chars.push(bytes[at + 4 + i])
	str(move chars)

# [length u32][tag u8][payload]: the frame a reader can split from a byte stream
fn encode(m Message):
	body u8[] = []
	match m:
		Move(id, x, y):
			body.push(1)
			putU32(body, id)
			putU32(body, x)
			putU32(body, y)
		Say(id, text):
			body.push(2)
			putU32(body, id)
			putStr(body, text)
		Quit(id):
			body.push(3)
			putU32(body, id)
	frame = []
	putU32(frame, body.len)
	for b in body:
		frame.push(b)
	frame

fn decode(frame ref u8[]) Message?:
	if frame.len < 5: return none
	n = getU32(frame, 0)
	if frame.len != n + 4: return none
	tag = frame[4]
	if tag == 1: return .Move(getU32(frame, 5), getU32(frame, 9), getU32(frame, 13))
	if tag == 2: return .Say(getU32(frame, 5), getStr(frame, 9))
	if tag == 3: return .Quit(getU32(frame, 5))
	none

fn describe(m Message):
	match m:
		Move(id, x, y): "#{id} moves to {x},{y}"
		Say(id, text): "#{id} says {text}"
		Quit(id): "#{id} quits"

outgoing = [Message.Move(7, 120, -5), Message.Say(7, "olá, mundo"), Message.Quit(9)]
mut stream = []
for m in outgoing:
	frame = m.encode()
	print("{m.describe()} -> {frame.len} bytes, tag {frame[4]}")
	for b in frame:
		stream.push(b)
print("stream: {stream.len} bytes")
# split the stream back into frames and decode each one
mut at = 0
mut count = 0
while at + 4 <= stream.len:
	n = getU32(stream, at)
	frame = stream[at..at + 4 + n]
	match decode(frame):
		m: print("decoded {m.describe()}")
		none: print("bad frame")
	at = at + 4 + n
	count += 1
print("{count} frames, {stream.len - at} bytes left")
bad u8[] = [0, 0, 0, 0, 9]
print(decode(bad) == none)

test "typed messages framed with a length prefix decode back to themselves":
	main()
	prints """
	    #7 moves to 120,-5 -> 17 bytes, tag 1
	    #7 says olá, mundo -> 24 bytes, tag 2
	    #9 quits -> 9 bytes, tag 3
	    stream: 50 bytes
	    decoded #7 moves to 120,4294967291
	    decoded #7 says olá, mundo
	    decoded #9 quits
	    3 frames, 0 bytes left
	    true
	    """

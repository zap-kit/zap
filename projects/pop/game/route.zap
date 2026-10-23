# A scripted route of keys for headless and recorded runs: "right@10-40,shift@50,up@60-62" holds
# each key over its frames (both ends in).

type KeyHold:
	key str
	first i64
	last i64

pub type KeyRoute:
	holds KeyHold[]

	fn held(key str, n i64):
		for h in holds:
			if h.key == key and n >= h.first and n <= h.last: return true
		false

	# the key pressed at frame n, if the route has one that is none of the keys held
	fn pressedAt(n i64):
		for h in holds:
			if n >= h.first and n <= h.last and not (h.key in heldKeys): return h.key.copy()
		""

	# the keys the route holds at frame n
	pub fn inputAt(n i64) Input:
		Input(
			pressed = self.pressedAt(n),
			left = self.held("left", n),
			right = self.held("right", n),
			up = self.held("up", n),
			down = self.held("down", n),
			shift = self.held("shift", n),
			restart = self.held("restart", n),
			showTime = self.held("space", n),
			nextLevel = self.held("next", n)
		)

pub fn parseKeyRoute(text str) KeyRoute:
	holds = []
	for part in text.split(","):
		p = part.trimmed()
		if p == "": continue
		parts = p.split("@")
		if parts.len != 2: fail("a route's key needs @frames: {p}")
		ends = parts[1].split("-")
		first = i64.parse(ends[0]) ?? fail("bad frame in {p}")
		last = first
		if ends.len > 1:
			last = i64.parse(ends[1]) ?? fail("bad frame in {p}")
		holds.push(KeyHold(key = parts[0].copy(), first, last))
	KeyRoute(holds)

heldKeys = ["left", "right", "up", "down", "shift", "restart", "space", "next"]

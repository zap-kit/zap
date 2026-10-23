# A route: the orders a scripted run gives at the game's iterations, the checks', the
# screenshots' and the oracle's way of playing (`--route "digger@200 faster@40..60 pause@300+20
# nuke@400"`). A skill goes by a click on the lowest numbered living lemming, as a player's would;
# the rate buttons are held through a span of iterations; a pause lasts a number of steps.

pub type OrderKind:
	Give(skill Skill)
	Faster
	Slower
	Pause(steps i64)
	Nuke

pub type Order:
	kind OrderKind
	iteration i64
	last i64   # the last iteration a held button is down

pub type Route:
	orders Order[]
	pauseLeft i64 = 0   # the steps the pause still lasts

fn orderKind(name str) OrderKind:
	if name == "faster": return .Faster
	if name == "slower": return .Slower
	if name == "nuke": return .Nuke
	skill = skills.find("{it}".lower() == name.lower()) ?? fail("no order {name}")
	.Give(skill.copy())

# one order: "digger@200", "faster@40..60", "pause@300+20"
pub fn parseOrder(word str) Order:
	parts = word.split("@")
	if parts.len != 2: fail("an order is name@iteration, got {word}")
	if parts[0] == "pause":
		at = parts[1].split("+")
		if at.len != 2: fail("a pause is pause@iteration+steps, got {word}")
		first = i64.parse(at[0]) ?? fail("no iteration in {word}")
		steps = i64.parse(at[1]) ?? fail("no steps in {word}")
		return Order(kind = .Pause(steps), iteration = first, last = first)
	span = parts[1].split("..")
	first = i64.parse(span[0]) ?? fail("no iteration in {word}")
	last = first
	if span.len == 2:
		last = i64.parse(span[1]) ?? fail("no end in {word}")
	Order(kind = orderKind(parts[0]), iteration = first, last)

# the orders of a --route, separated by spaces
pub fn parseRoute(text str) Route:
	Route(orders = text.words().map(parseOrder(it)))

# where a click takes a lemming: the middle of the box lemmingsAt reads, kept inside the view the
# cursor can reach (a lemming off the screen's right edge is clicked at the edge, as DOS does)
pub fn aimAt(g Game, l Lemming) (i64, i64):
	x = l.x + l.action.frameLeftDx() + clickLeft + 6
	y = l.y + l.action.frameTopDy() + 5
	(x.clamp(g.level.screenStart, g.level.screenStart + 319), y.clamp(0, worldHeight - 1))

# the lowest numbered living lemming, the one a skill order goes to
pub fn routeTarget(g Game) i64?:
	(0..g.lemmings.len).find(not g.lemmings[it].removed)

# the orders due now carried out (call it after each step); what happened, a line each
pub fn runRoute(mut g Game, mut route Route) str[]:
	lines = []
	if route.pauseLeft > 0:
		route.pauseLeft -= 1
		if route.pauseLeft == 0:
			g.paused = false
		return lines
	g.rateChange = 0
	for o in route.orders:
		if g.iteration < o.iteration or g.iteration > o.last: continue
		match o.kind:
			Faster: g.rateChange = 1
			Slower: g.rateChange = -1
			Nuke:
				if g.iteration == o.iteration: g.nuke()
			Pause(steps):
				g.paused = true
				route.pauseLeft = steps
			Give(skill):
				target = g.routeTarget() ?? continue
				x, y = g.aimAt(g.lemmings[target])
				g.selected = skill.copy()
				given = g.clickAt(x, y, false)
				lines.push("iteration {g.iteration}: {skill} at {x}, {y}: {given}")
	lines

# Shortest paths on a small road map: adjacency in a map of lists, a hand-rolled priority queue.
type Edge:
	to str
	cost i64

type Graph:
	adj {str: Edge[]}

	# a road is two links, and each link keeps both names
	mut fn road(move a str, move b str, cost i64):
		self.link(a.copy(), b.copy(), cost)
		self.link(b, a, cost)

	fn link(move a str, move b str, cost i64):
		more = adj.remove(a) ?? []
		more.push(Edge(to = b, cost))
		adj[a] = more

	fn shortest(start str, to str) i64?:
		dist {str: i64} = {}
		queue = [Edge(to = start.copy(), cost = 0)]
		while not queue.isEmpty:
			# the cheapest entry first (a list scan is fine for a handful of towns)
			best = 0
			for i in 1..queue.len:
				if queue[i].cost < queue[best].cost:
					best = i
			cur = queue.remove(best)
			if cur.to in dist: continue
			dist[cur.to.copy()] = cur.cost
			if cur.to == to: return cur.cost
			if adj.get(cur.to) is edges:
				for e in edges:
					if e.to not in dist:
						queue.push(Edge(to = e.to.copy(), cost = cur.cost + e.cost))
		none

mut g = Graph(adj = {})
g.road("prontera", "izlude", 3)
g.road("prontera", "geffen", 7)
g.road("izlude", "payon", 4)
g.road("geffen", "payon", 2)
g.road("payon", "alberta", 5)
g.road("morroc", "comodo", 9)
for pair in [
	["prontera", "payon"],
	["prontera", "alberta"],
	["geffen", "izlude"],
	["prontera", "comodo"]
]:
	match g.shortest(pair[0], pair[1]):
		d: print("{pair[0]} -> {pair[1]}: {d}")
		none: print("{pair[0]} -> {pair[1]}: unreachable")
print(g.adj.len)

test "the shortest paths of the road map come out of a hand-rolled queue":
	main()
	prints """
	    prontera -> payon: 7
	    prontera -> alberta: 12
	    geffen -> izlude: 6
	    prontera -> comodo: unreachable
	    7
	    """

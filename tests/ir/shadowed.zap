# A region's loop calls a method whose field (`nodes`) has the name of a local of the function
# around it: the inlined body reads the field, never the local (found by the engine's glTF loader).
type JN:
	count i64
	first i64
	number f64

type J:
	nodes JN[]
	children i64[]
	root i64

	fn at(node i64, k i64):
		children[nodes[node].first + k]

	fn count(node i64):
		nodes[node].count

	fn number(node i64):
		nodes[node].number

type G:
	name str
	parent i64

fn scene(d J, n i64, nodes G[]):
	roots = 0
	isRoot = fill(n, false)
	for k in 0..d.count(roots):
		isRoot[i64(d.number(d.at(roots, k)))] = true
	isRoot

d = J(
	nodes = [JN(count = 2, first = 0, number = 0.0), JN(count = 0, first = 0, number = 1.0), JN(count = 0, first = 0, number = 2.0)],
	children = [1, 2],
	root = 0
)
print(d.scene(3, [G(name = "a", parent = -1)]))

test "a field named like a local":
	main()
	prints "[false, true, true]"

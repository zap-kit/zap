type Tree:
	Leaf
	Node(value i64, kids Tree[])
type Dir:
	name str
	sub Dir[]
	index {str: Dir}
fn count(t Tree) i64:
	match t:
		Leaf: 0
		Node(v, kids): v + kids.map(count).sum()
t = Tree.Node(1, [.Node(2, []), .Leaf])
print(t.count())
f = Dir(name = "root", sub = [Dir(name = "a", sub = [], index = {})], index = {})
print(f.sub[0].name)
print(f)

test "recursive types count, print and drop their parts":
	main()
	prints r"""
		3
		a
		Dir(name = "root", sub = [Dir(name = "a", sub = [], index = {})], index = {})
		"""

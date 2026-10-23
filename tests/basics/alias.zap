# alias name = expr: in a block to its end, at a file's top level to the file's end; every use is
# the expression written again there (read where it is used, no borrow held)
type Bag:
	items i64[]
	name str

type Ctx:
	box Bag

alias items = c.box.items

fn grow(mut c Ctx):
	items.push(items.len * 10)

fn total(c Ctx):
	items.sum()

mut c = Ctx(box = Bag(items = [1, 2], name = "b"))
c.grow()
c.grow()
print(c.total())
if true:
	alias n = c.box.name
	print(n.len)
alias first = c.box.items[0]
print(first)
c.box.items[0] = 7
print(first)

test "an alias is its expression written again where it is used":
	main()
	prints """
		53
		1
		1
		7
		"""

test "an alias is not rebound" refuses AliasRebound:
	alias x = 1
	x = 2

test "an alias is not a parameter's name" refuses AliasRebound:
	alias k = 3

	fn f(k i64) i64:
		k

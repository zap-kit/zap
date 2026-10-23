# Maps through the intermediate form: literals, maps made by calls and owned by locals, stored
# in fields, returned, reassigned; every table freed.
#
# A map a function builds and gives back inside an optional is the caller's: not dropped by the
# function (json decoding of a map of lists does this).

type Index:
	byName {str: i64}
	count i64

fn table():
	{"a": 1, "b": 2}

fn indexOf(words str[]):
	m {str: i64} = {}
	for i in 0..words.len:
		m[words[i].copy()] = i
	Index(byName = m, count = words.len)

fn swapped(flag bool):
	m = {1: 10}
	if flag:
		m = {2: 20, 3: 30}
	m

fn churn(n i64):
	before = liveBlocks()
	total = 0
	for i in 0..n:
		t = table()
		total += t.len
		ix = indexOf(["x", "y{i}"])
		total += ix.byName.get("x") ?? 0
		total += swapped(i % 2 == 0).len
	total > 0 and liveBlocks() == before

test "maps owned through the form":
	ix = indexOf(["p", "q"])
	expect table().len == 2
	expect (ix.byName.get("q") ?? 0) == 1
	expect swapped(true).len == 2
	expect (swapped(false).get(1) ?? 0) == 10
	expect churn(50)

type Inventory:
	items {str: str[]}

fn counts(words str[]) {str: i64}?:
	if words.isEmpty: return none
	m {str: i64} = {}
	for w in words:
		m[w.copy()] = w.len
	m

test "maps given back in optionals":
	inv = Inventory.fromJson(
		"\{\"items\":\{\"sword\":[\"iron\"],\"potion\":[\"red\",\"blue\"]\}\}"
	) ??
		Inventory(items = {})
	c = counts(["ab", "cde"]) ?? {}
	expect inv.items.len == 2
	expect ((inv.items.get("potion") ?? []).len) == 2
	expect (c.get("cde") ?? 0) == 3
	expect counts([]) == none

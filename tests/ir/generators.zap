# Generators lowered into the loops that walk them (spec 7.3).

type Op:
	a i64
	b i64
	args i64[]

fn reads(op Op) Seq<i64>:
	if op.a >= 0: yield op.a
	if op.b >= 0: yield op.b
	for v in op.args:
		yield v

type Marks:
	on bool[]

# the turn's blocks run from the yields before the generator's loop too: what the turn reads
# stays in it, not moved before that loop
fn marked(ops Op[], m Marks):
	for op in ops:
		for v in op.reads():
			if m.on[v]: return true
	false

test "a yield before a generator's loop runs the turn":
	ops = [Op(a = 1, b = -1, args = [2, 3]), Op(a = -1, b = 4, args = [])]
	expect marked(ops, Marks(on = [false, false, false, false, true]))
	expect not marked(ops, Marks(on = [false, false, false, false, false]))

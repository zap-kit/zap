# 4.2 Parameter conventions
#
# `x T` borrows for reading (the callee reads it and calls non-`mut` methods); `mut x T` borrows
# exclusively for writing (everything except moving it away); `move x T` takes ownership (the
# caller's variable is gone). Passing is never a copy: a read or `mut` parameter refers to the
# caller's value for the call, a `move` parameter is the value itself. A method taking `mut self T`
# borrows `self` exclusively and needs a `mut` receiver; one taking `self T` borrows it for reading.
# A parameter is never typed `mut ref T`: `mut x T` already changes the caller's value (a `ref T`
# parameter says what a returned reference points into, *Origins*).

type Hero:
	name str
	hp i64
	level i64

	fn heal(amount i64):
		hp += amount

	fn isAlive():
		hp > 0

fn damage(mut h Hero, amount i64):
	h.hp -= amount

fn levelUp(mut h Hero):
	h.level += 1
	h.heal(10)

fn describe(h Hero):
	"{h.name} lv{h.level} hp={h.hp} alive={h.isAlive()}"

fn eat(move xs str[]):
	xs.len

test "a mut parameter changes the caller's value":
	ana = Hero(name = "Ana", hp = 30, level = 1)
	ana.damage(25)
	print(ana.describe())
	ana.levelUp()
	print(ana.describe())
	ana.damage(50)
	print(ana.describe())
	party = [Hero(name = "Bia", hp = 10, level = 1)]
	party[0].heal(5)
	party[0].damage(3)
	print("{party[0].describe()} {eat(["a", "b"])}")
	prints """
		Ana lv1 hp=5 alive=true
		Ana lv2 hp=15 alive=true
		Ana lv2 hp=-35 alive=false
		Bia lv1 hp=12 alive=true 2
		"""

test "a read parameter is not changed" refuses NeedsMut:
	fn f(xs i64[]):
		xs.push(1)
	mut a = [1]
	f(a)

test "a moved argument is gone" refuses UseAfterGiven:
	fn eat(move xs i64[]) i64:
		xs.len
	ys = [1]
	n = eat(ys)
	print("{n} {ys.len}")

# Plain numbers are copied into read parameters (cheaper, with no observable difference); a
# struct or a fixed array is read in place even when it holds plain data, so one call cannot read
# it through a parameter and change it through a `mut` argument.

test "a value lent to read is not changed by the same call" refuses LentAndChanged:
	type H:
		hp i64
	fn copyInto(a H, mut b H):
		b.hp = a.hp + 1
	mut h = H(hp = 1)
	copyInto(h, h)
	print(h.hp)

# A `mut` parameter takes a struct, a fixed array, a list or a map, never a primitive (return the
# new value instead), and its argument is a `mut` place, not a temporary; two `mut` arguments of
# one call (or one and a `mut self` method's receiver) are never the same place or overlap.

test "a mut primitive is a result instead" refuses MutParameterType:
	fn inc(mut n i64):
		n += 1
	mut a = 1
	inc(a)
	print(a)

test "a mut argument is a mut place" refuses MutArgImmutable:
	type Point:
		x i64
	fn bump(mut p Point):
		p.x += 1
	fn bumped(p Point) i64:
		bump(p)
		p.x
	print(bumped(Point(x = 1)))

test "a mut argument is a place" refuses MutArgTemporary:
	fn add(mut xs i64[]):
		xs.push(1)
	add([1])

test "two mut arguments are never one place" refuses LentTwice:
	fn both(mut a i64[], mut b i64[]):
		a.push(b.len)
	mut xs = [1]
	both(xs, xs)
	print(xs)

# Arguments are evaluated left to right, values (plain data, `move` arguments) before the addresses
# of read and `mut` arguments, so a call that grows the list its receiver lives in is well defined.

type Node:
	kids i64[]

fn grow(mut nodes Node[]):
	loop 64:
		nodes.push(Node(kids = []))
	nodes.len

test "a receiver's address is taken after the arguments":
	nodes = [Node(kids = [])]
	loop 3:
		nodes[0].kids.push(grow(nodes))
	expect nodes[0].kids == [65, 129, 193]

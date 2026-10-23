# Entry file: the main module. Imports module dirs relative to this file's directory.
import util
import game.world

mut total = 100
mut count = 7

print(util.clamp(15, 0, 10))   # 10
print(util.revealed())   # 42
print(util.shout(util.greeting))   # HELLO!
print(util.greeting)   # hello

mut w = world.World()
ana = w.add(.Player, "Ana", 1, 1)
bob = w.add(.Monster, "Poring", 5, 4)
print(w.distance(ana, bob) ?? -1)   # 7
print(w.distance(ana, 99) ?? -1)   # -1

match w.entities.remove(bob):
	mut e:
		moved = move e
		moved.walk(100, -100)   # clamped to the world bounds
		print(moved.describe())   # Poring#2 at 7,0 hp=10
		print(moved.kind == .Monster)
	none: print("missing")

hero = world.Entity(id = 9, kind = .Player, name = "Hero", x = 0, y = 0, hp = 1)
print(hero.describe())

test "an entry file imports module dirs beside it":
	main()
	prints """
	    10
	    42
	    HELLO!
	    hello
	    7
	    -1
	    Poring#2 at 7,0 hp=10
	    true
	    Hero#9 at 0,0 hp=1
	    """

test "defaults written in another module mean what they meant there":
	expect util.ask("why") == "why?"
	expect util.ask("why", end = "!") == "why!"
	print(util.Banner(text = "b"))
	prints """
		Banner(text = "b", mark = "??")
		"""

test "types of the same name in two modules stay apart":
	a = util.tags()
	b = world.tags()
	print("{a.len} {a[0].parts.len} {b.len} {b[0].label.len}")
	prints """
		2 3 1 4
		"""

test "module variables of the same name in two modules stay apart":
	a = util.addToTotal(5)
	b = util.addToTotal(3)
	expect a == 5
	expect b == 8
	expect total == 100
	expect util.tripled(4) == 12
	expect count == 7

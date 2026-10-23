# x.f() calls a method of x's type's block, else a function taking x's type first: the caller's
# own or an import's (the type's module's when imported); two such are an error.
# T.f() calls a function giving a T and taking none first, found the same way.
import orbits
import extra

fn twice(o orbits.Orbit):
	o.distance * 2.0

test "a type's functions from several files of its module are called on it":
	o = orbits.Orbit(yaw = 0.5, distance = 10.0)
	o.steer(0.5)
	expect o.forward() == 2
	expect o.eye() == 8

test "a function taking the type first is called on it: the caller's or an import's":
	o = orbits.Orbit(yaw = 0.5, distance = 10.0)
	expect o.grown(2.0) == 12
	expect o.twice() == 20
	expect o.spin() == 5

test "a private function of another module is not the method of a call that names it":
	o = orbits.Orbit(yaw = 0.5, distance = 10.0)
	expect o.tracked([1, 2, 3]) == 11

fn near():
	orbits.Orbit(yaw = 3.0, distance = 1.0)

test "a function giving the type is called on its name: its module's, the caller's, an import's":
	expect orbits.Orbit.level(10.0).distance == 10
	expect orbits.Orbit.near().distance == 1
	expect orbits.Orbit.far().yaw == 1

test "two functions a type's call could be" refuses AmbiguousFunction:
	import orbits
	import extra
	import other

	print(orbits.Orbit.far().yaw)

test "two functions an orbit's method could be" refuses AmbiguousMethod:
	import orbits
	import extra
	import other

	o = orbits.Orbit(yaw = 0.5, distance = 10.0)
	print(o.spin())

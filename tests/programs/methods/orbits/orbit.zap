# An orbit whose functions sit in two files of its module.

pub type Orbit:
	yaw f32
	distance f32

	pub fn forward() f32:
		yaw * 2.0

# a function giving an Orbit: called on the type's name too, Orbit.level(10.0)
pub fn level(distance f32) Orbit:
	Orbit(yaw = 0.0, distance)

# a function taking an Orbit first: called as a method too
pub fn grown(o Orbit, by f32) f32:
	o.distance + by

# a private function named as one of extra's, which changes its list: a call here reads only this
fn track(o Orbit, marks i64[]):
	marks.len + i64(o.distance)

pub fn tracked(o Orbit, marks i64[]) i64:
	firsts = marks[..1]   # a reference into marks, never changed
	o.track(firsts)

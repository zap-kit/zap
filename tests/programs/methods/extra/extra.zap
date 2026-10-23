# A function on an orbit of another module.

import orbits

pub fn spin(o orbits.Orbit) f32:
	o.yaw * 10.0

pub fn far() orbits.Orbit:
	orbits.Orbit(yaw = 1.0, distance = 100.0)

pub type Log:
	count i64

# a private function of the name of one of orbits', its second parameter changed
fn track(mut log Log, mut marks i64[]):
	marks.push(log.count)
	marks.len

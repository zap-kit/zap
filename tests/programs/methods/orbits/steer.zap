# The orbit's functions that change it.

pub fn steer(mut orbit Orbit, dt f32):
	orbit.yaw += dt

pub fn eye(orbit Orbit) f32:
	orbit.distance - orbit.forward()

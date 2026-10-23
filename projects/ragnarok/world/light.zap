# The sun of a map as the client lights with it, per vertex (BrowEdit 3's reading of the client):
# the direction toward it from the RSW's longitude and latitude, and a vertex's brightness from
# how its normal faces it, the ambient and diffuse colors mixed so that their sum never washes
# a surface out.

import ragnarok.rsw

# the direction toward the sun in the map's world (x east, y up, z south): the longitude turns
# it from the north toward the west (the shadows baked in the lightmaps fall away from it)
pub fn sunDirection(sun rsw.Sun) Vec3:
	toRad f32 = pi / 180.0
	lat = f32(sun.latitude) * toRad
	lon = f32(sun.longitude) * toRad
	Vec3(-lat.sin() * lon.sin(), lat.cos(), -lat.sin() * lon.cos())

fn channel(nl f32, a f32, d f32):
	af = (1.0 - a) * a
	ambient = a - af + af * d
	df = (1.0 - d) * d
	diffuse = d - df + df * a
	lit = (nl * diffuse + ambient).min(1.0)
	cap = (d.max(a) + (1.0 - d.max(a)) * d.min(a)).min(1.0)
	lit.min(cap).max(0.0)

# the brightness of a surface whose normal is n (none: unshaded, the cap alone)
pub fn sunlight(sun rsw.Sun, toward Vec3, n Vec3?) Vec3:
	nl = match n:
		v: (v @ toward).clamp(0.0, 1.0)
		none: 1.0
	Vec3(
		channel(nl, sun.ambient.x, sun.diffuse.x),
		channel(nl, sun.ambient.y, sun.diffuse.y),
		channel(nl, sun.ambient.z, sun.diffuse.z)
	)

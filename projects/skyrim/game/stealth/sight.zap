# Where a watcher looks from and what it looks at, and the light on the watched. The watcher's eye
# is its camera height over its feet (the player's first person eye, the race's for others), 0.57 of
# it while it sneaks (0x140685b30); a ray from the eye goes to the watched's chest (half its
# height), head (85 hundredths) and legs (15 hundredths, each 0.57 of that while it sneaks) and
# the watcher sees it when one reaches (Actor::RequestLOS 0x1406a2830, CalculateLOSLocation
# 0x1406a30c0), the ray itself the caller's to cast on the cell's geometry. The light on an actor
# is the sum of the lights near it, each its color's mean times its dimmer, falling off with the
# square of the distance over the radius (0x141576ca0), plus the cell's ambient and directional
# light, times 100 (0x140726250).

import math

pub eyeHeight f32 = 121.0   # the skeleton's Camera3rd node over the feet
pub sneakScale f32 = 0.57   # the share of a height a sneaking actor has
pub bodyHeight f32 = 128.0   # a standing human's capsule

# a light that lights actors: where, how far it reaches, its color (0..1) and dimmer
pub type Lamp:
	at Vec3
	radius f32
	color Vec3
	dimmer f32 = 1.0

# the light of the cell the watched stands in
pub type Lighting:
	lamps Lamp[] = []
	ambient f32 = 0.0   # the mean of the cell's ambient color (0..1)
	directional f32 = 0.0   # the mean of its directional color
	directionalScale f32 = 1.0   # what the game scales the directional light by (BSShaderManager 0xe0)
	ambientMax f32 = 0.0   # the highest component of the ambient color
	exterior bool = false

# the eye of an actor standing at `feet`
pub fn eyeAt(feet Vec3, sneaking bool) Vec3:
	feet + Vec3(0.0, 0.0, eyeHeight * (sneakScale if sneaking else 1.0))

# the points of a body of this height standing at `feet` a ray must reach: chest, head, legs
pub fn bodyPoints(feet Vec3, height f32, sneaking bool) Vec3[]:
	h = height * (sneakScale if sneaking else 1.0)
	[feet + Vec3(0.0, 0.0, h * 0.5), feet + Vec3(0.0, 0.0, h * 0.85),
		feet + Vec3(0.0, 0.0, h * 0.15)]

# the angle between the way a watcher at `from` faces (radians from north toward east) and the
# direction to `to`, 0 to pi (0x1406a32c0)
pub fn angleToward(heading f32, from Vec3, to Vec3) f32:
	math.angleBetween(heading, (to.x - from.x).atan2(to.y - from.y)).abs()

# the light of one lamp on a point
fn lampLight(l Lamp, at Vec3):
	far = (l.at.distance(at) / l.radius).clamp(0.0, 1.0)
	l.dimmer * (l.color.x + l.color.y + l.color.z) * (1.0 - far * far) * 0.33333334

# an actor's light level at a point before the cell's ambient is taken off (0x140726250): 100 for
# the sum of the lamps' light, the ambient and the directional light being 1
pub fn lightRawAt(l Lighting, at Vec3) f32:
	total = l.ambient + l.directionalScale * l.directional
	for lamp in l.lamps: total += lamp.lampLight(at)
	total * 100.0

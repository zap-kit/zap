# What the crosshair is on: the nearest reference the player can activate whose rough shape (an
# upright capsule standing on its origin, sized by its kind) the view ray meets within the game's
# reach, fActivatePickLength (180 units unless the plugin sets it). The game casts the ray against
# the references' collision; these capsules stand in for it until the physics casts rays.

defaultReach = 180.0

# the rough shape of what the crosshair picks: a radius and a height by record type
type Shape:
	radius f32
	height f32

fn shapeOf(kind str) Shape?:
	if kind in itemKinds: return Shape(radius = 10.0, height = 20.0)
	match kind:
		"CONT": Shape(radius = 30.0, height = 60.0)
		"DOOR": Shape(radius = 40.0, height = 120.0)
		"FURN": Shape(radius = 40.0, height = 50.0)
		"ACTI", "FLOR", "TREE": Shape(radius = 20.0, height = 40.0)
		"NPC_": Shape(radius = 25.0, height = 128.0)
		_: none

# how far along the ray (from `eye` along the unit `dir`) it passes closest to the upright segment
# from `base` up `height`, and how close it passes
fn closestToUpright(eye Vec3, dir Vec3, base Vec3, height f32):
	up = Vec3(0.0, 0.0, 1.0)
	w = eye - base
	b = dir @ up
	d = dir @ w
	e = up @ w
	denom = 1.0 - b * b
	along = (b * e - d) / denom if denom > 0.0001 else -d
	high = (e + b * along).clamp(0.0, height)
	along = (base + up * high - eye) @ dir
	(along, (eye + dir * along - base - up * high).length())

# the reference the crosshair is on, looking from `eye` along `dir` (unit length), none for none
pub fn targetOf(w GameWorld, eye Vec3, dir Vec3) i64?:
	reach = f32(w.settings.get("factivatepicklength") ?? defaultReach)
	best i64? = none
	nearest = reach
	for id in w.forms.keys().sorted():
		f = w.forms[id]
		if id == w.player or not f.enabled or f.deleted or f.cell == 0: continue
		shape = shapeOf(f.baseKind) ?? continue
		along, apart = eye.closestToUpright(dir, f.positionOf(), shape.height)
		if along <= 0.0 or along >= nearest or apart > shape.radius: continue
		best = id
		nearest = along
	best

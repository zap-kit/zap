# A cell's physics: its refs placed with their models' collision, what does not move as the
# scene's triangles, the clutter as dynamic bodies, in Skyrim's units (havokScale to a meter).

import skyrim
import skyrim.esm
import skyrim.nif
import engine.physics

# a dynamic body as the cell placed it
pub type Placed:
	body i64
	editorId str
	shape str   # its leaves' kind, or compound for several
	at Vec3   # its center of mass as placed
	material i64   # its collision's Havok material (its first triangle's), 0 for none

pub type CellWorld:
	world physics.World
	placed Placed[] = []
	staticShapes i64 = 0   # the colliders the scene is made of
	floors f32[] = []   # the heights of the farmhouse's floor pieces, highest first
	chains Chain[] = []   # the bodies constraints link (hanging.zap)

dynamicLayers = [4, 5]   # clutter, weapon
# the layers of what does not move that clutter meets: static, anim static, transparent, clutter,
# weapon, trees, props, terrain, ground, debris small and large, transparent small, invisible
# wall, transparent small anim
sceneLayers = [1, 2, 3, 4, 5, 9, 10, 13, 17, 19, 20, 26, 27, 28]
floorPieces = ["FarmIntInn", "FarmB"]   # the editor ids the farmhouse's floors start with
rackPrefix = "WeaponRack"   # the editor ids of the racks' activators
rackReach f32 = 64.0   # a weapon this near a rack (across) and above its foot is on it
rackHeight f32 = 160.0

# whether a weapon at p hangs on one of the racks standing at `racks`
fn isOnRack(racks Vec3[], p Vec3):
	racks.any(
		Vec2(.x - p.x, .y - p.y).length() <= rackReach and p.z >= .z and
			p.z <= it.z + rackHeight
	)

# the triangles first..end of the collider, placed, three corners each
fn leafTriangles(c nif.Collider, place Mat4, first i64, end i64):
	positions = (first * 3..end * 3).map(place.applyPoint(c.positions[c.indices[it]]))
	(positions, (0..positions.len).map(u32(it)))

# the ball of a sphere or capsule primitive, placed
fn roundOf(p nif.Primitive, place Mat4) physics.Round:
	scale = place.applyDirection(Vec3(1, 0, 0)).length()
	match p:
		SpherePrimitive(center, radius):
			.Ball(place.applyPoint(center), place.applyPoint(center), radius * scale)
		CapsulePrimitive(a, b, radius):
			.Ball(place.applyPoint(a), place.applyPoint(b), radius * scale)
		_: .Hull

# Each leaf of the collider a piece, where `place` puts it: a hull as its core and shell (its grown
# triangles when the core is flat), a mesh as its convex hull.
fn piecesOf(c nif.Collider, place Mat4):
	scale = place.applyDirection(Vec3(1, 0, 0)).length()
	out = []
	primitive = 0
	for k in 0..c.kinds.len:
		first = c.leafEnds[k - 1] if k > 0 else 0
		positions, indices = c.leafTriangles(place, first, c.leafEnds[k])
		piece = physics.Piece(positions, indices)
		if c.kinds[k] in ["box", "sphere", "capsule", "convex"]:
			match c.primitives[primitive]:
				HullPrimitive(points, radius):
					core = points.map(place.applyPoint(it))
					hull = physics.hullOf(core)
					if not hull.isEmpty:
						piece = physics.Piece(
							positions = core,
							indices = hull,
							shell = radius * scale
						)
				p: piece.round = p.roundOf(place)
			primitive += 1
		if c.kinds[k] == "mesh": piece.indices = physics.hullOf(piece.positions)
		out.push(piece)
	out

fn shapeOf(c nif.Collider):
	"compound" if c.kinds.len > 1 else c.kinds[0].copy()

# A model's colliders placed in the world: a dynamic body of each piece of clutter, the scene's
# triangles of what does not move, nothing of the rest (triggers, actor zones); then the joints of
# its constraints (hanging.zap), whose bodies that do not move (a hook) stand as the world and
# collide with nothing, as Havok's filter keeps a constrained system's bodies apart. Clutter
# `held` (a weapon on a rack, whose script keyframes it) is kept where it is: scripts are not
# simulated.
pub fn addModel(mut cw CellWorld, colliders nif.Collider[], editorId str, place Mat4, held bool):
	linked = colliders.flatMap(.constraints.flatMap([.entityA, .entityB]))
	bodies {i64: i64} = {}
	for c in colliders:
		if c.motion != .Dynamic and c.block in linked: continue
		if cw.addCollider(c, editorId, place, held) is i: bodies[c.block] = i
	cw.addConstraints(colliders, bodies, editorId, place)

# the collider's dynamic body, none when it is the scene's or nothing
fn addCollider(mut cw CellWorld, c nif.Collider, editorId str, place Mat4, held bool) i64?:
	if c.motion == .Dynamic and c.layer in dynamicLayers and not held:
		i = cw.world.addBody(editorId, c.piecesOf(place), c.mass, c.friction, c.restitution)
		cw.world.bodies[i].linearDamping = c.body.linearDamping
		cw.world.bodies[i].angularDamping = c.body.angularDamping
		cw.world.bodies[i].maxSpeed = c.body.maxLinearVelocity * nif.havokScale
		cw.world.bodies[i].maxTurn = c.body.maxAngularVelocity
		cw.world.bodies[i].slow = slowingOf(c.body.solverDeactivation)
		cw.world.bodies[i].layer = c.layer
		cw.placed.push(
			Placed(
				body = i,
				editorId = editorId.copy(),
				shape = c.shapeOf(),
				at = cw.world.bodies[i].position,
				material = c.materials.first ?? 0
			)
		)
		return i
	if c.layer in sceneLayers:
		cw.world.addSurface(
			c.positions.map(place.applyPoint(it)),
			c.indices,
			c.friction,
			c.restitution,
			c.materials
		)
		cw.staticShapes += 1
	none

# The world of the cell's enabled refs. `models` keeps each model's colliders, read once.
pub fn cellWorld(
	install skyrim.Install,
	mut plugin esm.Esm,
	cell esm.Cell,
	mut models {str: nif.Collider[]}
) CellWorld:
	cw = CellWorld(world = havokWorld())
	racks = []
	for r in cell.refs:
		if (plugin.baseRecord(r.base) ?? continue).editorId.startsWith(rackPrefix):
			racks.push(r.position)
	for r in cell.refs:
		if r.disabled: continue
		b = plugin.baseRecord(r.base) ?? continue
		if floorPieces.any(b.editorId.startsWith(it)) and r.position.z not in cw.floors:
			cw.floors.push(r.position.z)
		if b.model.isEmpty: continue
		key = install.loadColliders(b.model, models)
		held = b.kind == "WEAP" and racks.isOnRack(r.position)
		first = cw.world.scene.triangleCount()
		cw.addModel(models.get(key) ?? [], b.editorId, r.placement(), held)
		if b.kind == "DOOR" and not r.teleports: cw.world.scene.groupFrom(r.formId, first)
	cw.floors = cw.floors.sortedBy(-it)
	cw

# the archive key of a base record's model, its colliders read into `models` the first time (none
# when it cannot be read)
pub fn loadColliders(install skyrim.Install, model str, mut models {str: nif.Collider[]}) str:
	key = skyrim.modelKey(model)
	if key not in models:
		models[key.copy()] = match install.readModel(key):
			n: n.collisionShapes()
			error: []
	key

# the floor under a point placed at height z: the highest floor piece at or below it
pub fn floorUnder(cw CellWorld, z f32) f32:
	cw.floors.find(it <= z + 1.0) ?? (cw.floors.last ?? 0.0)

# how far a placed body is from where it was placed
pub fn displacement(cw CellWorld, p Placed) f32:
	(cw.world.bodies[p.body].position - p.at).length()

# whether a placed body has gone wholly below the floor under where it was placed
pub fn isBelowFloor(cw CellWorld, p Placed) bool:
	cw.world.bodies[p.body].hi.z < cw.floorUnder(p.at.z)

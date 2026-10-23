# Which objects touch each other this frame (object_collision.c): cylinders, each an object's
# hitbox (its radius, its height, raised or lowered by its down offset), tested Mario against the
# objects of the lists he meets, in the game's order. Each object keeps the first four it met and
# the kinds of interaction they offer. The tests between other objects (destructive and pushable
# ones) are not ported: no ported code reads them, and they come after Mario's.

# detect_object_collisions: last frame's meetings cleared, then Mario's tested
pub fn detectObjectCollisions(mut objs Objects):
	objs.clearObjectCollision()
	objs.checkPlayerObjectCollision()

# clear_object_collision: none met yet, and a frame off each intangibility
fn clearObjectCollision(mut objs Objects):
	for i in 0..objs.all.len:
		objs.all[i].numCollidedObjs = 0
		objs.all[i].collidedObjInteractTypes = 0
		if objs.all[i].intangibleTimer > 0:
			objs.all[i].intangibleTimer -= 1

# check_player_object_collision: Mario against the pole-like objects, then the level's, the
# general actors, the pushable, the surface and the destructive ones
fn checkPlayerObjectCollision(mut objs Objects):
	objs.checkCollisionInList(objListPolelike)
	objs.checkCollisionInList(objListLevel)
	objs.checkCollisionInList(objListGenactor)
	objs.checkCollisionInList(objListPushable)
	objs.checkCollisionInList(objListSurface)
	objs.checkCollisionInList(objListDestructive)

# check_collision_in_list: Mario against each tangible object of a list, its hurtbox tested too
# where it has one
fn checkCollisionInList(mut objs Objects, list i64):
	if objs.all[0].intangibleTimer != 0: return
	for b in 1..objs.all.len:
		if objs.all[b].list != list or objs.all[b].intangibleTimer != 0: continue
		if objs.detectObjectHitboxOverlap(0, b) and objs.all[b].hurtboxRadius != 0.0:
			objs.detectObjectHurtboxOverlap(0, b)

# detect_object_hitbox_overlap: whether the two hitboxes meet, noted on both (four at most each).
# (When they are too far apart the game returns nothing; that only decides whether the hurtbox is
# tested, which changes nothing then, so it is taken as false.)
fn detectObjectHitboxOverlap(mut objs Objects, a i64, b i64):
	oa = mut ref objs.all[a]
	ob = mut ref objs.all[b]
	aBottom = oa.pos.y - oa.hitboxDownOffset
	bBottom = ob.pos.y - ob.hitboxDownOffset
	dx = oa.pos.x - ob.pos.x
	dz = oa.pos.z - ob.pos.z
	collisionRadius = oa.hitboxRadius + ob.hitboxRadius
	distance = (dx * dx + dz * dz).sqrt()
	if not (collisionRadius > distance): return false
	aTop = oa.hitboxHeight + aBottom
	bTop = ob.hitboxHeight + bBottom
	if aBottom > bTop or aTop < bBottom: return false
	if oa.numCollidedObjs >= 4 or ob.numCollidedObjs >= 4: return false
	objs.addCollided(a, b)
	objs.addCollided(b, a)
	oa.collidedObjInteractTypes |= ob.interactType
	ob.collidedObjInteractTypes |= oa.interactType
	true

# detect_object_hurtbox_overlap: Mario's hitbox against the object's hurtbox; while they do not
# meet, its invincibility from him is delayed
fn detectObjectHurtboxOverlap(mut objs Objects, a i64, b i64):
	oa = mut ref objs.all[a]
	ob = mut ref objs.all[b]
	aBottom = oa.pos.y - oa.hitboxDownOffset
	bBottom = ob.pos.y - ob.hitboxDownOffset
	dx = oa.pos.x - ob.pos.x
	dz = oa.pos.z - ob.pos.z
	radius = oa.hurtboxRadius + ob.hurtboxRadius
	distance = (dx * dx + dz * dz).sqrt()
	if a == 0:
		ob.interactionSubtype |= intSubtypeDelayInvincibility
	if radius > distance:
		aTop = oa.hitboxHeight + aBottom
		bTop = ob.hurtboxHeight + bBottom
		if aBottom > bTop or aTop < bBottom: return
		if a == 0:
			ob.interactionSubtype &= ~intSubtypeDelayInvincibility

# the object `other` noted among those `o` met
fn addCollided(mut objs Objects, o i64, other i64):
	n = objs.all[o].numCollidedObjs
	if n == 0:
		objs.all[o].collided0 = other
	elif n == 1:
		objs.all[o].collided1 = other
	elif n == 2:
		objs.all[o].collided2 = other
	else:
		objs.all[o].collided3 = other
	objs.all[o].numCollidedObjs = n + 1

# the i-th object `o` met
pub fn collidedObject(o Object, i i64) i64:
	if i == 0: return o.collided0
	if i == 1: return o.collided1
	if i == 2: return o.collided2
	o.collided3

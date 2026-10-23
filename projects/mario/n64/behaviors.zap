# Behavior scripts (segment 0x13): what an object does, a list of commands of one to five
# words. What an object is set up as is read here, from its first command to its main loop:
# whether it faces the camera, whether it starts hidden, which animation it plays, and whether
# it hides when Mario is far. behavior_script.c: an object that measures its distance to Mario,
# is not active from afar and has no collision of its own is drawn only within its drawing
# distance of him, 4000 unless it says otherwise. surface_load.c: one with collision of its own
# is drawn only within that distance too, stretched to its collision distance when that is more.
# What it collides with Mario as (object_collision.c) is read too: its object list, its hitbox
# and hurtbox, how Mario interacts with it and whether it is tangible (spawn_object.c's defaults
# where the script sets nothing: a hitbox of 50 x 100, intangible).

# an object a behavior spawns where it is: its model and its behavior
pub type Spawn:
	model i64
	behavior i64

pub type Behavior:
	address i64   # its script's segmented address
	facesCamera bool
	hidden bool
	animations i64   # a segmented address of its list of animations, -1 none
	animation i64   # the one it plays
	flags i64   # oFlags as it sets them
	drawingDistance f32
	collision bool   # it loads collision data of its own
	collisionDistance f32
	raise f32   # what it adds to its height
	dropsToFloor bool   # it sets itself on the floor below it
	children Spawn[]   # what it spawns where it is
	graphLift f32   # oGraphYOffset: how far over its place it is drawn
	list i64   # the object list it begins in (BEGIN): OBJ_LIST_*
	hitboxRadius f32
	hitboxHeight f32
	hitboxDownOffset f32
	hurtboxRadius f32
	hurtboxHeight f32
	interactType i64   # oInteractType: INTERACT_*
	intangibleTimer i64   # oIntangibleTimer: 0 tangible, -1 never

pub flagComputeDistance = 0x40
flagActiveFromAfar = 0x80
fieldFlags = 0x01
fieldDrawingDistance = 0x45
fieldPosY = 0x07
fieldCollisionDistance = 0x43
fieldGraphYOffset = 0x15
fieldIntangibleTimer = 0x05
fieldInteractType = 0x2A
listDefault = 8

# whether an object of the behavior at (x, y, z) is drawn while Mario is at (mx, my, mz)
pub fn isShownNear(b Behavior, x f32, y f32, z f32, mx f32, my f32, mz f32) bool:
	if b.hidden: return false
	if (b.flags & flagActiveFromAfar) != 0:
		return true   # active from afar: drawn wherever Mario is (a door)
	dx, dy, dz = x - mx, y - my, z - mz
	distance = (dx * dx + dy * dy + dz * dz).sqrt()
	if b.collision:
		return distance <
			b.drawingDistance.max(b.collisionDistance if b.collisionDistance > 4000.0 else 0.0)
	if (b.flags & flagComputeDistance) == 0 or (b.flags & flagActiveFromAfar) != 0: return true
	distance <= b.drawingDistance

# whether an object of the behavior may be hidden while the level runs (by distance)
pub fn hidesFar(b Behavior) bool:
	(b.flags & flagActiveFromAfar) == 0 and (b.collision or (b.flags & flagComputeDistance) != 0)

# the words each command takes, by opcode (behavior_data.c's macros)
commandWords = [
	1,
	1,
	2,
	1,
	2,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	2,
	1,
	1,
	1,
	1,
	1,
	1,
	2,
	2,
	2,
	2,
	2,
	1,
	1,
	1,
	1,
	3,
	1,
	1,
	1,
	1,
	1,
	1,
	2,
	1,
	1,
	1,
	2,
	1,
	3,
	2,
	3,
	3,
	1,
	2,
	2,
	5, 2, 1, 2, 1, 1, 2, 2, 1]

# what the behavior at `at` sets its object up as, before its loop
pub fn readBehavior(s Segments, at0 i64) Behavior:
	b = Behavior(
		address = at0,
		graphLift = 0.0,
		facesCamera = false,
		hidden = false,
		animations = -1,
		animation = 0,
		flags = 0,
		drawingDistance = 4000.0,
		collision = false,
		collisionDistance = 1000.0,
		raise = 0.0,
		dropsToFloor = false,
		children = [],
		list = listDefault,
		hitboxRadius = 50.0,
		hitboxHeight = 100.0,
		hitboxDownOffset = 0.0,
		hurtboxRadius = 0.0,
		hurtboxHeight = 0.0, interactType = 0, intangibleTimer = -1)
	if segmentOf(at0) != 0x13: return b
	at = at0
	loop 64:
		if not s.holds(at, 4): return b
		op = s.u8At(at)
		if op >= commandWords.len or op == 0x08 or op == 0x09 or op == 0x0A or op == 0x03 or
			op == 0x1D:
			return b   # its loop, its end, its return: past its setting up
		if op == 0x21 or op == 0x38:
			b.facesCamera = true
		elif op == 0x22 or op == 0x35:
			b.hidden = true
		elif op == 0x27:
			b.animations = s.u32At(at + 4)
		elif op == 0x28:
			b.animation = s.u8At(at + 1)
		elif op == 0x11 and s.u8At(at + 1) == fieldFlags:
			b.flags |= s.u16At(at + 2)
		elif op == 0x10 and s.u8At(at + 1) == fieldFlags:
			b.flags = s.u16At(at + 2)
		elif op == 0x0E and s.u8At(at + 1) == fieldDrawingDistance:
			b.drawingDistance = f32(s.s16At(at + 2))
		elif op == 0x0E and s.u8At(at + 1) == fieldCollisionDistance:
			b.collisionDistance = f32(s.s16At(at + 2))
		elif op == 0x0E and s.u8At(at + 1) == fieldGraphYOffset:
			b.graphLift = f32(s.s16At(at + 2))
		elif op == 0x2A:
			b.collision = true
		elif op == 0x0D and s.u8At(at + 1) == fieldPosY:
			b.raise += f32(s.s16At(at + 2))
		elif op == 0x1E:
			b.dropsToFloor = true
		elif op == 0x1C:
			b.children.push((s.u32At(at + 4), s.u32At(at + 8)))
		elif op == 0x00:
			b.list = s.u8At(at + 1)
		elif op == 0x10 and s.u8At(at + 1) == fieldIntangibleTimer:
			b.intangibleTimer = s.s16At(at + 2)
		elif op == 0x10 and s.u8At(at + 1) == fieldInteractType:
			b.interactType = s.s16At(at + 2) & 0xFFFF_FFFF
		elif op == 0x2F:
			b.interactType = s.u32At(at + 4)
		elif op == 0x23 or op == 0x2B:
			b.hitboxRadius = f32(s.s16At(at + 4))
			b.hitboxHeight = f32(s.s16At(at + 6))
			if op == 0x2B:
				b.hitboxDownOffset = f32(s.s16At(at + 8))
		elif op == 0x2E:
			b.hurtboxRadius = f32(s.s16At(at + 4))
			b.hurtboxHeight = f32(s.s16At(at + 6))
		elif op == 0x04:
			at = s.u32At(at + 4)   # GOTO: on from there
			continue
		at += commandWords[op] * 4
	b

# What the objects' own code (their behaviors' native routines) does: what it sets up when they
# first run, in the order they were placed (the animation they rest in, the frame it starts at,
# how near Mario must be for them to show), and, while the level runs, the little of it that
# moves Mario (the poles and trees pushing him off their trunk). Behaviors are known by their
# script's address in the US cartridge. Each object of the level is kept with what it collides
# with Mario as (collisions.zap); Mario's own object is the first.

import n64

pub bhvTree = 0x1300_2AA4
pub bhvButterfly = 0x1300_33BC
pub bhvCastleFlagWaving = 0x1300_3C58

# the object lists (object_list_processor.h)
pub objListPlayer = 0
pub objListDestructive = 2
pub objListGenactor = 4
pub objListPushable = 5
pub objListLevel = 6
pub objListSurface = 9
pub objListPolelike = 10

# an object's start: its animation (-1 the script's), its first frame (-1 the animation's own),
# the distance from Mario it shows within (-1 as its script says)
pub type ObjectStart:
	animation i64
	frame i64
	shownWithin f32

pub fn startObject(b n64.Behavior, mut r Random) ObjectStart:
	if b.address == bhvButterfly:
		# bhv_butterfly_init: resting, a random height phase and frame; set_object_visibility(3000)
		r.randomFloat()
		frame = i64(r.randomFloat() * 7.0)
		return ObjectStart(animation = 1, frame, shownWithin = 3000.0)
	if b.address == bhvCastleFlagWaving:
		# bhv_castle_flag_init: a random frame of its waving
		return ObjectStart(
			animation = -1,
			frame = i64(r.randomFloat() * 28.0),
			shownWithin = -1.0
		)
	ObjectStart(animation = -1, frame = -1, shownWithin = -1.0)

# an object as the level runs it: where it is and the collision fields of its struct Object
pub type Object:
	behavior i64   # its script's address
	list i64   # OBJ_LIST_*
	pos Vec3
	hitboxRadius f32
	hitboxHeight f32
	hitboxDownOffset f32
	hurtboxRadius f32
	hurtboxHeight f32
	interactType i64
	interactStatus i64
	interactionSubtype i64
	intangibleTimer i64
	timer i64   # oTimer: the frames it has run
	numCollidedObjs i64
	collided0 i64   # collidedObjs: indices of the objects it met this frame
	collided1 i64
	collided2 i64
	collided3 i64
	collidedObjInteractTypes i64

pub type Objects:
	all Table<Object>   # Mario's first

# the level's objects: Mario's own (bhvMario: OBJ_LIST_PLAYER, SET_HITBOX(37, 160), tangible)
# where he stands, then those the level places
pub fn newGameObjects(m Mario, placed Object[]) Objects:
	objs = Objects(all = [Object(
		behavior = 0,
		list = objListPlayer,
		pos = m.pos,
		hitboxRadius = 37.0,
		hitboxHeight = 160.0,
		hitboxDownOffset = 0.0,
		hurtboxRadius = 0.0,
		hurtboxHeight = 0.0,
		interactType = 0,
		interactStatus = 0,
		interactionSubtype = 0,
		intangibleTimer = 0,
		timer = 0,
		numCollidedObjs = 0, collided0 = -1, collided1 = -1, collided2 = -1, collided3 = -1, collidedObjInteractTypes = 0)])
	for o in placed:
		objs.all.push(o)
	objs

# an object the level places, as its script sets it up, if it is one Mario can meet (in a list
# checked against his)
pub fn gameObjectOf(b n64.Behavior, at Vec3) Object?:
	l = b.list
	if l != objListPolelike and l != objListLevel and l != objListGenactor and
		l != objListPushable and l != objListSurface and l != objListDestructive:
		return none
	Object(
		behavior = b.address,
		list = l,
		pos = at,
		hitboxRadius = b.hitboxRadius,
		hitboxHeight = b.hitboxHeight,
		hitboxDownOffset = b.hitboxDownOffset,
		hurtboxRadius = b.hurtboxRadius,
		hurtboxHeight = b.hurtboxHeight,
		interactType = b.interactType,
		interactStatus = 0,
		interactionSubtype = 0,
		intangibleTimer = b.intangibleTimer,
		timer = 0,
		numCollidedObjs = 0,
		collided0 = -1,
		collided1 = -1,
		collided2 = -1, collided3 = -1, collidedObjInteractTypes = 0)

# update_objects up to Mario: which objects meet (detect_object_collisions), then the pole-like
# objects' code, which runs before his (sObjectListUpdateOrder). Of the other objects' code only
# their timers run.
pub fn updateObjects(mut objs Objects, mut m Mario):
	objs.detectObjectCollisions()
	for i in 1..objs.all.len:
		if objs.all[i].behavior == bhvTree:
			objs.bhvPoleBaseLoop(i, m)
		objs.all[i].timer += 1

# bhv_pole_base_loop: Mario within its height is pushed out to 70 units from its trunk (from its
# eleventh frame; @bug the test of his punching reads his action, where the flag is ACT_FLAG_ON_POLE)
fn bhvPoleBaseLoop(mut objs Objects, i i64, mut m Mario):
	o = mut ref objs.all[i]
	mario = mut ref objs.all[0]
	if o.pos.y - 10.0 < mario.pos.y and mario.pos.y < o.pos.y + o.hitboxHeight + 30.0:
		if o.timer > 10:
			if (m.action & marioPunching) == 0:
				o.curObjPushMarioAway(mario, m, 70.0)

# cur_obj_push_mario_away: Mario (his object's place, last frame's) pushed out to `radius`
fn curObjPushMarioAway(o Object, mario Object, mut m Mario, radius f32):
	marioRelX = mario.pos.x - o.pos.x
	marioRelZ = mario.pos.z - o.pos.z
	marioDist = (marioRelX * marioRelX + marioRelZ * marioRelZ).sqrt()
	if marioDist < radius:
		m.pos.x += (radius - marioDist) / radius * marioRelX
		m.pos.z += (radius - marioDist) / radius * marioRelZ

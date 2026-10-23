# A level as the cartridge's scripts describe it. The main scripts (segment 0x15) load the banks
# every level shares, register their models, then pick the level by number; the level's own
# script (segment 0x0E) loads its banks, registers its models and lists each area: its geo layout,
# objects, collision and macro objects, and where Mario starts. Here the scripts are followed
# only to read that: what the game's code would do (calls, loops, the menu) is skipped, and the
# reading stops when the level begins its frames.

pub levelCastleGrounds = 16

# a model of the level's table: a geo layout, or a display list drawn in a layer
pub type ModelDef:
	id i64
	geo i64   # a segmented address, or -1
	dl i64   # a segmented address, or -1
	layer i64

# an object the level places: its model, place, turn (degrees), parameter and behavior
pub type ObjectDef:
	model i64
	x i64
	y i64
	z i64
	rx i64
	ry i64
	rz i64
	param i64
	behavior i64

pub type Level:
	segments Segments
	areaGeo i64   # the first area's geo layout
	models ModelDef[]
	objects ObjectDef[]
	terrain i64   # the collision data, -1 none
	macros i64   # the macro object list, -1 none
	marioX i64
	marioY i64
	marioZ i64
	marioYaw i64   # degrees

# segment 2 in the US cartridge
segment2Start = 0x10_8A40
segment2End = 0x11_4750

# where the menu's script hands over to the main scripts: the bytes of segment 0x15
menuHandover = 0x2A_622C

# the level of that number, read from the cartridge's scripts
pub fn readLevel(rom Rom, number i64) Level:
	lv = Level(
		segments = newSegments(),
		areaGeo = -1,
		models = [],
		objects = [],
		terrain = -1,
		macros = -1,
		marioX = 0,
		marioY = 0,
		marioZ = 0,
		marioYaw = 0)
	start = rom.bytes.u32be(menuHandover)
	end = rom.bytes.u32be(menuHandover + 4)
	lv.segments.loadSegment(rom, 0x15, start, end, false)
	# segment 2 (the water's and the HUD's textures), loaded by the game's code, not a script
	lv.segments.loadSegment(rom, 0x02, segment2Start, segment2End, true)
	lv.runScripts(rom, 0x1500_0000, number)
	if lv.areaGeo < 0:
		fail("level {number}: its scripts give no area")
	lv

fn runScripts(mut lv Level, rom Rom, entry i64, number i64):
	at = entry
	returns = []
	reg = 0
	inLevel = false   # inside the level's own script (segment 0x0E)
	loop 100_000:
		s = lv.segments
		op = s.u8At(at)
		len = s.u8At(at + 1)
		if len == 0:
			fail("level script: a command of length 0 at {at}")
		next = at + len
		if op == 0x00 or op == 0x01:
			# EXECUTE / EXIT_AND_EXECUTE: a bank of scripts loaded and run (the menu's skipped)
			seg = s.u16At(at + 2)
			if seg == 0x14:
				at = next
				continue
			romStart = s.u32At(at + 4)
			romEnd = s.u32At(at + 8)
			target = s.u32At(at + 12)
			lv.segments.loadSegment(rom, seg, romStart, romEnd, false)
			if op == 0x00:
				returns.push(next)
			inLevel = inLevel or seg == 0x0E
			at = target
		elif op == 0x02 or op == 0x07:
			# EXIT / RETURN: back to the caller; the level's exit ends the reading
			if inLevel and op == 0x02 or returns.isEmpty: return
			at = returns.pop() ?? return
		elif op == 0x05:
			at = s.u32At(at + 4)
		elif op == 0x06:
			returns.push(next)
			at = s.u32At(at + 4)
		elif op == 0x0C or op == 0x0D:
			if holdsCondition(s.u8At(at + 2), reg, s.s32At(at + 4)):
				if op == 0x0D:
					returns.push(next)
				at = s.u32At(at + 8)
			else:
				at = next
		elif op == 0x12 and inLevel and lv.areaGeo >= 0:
			return   # CALL_LOOP: the level's frames begin
		elif op == 0x13:
			reg = s.u16At(at + 2)
			at = next
		elif op == 0x3C:
			if s.u8At(at + 2) == 1 and s.u8At(at + 3) == 3:
				reg = number   # GET_OR_SET(get, the current level)
			at = next
		elif op in [0x17, 0x18, 0x1A]:
			loadSegment(
				lv.segments,
				rom,
				s.u16At(at + 2),
				s.u32At(at + 4),
				s.u32At(at + 8),
				op != 0x17
			)
			at = next
		else:
			lv.noteCommand(op, at)
			at = next
	fail("level script: no end after 100000 commands")

# what the commands that only describe the level say
fn noteCommand(mut lv Level, op i64, at i64):
	s = lv.segments
	if op == 0x1F and lv.areaGeo < 0:
		lv.areaGeo = s.u32At(at + 4)
	elif op == 0x21:
		v = s.u16At(at + 2)
		lv.models.push(ModelDef(id = v & 0xFFF, geo = -1, dl = s.u32At(at + 4), layer = v >> 12))
	elif op == 0x22:
		lv.models.push(ModelDef(id = s.u16At(at + 2), geo = s.u32At(at + 4), dl = -1, layer = 0))
	elif op == 0x24:
		lv.objects.push(ObjectDef(
			model = s.u8At(at + 3),
			x = s.s16At(at + 4),
			y = s.s16At(at + 6),
			z = s.s16At(at + 8),
			rx = s.s16At(at + 10),
			ry = s.s16At(at + 12), rz = s.s16At(at + 14), param = s.u32At(at + 16), behavior = u32At(
				s,
				at + 20
		)))
	elif op == 0x2B:
		lv.marioYaw = s.s16At(at + 4)
		lv.marioX = s.s16At(at + 6)
		lv.marioY = s.s16At(at + 8)
		lv.marioZ = s.s16At(at + 10)
	elif op == 0x2E and lv.terrain < 0:
		lv.terrain = s.u32At(at + 4)
	elif op == 0x39 and lv.macros < 0:
		lv.macros = s.u32At(at + 4)

# a script's condition on its register: AND, NAND, EQ, NEQ, LT, LEQ, GT, GEQ
fn holdsCondition(op i64, reg i64, arg i64):
	match op:
		0: (reg & arg) != 0
		1: (reg & arg) == 0
		2: reg == arg
		3: reg != arg
		4: reg < arg
		5: reg <= arg
		6: reg > arg
		7: reg >= arg
		_: false

# the model the level registered under id (the latest), or none
pub fn modelNamed(lv Level, id i64) ModelDef?:
	found ModelDef? = none
	for m in lv.models:
		if m.id == id:
			found = m
	found

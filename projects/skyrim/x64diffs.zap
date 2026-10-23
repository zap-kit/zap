# The ports of SkyrimSE.exe's pure math checked against the executable itself: each function run in
# the emulator (recomp/x64) on a few thousand seeded inputs and its result compared, bit for bit,
# with the port's. The executable is read where it lies (1.7.104); without it the tests pass quietly.

import fs
import recomp.x64
import engine.physics
import skyrim.esm
import world
import game.sim
import game.stealth

exePath = "C:/tools/skyrim-input/SkyrimSE.exe"
inputs = 4000

# a machine over the executable, none without it
fn machine() x64.Machine?:
	if not fs.exists(exePath): return none
	x64.machineFor(x64.openImage(exePath) ?? fail)

# the scratch memory's page at this index
fn scratch(page u64):
	x64.scratchBase + page * 0x1000

# a float drawn for the tests: mostly ordinary values of any sign and size, now and then a zero,
# a value on a boundary or two that compare equal
fn drawFloat(mut rng Random):
	match rng.nextInt(0, 10):
		0: f32(0.0) if rng.nextInt(0, 2) == 0 else f32(-0.0)
		1: f32(rng.nextFloat(-1.0, 1.0)) * 1e-6
		2: f32(rng.nextFloat(-1e6, 1e6))
		_: f32(rng.nextFloat(-10.0, 10.0))

# hkMath::atan2fApproximation (0x140aabb90) against engine/physics's angleOf
test "Havok's atan2 approximation is the executable's":
	m = machine() ?? return
	rng = Random(7)
	differ = 0
	for k in 0..inputs:
		y = rng.drawFloat()
		x = rng.drawFloat()
		if k % 7 == 0: x = y if k % 2 == 0 else -y
		_ = m.call(0x1_40aa_bb90, [.Single(y), .Single(x)]) ?? fail
		got = m.resultSingle()
		mine = physics.angleOf(y, x)
		if got.toBits() != mine.toBits():
			if differ < 5: print("angleOf({y}, {x}): exe {got}, port {mine}")
			differ += 1
	expect differ == 0

# the executable's sine and cosine tables (0x14331c6f0, 0x14331cef0) filled as the game starts,
# the sines read back
fn withTables(mut m x64.Machine):
	_ = m.call(0x1_40ef_2ca0, []) ?? fail
	(0..512).map(f32.fromBits(u32.wrap(m.mem.read(0x1_4331_c6f0 + u64(4 * it), 4))))

# The table's angles are the game's (single additions of a turn / 512); their sines come from the
# executable's own vector sincos (0x1415a8050), not correctly rounded: the port's, rounded from
# double precision, is within one unit in the last place of each.
test "the flicker's sine table is the executable's within an ulp":
	m = machine() ?? return
	table = m.withTables()
	off = 0
	for k in 0..512:
		gap = (i64(table[k].toBits()) - i64(world.sineTable[k].toBits())).abs()
		expect gap <= 1
		if gap == 1: off += 1
	print("{off} of 512 entries an ulp apart")
	prints "140 of 512 entries an ulp apart"

# The flicker's core (0x140274be0 with no dimmer given): the record (+0xec flags, 8 the flicker;
# +0xfc period, +0x100 amplitude, +0x104 movement, +0x108 fade) and the light (+0x140.. the
# phases; +0x134 the dimmer and +0x6c.. the offset it writes) in scratch memory. The frame time is
# 0 in the image, so the phases stay those given; the random draw, the light's update and the
# check before it are stubs. The port reads the executable's sine table here (see above).
test "the flicker's dimmer and offset are the executable's":
	m = machine() ?? return
	world.sineTable = m.withTables()
	m.stubs[0x1_401d_6e40] = .Returns(0, 0)
	m.stubs[0x1_406e_49e0] = .Returns(1, 0)
	m.stubs[0x1_4066_7c60] = .Returns(0, 0)
	record = x64.scratchBase
	light = x64.scratchBase + 0x1000
	cell = x64.scratchBase + 0x2000
	m.mem.write(cell, 8, light)
	m.mem.write(record + 0xEC, 4, 8)
	rng = Random(11)
	differ = 0
	turn = 2.0 * pi
	for k in 0..inputs:
		x = f32(rng.nextFloat(0.0, turn))
		y = f32(rng.nextFloat(0.0, turn))
		z = f32(rng.nextFloat(0.0, turn))
		amplitude = f32(rng.nextFloat(0.0, 1.0))
		movement = f32(rng.nextFloat(0.0, 20.0)) if k % 3 != 0 else 0.0
		fade = f32(rng.nextFloat(0.0, 3.0)) if k % 2 == 0 else 1.0
		for (at, v) in [
			(record + 0xFC, f32(1.0)),
			(record + 0x100, amplitude),
			(record + 0x104, movement),
			(record + 0x108, fade), (light + 0x140, x), (light + 0x144, y), (light + 0x148, z)]:
			m.mem.write(at, 4, v.toBits())
		_ = m.call(0x1_4027_4be0, [.Int(record), .Int(cell), .Int(0), .Single(-1.0)]) ?? fail
		got = [0x134, 0x6C, 0x70, 0x74].map(m.mem.read(light + u64(it), 4))
		dimmer, ox, oy, oz = world.flickerAt(x, y, z, amplitude, movement, fade)
		mine = [dimmer, ox, oy, oz].map(u64(.toBits()))
		if got != mine:
			if differ < 5:
				print("flicker({x}, {y}, {z}, {amplitude}, {movement}, {fade}): exe {got}, port {mine}")
			differ += 1
	expect differ == 0

# addresses no code is at, for the stubs a fake object's table of methods points to
fakeMethods u64 = 0x50_0000_0000

# a single float's bits as a register holds them
fn bitsOf(x f32) u64:
	x.toBits()

# PlayerSkills::AddSkillExperience (0x14078dcb0) on PlayerSkills data in scratch memory: the
# player (0x143230778) a fake whose actor values (+0xb8, methods +0x18 the value, +0x28 the base's
# change) are stubs, the AVSK reader (0x1404454e0) answered with the case's, the perk entry point
# and the SkillIncrease event stubs, quiet. The port's gainExperience from the same state.
test "the skill-use experience is the executable's":
	m = machine() ?? return
	data = x64.scratchBase
	cell = x64.scratchBase + 0x1000
	player = x64.scratchBase + 0x2000
	methods = x64.scratchBase + 0x4000
	m.mem.write(cell, 8, data)
	m.mem.write(0x1_4323_0778, 8, player)
	m.mem.write(player + 0xB8, 8, methods)
	m.mem.write(methods + 0x18, 8, fakeMethods)
	m.mem.write(methods + 0x28, 8, fakeMethods + 0x10)
	m.stubs[fakeMethods + 0x10] = .Returns(0, 0)
	for at in [0x1_4038_cff0, 0x1_4053_0970, 0x1_4053_39b0, 0x1_4073_af50]:
		m.stubs[u64(at)] = .Returns(0, 0)
	m.stubs[0x1_4044_54e0] = .Pause
	risen = 0
	rng = Random(5)
	differ = 0
	for k in 0..inputs:
		curve = f32(1.95) if k % 4 != 0 else f32(rng.nextFloat(1.0, 3.0))
		perRank = f32(1.0) if k % 5 != 0 else f32(rng.nextFloat(0.1, 4.0))
		use = sim.SkillUse(
			useMult = f32(rng.nextFloat(0.1, 4.0)),
			useOffset = f32(rng.nextFloat(0.0, 3.0)),
			improveMult = f32(rng.nextFloat(0.2, 4.0)),
			improveOffset = f32(rng.nextFloat(0.0, 300.0)),
			displayName = ""
		)
		level = f32(rng.nextInt(0, 100))
		threshold = use.thresholdOf(level, curve)
		start = sim.SkillState(level, skillXp = threshold * f32(rng.nextFloat(0.0, 1.0)), threshold,
			xp = f32(rng.nextFloat(0.0, 1000.0)))
		points = f32(rng.nextFloat(0.0, 3000.0)) if k % 3 != 0 else f32(rng.nextFloat(0.0, 30.0))
		scaled = k % 2 == 0
		skill = 6 + k % 18
		slot = data + u64(12 * (skill - 6))
		m.mem.write(0x1_420a_8ca8, 4, bitsOf(curve))
		m.mem.write(0x1_420a_8cf0, 4, bitsOf(perRank))
		m.mem.write(data, 4, bitsOf(start.xp))
		m.mem.write(slot + 0xC, 4, bitsOf(start.skillXp))
		m.mem.write(slot + 0x10, 4, bitsOf(threshold))
		m.stubs[fakeMethods] = .Returns(0, bitsOf(level))
		args x64.Arg[] = [
			.Int(cell),
			.Int(skill),
			.Single(points),
			.Int(0),
			.Int(0),
			.Int(1 if scaled else 0),
			.Int(1)
		]
		stop = m.call(0x1_4078_dcb0, args) ?? fail
		while stop is Paused:
			for (at, v) in [
				(m.regs[2], use.useMult),
				(m.regs[8], use.useOffset),
				(m.regs[9], use.improveMult),
				(m.mem.read(m.regs[4] + 0x28, 8), use.improveOffset)]:
				m.mem.write(at, 4, bitsOf(v))
			m.answer(1, 0)
			stop = m.run() ?? fail
		got = [m.mem.read(data, 4), m.mem.read(slot + 0xC, 4), m.mem.read(slot + 0x10, 4)]
		amount = use.useMult * points + use.useOffset if scaled else points
		after, rose = start.gainExperience(amount, use, curve, perRank)
		if rose: risen += 1
		mine = [bitsOf(after.xp), bitsOf(after.skillXp), bitsOf(after.threshold)]
		if got != mine:
			if differ < 5:
				print("skill {skill} level {level} points {points}: exe {got}, port {mine}")
			differ += 1
	expect risen > inputs / 4
	expect differ == 0

# The perk entry points' functions of a number (the DAT_14209a080 table): set, add, multiply, add
# actor value mult, absolute, negative absolute, set to, multiply by and multiply by 1 + actor value
# mult, each with its kind
perkFunctions = [
	(1, 0x1_4038_d2c0),
	(2, 0x1_4038_d330),
	(3, 0x1_4038_d3a0),
	(5, 0x1_4038_d550),
	(6, 0x1_4038_d8e0),
	(7, 0x1_4038_d950),
	(12, 0x1_4038_d630),
	(13, 0x1_4038_d710),
	(14, 0x1_4038_d7f0)
]

# Each function on a value in scratch memory: the entry's data a fake (its type from the method
# at +8, its two values at +8 and +0xc), the owner a fake actor (form type 0x3e at +0x1a, or not
# one) whose actor value (+0xb8, method +8) is a stub. The port's entryFunctionValue on the same.
test "the perk entry functions are the executable's":
	m = machine() ?? return
	value = x64.scratchBase
	results = x64.scratchBase + 0x100
	entry = x64.scratchBase + 0x200
	owner = x64.scratchBase + 0x1000
	entryMethods = x64.scratchBase + 0x3000
	ownerMethods = x64.scratchBase + 0x3100
	m.mem.write(results, 8, value)
	m.mem.write(entry, 8, entryMethods)
	m.mem.write(entryMethods + 8, 8, fakeMethods)
	m.mem.write(owner + 0xB8, 8, ownerMethods)
	m.mem.write(ownerMethods + 8, 8, fakeMethods + 0x10)
	count = m.mem.read(0x1_4209_a1f0, 1)
	rng = Random(3)
	differ = 0
	for k in 0..inputs:
		kind, address = perkFunctions[k % len]
		dataType = [1, 2, 0][rng.nextInt(0, 3)] if k % 4 == 0
			else (2 if kind >= 5 and kind != 6 and kind != 7 else 1 if kind < 5 else 0)
		values = [f32(rng.nextInt(0, 160)) if kind >= 5 else rng.drawFloat(), rng.drawFloat()]
		before = rng.drawFloat()
		owned = rng.drawFloat()
		isActor = k % 9 != 0
		m.mem.write(value, 4, bitsOf(before))
		m.mem.write(entry + 8, 4, bitsOf(values[0]))
		m.mem.write(entry + 0xC, 4, bitsOf(values[1]))
		m.mem.write(owner + 0x1A, 1, 0x3E if isActor else 0x2B)
		m.stubs[fakeMethods] = .Returns(u64(dataType), 0)
		m.stubs[fakeMethods + 0x10] = .Returns(0, bitsOf(owned))
		_ = m.call(u64(address), [.Int(owner), .Int(0), .Int(count), .Int(results), .Int(entry)]) ??
			fail
		got = m.mem.read(value, 4)
		mine = bitsOf(
			sim.entryFunctionValue(kind, dataType, values, owned if isActor else none, before)
		)
		if got != mine:
			if differ < 5: print("kind {kind} type {dataType} values {values} owned {owned} of {before}: exe {got:x}, port {mine:x}")
			differ += 1
	expect differ == 0

# the settings the detection sum reads, where the executable keeps their values (each SettingT's
# value at +8 of the object, its name's address after it)
sneakSettings u64[] = [
	0x1_4209_eb58,
	0x1_4209_ed50,
	0x1_4209_faa0,
	0x1_4209_ed38,
	0x1_4209_ed80,
	0x1_4209_ed68,
	0x1_4209_eb70,
	0x1_4209_ed98,
	0x1_4209_edb0,
	0x1_4209_edc8,
	0x1_4209_ebd0,
	0x1_4209_edf8,
	0x1_4209_ebe8,
	0x1_4209_eca8,
	0x1_4209_eba0,
	0x1_4209_eb88,
	0x1_4209_ec30,
	0x1_4209_ecf0,
	0x1_4209_ecd8,
	0x1_4209_ec00,
	0x1_4209_ec18,
	0x1_4209_ee40,
	0x1_4209_ee58,
	0x1_4209_ee70,
	0x1_4209_ee88,
	0x1_4209_ecc0,
	0x1_4209_ee10,
	0x1_4209_ebb8,
	0x1_4209_fab8, 0x1_4209_fad0, 0x1_420a_1180, 0x1_420a_1168
]

# the setting's name, as the executable's object holds it, lower case as the port's settings
fn settingName(mut m x64.Machine, at u64):
	m.mem.bytes(m.mem.read(at + 8, 8), 64).cStringAt(0, 64).lower()

fn drawBool(mut rng Random):
	rng.nextInt(0, 2) == 1

fn flagArg(b bool) x64.Arg:
	.Int(1 if b else 0)

# The detection sum (0x14041cd90) on drawn watchers, quarries and sights, the settings the
# executable's defaults scaled at random every 50 cases (written to its memory and to the port's):
# the level it returns and the noise, light and skill terms it writes, against game/stealth's
# valueAt. The two actors are fakes (their flags at +0xc8: 0x40000 flies), the player
# (0x1431df300) one of them or neither; the perk entry points are stubs.
test "the detection sum is the executable's":
	m = machine() ?? return
	watcher = x64.scratchBase
	quarry = x64.scratchBase + 0x1000
	outs = x64.scratchBase + 0x2000
	m.stubs[0x1_4038_cff0] = .Returns(0, 0)
	names = sneakSettings.map(m.settingName(it))
	defaults = sneakSettings.map(f32.fromBits(u32.wrap(m.mem.read(it, 4))))
	settings {str: f64} = {
		"fdetectionnighteyebonus": 3.0,
		"ilightlevelexteriormod": 0.0,
		"ilightlevelinteriormod": 25.0,
		"ilightlevelmax": 300.0
	}
	rng = Random(13)
	differ = 0
	powDiffers = 0
	for k in 0..inputs:
		if k % 50 == 0:
			for j in 0..names.len:
				v = defaults[j] if k == 0 else defaults[j] * f32(rng.nextFloat(0.5, 1.5))
				settings[names[j].copy()] = f64(v)
				m.mem.write(sneakSettings[j], 4, bitsOf(v))
		w = stealth.Watcher(sneakSkill = f32(rng.nextFloat(0.0, 100.0)), isPlayer = k % 5 == 1,
			blindness = f32(rng.nextFloat(0.0, 100.0)) if k % 4 == 0 else 0.0,
			nightEye = k % 7 == 0,
			alerted = rng.drawBool(), fightsOther = rng.drawBool(), sleeping = k % 6 == 0,
			flying = k % 11 == 0, ambush = rng.nextInt(0, 3))
		q = stealth.Quarry(sneakSkill = f32(rng.nextFloat(0.0, 100.0)), isPlayer = k % 5 == 2,
			sneaking = rng.drawBool(), moving = rng.drawBool(), running = rng.drawBool(),
			invisible = k % 8 == 0,
			size = rng.nextInt(0, 5),
			equippedWeight = f32(rng.nextFloat(0.0, 80.0)),
			movementNoise = f32(rng.nextFloat(-0.5, 2.0)),
			action = [0, 50, 100, 200][rng.nextInt(0, 4)],
			flying = k % 13 == 0)
		s = stealth.Sight(distance = f32(rng.nextFloat(0.0, 4000.0)), exterior = rng.drawBool(),
			lightRaw = f32(rng.nextFloat(0.0, 200.0)), ambientMax = f32(rng.nextFloat(0.0, 1.0)))
		seen = rng.drawBool()
		los = seen or rng.drawBool()
		mine = stealth.valueAt(settings, w, q, s, seen, los)
		m.mem.write(watcher + 0xC8, 4, 0x4_0000 if w.flying else 0)
		m.mem.write(quarry + 0xC8, 4, 0x4_0000 if q.flying else 0)
		m.mem.write(0x1_431d_f300, 8, watcher if w.isPlayer else quarry if q.isPlayer else 0)
		light = stealth.lightLevelOf(settings, s, w.nightEye)
		args x64.Arg[] = [
			.Int(watcher),
			.Int(quarry),
			.Single(w.sneakSkill),
			.Single(q.sneakSkill),
			.Int(u64(q.size)),
			flagArg(los),
			flagArg(seen),
			.Single(s.distance),
			.Int(u64(light)),
			.Int(u64(i64(w.blindness))),
			flagArg(q.invisible), .Single(q.equippedWeight), flagArg(q.moving), flagArg(q.sneaking),
			.Single(q.movementNoise), flagArg(q.running), flagArg(w.sleeping), flagArg(w.alerted),
			.Int(u64(q.action)), flagArg(s.exterior), flagArg(w.fightsOther), .Int(u64(w.ambush)),
			.Int(outs), .Int(outs + 4), .Int(outs + 8)
		]
		_ = m.call(0x1_4041_cd90, args) ?? fail
		got = [i64(i32.wrap(m.resultInt())), i64(m.mem.read(outs, 4)), i64(m.mem.read(outs + 4, 4)),
			i64(m.mem.read(outs + 8, 4))]
		ours = [
			mine.level,
			i64(mine.noise.toBits()),
			i64(mine.light.toBits()),
			i64(mine.skill.toBits())
		]
		if got == ours: continue
		# the attenuation's powf (the import, 0x1415a98ca) is the platform's, the port's pow is
		# rounded from double precision: a case where those two differ is counted apart
		range = stealth.maxDistance(settings, s.exterior, w.flying or q.flying)
		near = ((range - s.distance) / range).max(0.0)
		exponent = settings.gmst("fsneakdistanceattenuationexponent")
		_ = m.call(0x1_415a_98ca, [.Single(near), .Single(exponent)]) ?? fail
		if m.resultSingle().toBits() != near.pow(exponent).toBits():
			powDiffers += 1
			continue
		if differ < 5: print("case {k}: exe {got}, port {ours}")
		differ += 1
	expect differ == 0
	expect powDiffers < inputs / 1000

# Sky::FillColorBlend (0x140416760) on a Sky in scratch memory with its climate's hours as the
# executable keeps them (the sunrise's begin less the extension 0x1431e0da4, its end 0x1431e0d98,
# the sunset's begin 0x1431e0d9c, its end plus the extension 0x1431e0da8), the hour (+0x1b0) and
# the share of the weather (+0x1b8): the times of day it picks and the four weights it fills.
test "the sky's color blend is the executable's":
	m = machine() ?? return
	sky = x64.scratchBase
	out = x64.scratchBase + 0x1000
	weather = x64.scratchBase + 0x2000
	picked = x64.scratchBase + 0x3000
	rng = Random(23)
	differ = 0
	for k in 0..inputs:
		begin = f32(rng.nextFloat(0.0, 8.0))
		sunriseEnd = begin + f32(rng.nextFloat(0.5, 6.0))
		sunsetBegin = sunriseEnd + f32(rng.nextFloat(2.0, 10.0))
		sunsetEnd = (sunsetBegin + f32(rng.nextFloat(0.5, 6.0))).min(23.99)
		hours = Vec4(begin, sunriseEnd, sunsetBegin, sunsetEnd)
		hour = f32(rng.nextFloat(0.0, 24.0))
		if k % 7 == 0: hour = [begin, sunriseEnd, sunsetBegin, sunsetEnd][k % 4]
		share = f32(rng.nextFloat(0.0, 1.0))
		for (at, v) in [
			(u64(0x1_431e_0da4), begin),
			(u64(0x1_431e_0d98), sunriseEnd),
			(u64(0x1_431e_0d9c), sunsetBegin),
			(u64(0x1_431e_0da8), sunsetEnd),
			(sky + 0x1b0, hour),
			(sky + 0x1b8, share)]:
			m.mem.write(at, 4, v.toBits())
		m.mem.write(sky + 0x1dc, 4, 0)
		_ = m.call(
			0x1_4041_6760,
			[.Int(sky), .Int(out), .Int(weather), .Int(0), .Int(picked), .Int(picked + 8)]
		) ??
			fail
		first = m.mem.read(picked, 4)
		second = m.mem.read(picked + 8, 4)
		weights = [0x10, 0x14, 0x18, 0x1c].map(m.mem.read(out + u64(it), 4))
		mine = hours.blendOf(hour, share)
		want = [mine.weights.x, mine.weights.y, mine.weights.z, mine.weights.w].map(u64(.toBits()))
		if first != u64(mine.first) or second != u64(mine.second) or weights != want:
			if differ < 5:
				print("blend({hours}, {hour}, {share}): exe {first} {second} {weights}, port {mine.first} {mine.second} {want}")
			differ += 1
	expect differ == 0

# Sky::SetColor (0x140414cf0): four RGBA bytes colors times their four weights, the lightning's flash
# added and held under the weather's lightning color (the weather at +0x48, its lightning color at
# +0x670), or held under 1 without a flash.
test "the sky's blended color is the executable's":
	m = machine() ?? return
	sky = scratch(0)
	out = scratch(1)
	blend = scratch(2)
	weather = scratch(3)
	m.mem.write(sky + 0x48, 8, weather)
	rng = Random(29)
	differ = 0
	for k in 0..inputs:
		colors = []
		weights = []
		loop 4:
			colors.push(
				esm.Color(r = rng.nextInt(0, 256), g = rng.nextInt(0, 256), b = rng.nextInt(0, 256))
			)
			weights.push(f32(rng.nextFloat(0.0, 1.0)) if k % 5 != 0 else f32(0.0))
		for (j, c) in [(0, colors[0]), (4, colors[1]), (8, colors[2]), (12, colors[3])]:
			m.mem.write(blend + u64(j), 4, u64(c.r | c.g << 8 | c.b << 16 | 255 << 24))
		for j in 0..4:
			m.mem.write(blend + 0x10 + u64(4 * j), 4, weights[j].toBits())
		lightning = esm.Color(
			r = rng.nextInt(0, 256),
			g = rng.nextInt(0, 256),
			b = rng.nextInt(0, 256)
		)
		m.mem.write(weather + 0x670, 4, u64(lightning.r | lightning.g << 8 | lightning.b << 16))
		flash = f32(rng.nextFloat(0.0, 1.5)) if k % 3 == 0 else f32(0.0)
		_ = m.call(0x1_4041_4cf0, [.Int(sky), .Int(out), .Int(blend), .Single(flash)]) ?? fail
		got = [0, 4, 8].map(m.mem.read(out + u64(it), 4))
		w = Vec4(weights[0], weights[1], weights[2], weights[3])
		mine = world.flashed(
			colors[0].weightedBytes(colors[1], colors[2], colors[3], w),
			lightning,
			flash
		)
		want = [mine.x, mine.y, mine.z].map(u64(.toBits()))
		if got != want:
			if differ < 5: print("setColor({colors}, {w}, flash {flash}): exe {got}, port {want}")
			differ += 1
	expect differ == 0

# the sky's ambient cube blend (0x140416490, the cube then its specular tint then its fresnel written
# to the sky at +0x200, +0x248 and +0x254) on weathers whose DALC (+0x7f8, 32 bytes a time of day, the
# fresnel at +0x1c of each) are in scratch memory
test "the ambient cube's blend is the executable's":
	m = machine() ?? return
	m.stubs[0x1_414e_c3b0] = .Returns(0, 0)
	sky = x64.scratchBase
	blend = x64.scratchBase + 0x1000
	current = x64.scratchBase + 0x2000
	last = x64.scratchBase + 0x6000
	rng = Random(31)
	differ = 0
	for k in 0..inputs:
		first = rng.nextInt(0, 4)
		second = rng.nextInt(0, 4)
		w = Vec4(
			f32(rng.nextFloat(0.0, 1.0)),
			f32(rng.nextFloat(0.0, 1.0)),
			f32(rng.nextFloat(0.0, 1.0)),
			f32(rng.nextFloat(0.0, 1.0))
		)
		for j in 0..4:
			m.mem.write(blend + 0x10 + u64(4 * j), 4, [w.x, w.y, w.z, w.w][j].toBits())
		hasLast = k % 2 == 0
		cubes = []
		fresnels = []
		for weather in [current, last]:
			cube = []
			for time in 0..4:
				for u in 0..7:
					c = esm.Color(
						r = rng.nextInt(0, 256),
						g = rng.nextInt(0, 256),
						b = rng.nextInt(0, 256)
					)
					cube.push(c)
					m.mem.write(
						weather + 0x7f8 + u64((time * 8 + u) * 4),
						4,
						u64(c.r | c.g << 8 | c.b << 16)
					)
				f = f32(rng.nextFloat(0.0, 4.0))
				fresnels.push(f)
				m.mem.write(weather + 0x814 + u64(time * 0x20), 4, f.toBits())
			cubes.push(cube)
		_ = m.call(
			0x1_4041_6490,
			[
				.Int(sky),
				.Int(blend),
				.Int(current),
				.Int(last if hasLast else 0),
				.Int(u64(first)),
				.Int(u64(second))
			]
		) ?? fail
		got = []
		for u in 0..7:
			at = sky + 0x200 + u64(12 * u) if u < 6 else sky + 0x248
			for c in 0..3:
				got.push(m.mem.read(at + u64(4 * c), 4))
		got.push(m.mem.read(sky + 0x254, 4))
		want = []
		for u in 0..7:
			lf esm.Color? = none
			ls esm.Color? = none
			if hasLast:
				lf = cubes[1][first * 7 + u]
				ls = cubes[1][second * 7 + u]
			v = cubes[0][first * 7 + u].mixedFace(cubes[0][second * 7 + u], lf, ls, w)
			want.push(v.x.toBits())
			want.push(v.y.toBits())
			want.push(v.z.toBits())
		fl f32? = none
		fs f32? = none
		if hasLast:
			fl = fresnels[4 + first]
			fs = fresnels[4 + second]
		want.push(world.mixedFresnel(fresnels[first], fresnels[second], fl, fs, w).toBits())
		if got != want.map(u64(it)):
			if differ < 3:
				print("ambient({first}, {second}, {w}, last {hasLast}): exe {got}, port {want}")
			differ += 1
	expect differ == 0

# Moon::Update (0x14040e0f0): a moon's object, its root and meshes' nodes, and a sky with its hour,
# the stars' alpha and the moon glare color in scratch memory; the shader properties' vtable method
# answers with the type the update tests for. The angle, the hour kept, the root's rotation and the
# alphas it sets on the two meshes' properties against the port's. The executable's sine and cosine
# are its vector sincos (not correctly rounded), so the rotation is compared within a few ulps.
test "the moon's angle, fades and placement are the executable's":
	m = machine() ?? return
	moon = scratch(0)
	root = scratch(1)
	moonNode = scratch(2)
	shadowNode = scratch(3)
	moonMesh = scratch(4)
	shadowMesh = scratch(5)
	moonProp = scratch(6)
	shadowProp = scratch(7)
	sky = scratch(8)
	stars = scratch(9)
	methods = scratch(10)
	for (at, v) in [
		(moon + 8, root),
		(moon + 0x10, moonNode),
		(moon + 0x18, shadowNode),
		(moon + 0x20, moonMesh),
		(moon + 0x28, shadowMesh),
		(moonMesh + 0x128, moonProp),
		(shadowMesh + 0x128, shadowProp),
		(moonProp, methods),
		(shadowProp, methods),
		(methods + 0x10, fakeMethods),
		(sky + 0x78, stars)]:
		m.mem.write(at, 8, v)
	m.stubs[fakeMethods] = .Returns(0x1_4343_6648, 0)
	m.mem.write(sky + 0x1BC, 4, 3)
	for at in [root, moonMesh, shadowMesh]:
		m.mem.write(at + 0xF4, 4, 0x20)
	# the glare color differs from the executable's last one, so the colors are written
	for k in 0..3:
		m.mem.write(0x1_4331_d6f0 + u64(4 * k), 4, bitsOf(f32(7.0)))
		m.mem.write(sky + 0x168 + u64(4 * k), 4, bitsOf(f32(k) + 0.25))
	rng = Random(21)
	differ = 0
	shown = 0
	for k in 0..inputs:
		settings = world.MoonSettings(
			"moon",
			fadeStart = f32(rng.nextFloat(30.0, 80.0)),
			fadeEnd = f32(rng.nextFloat(10.0, 60.0)),
			earlyFade = f32(rng.nextFloat(0.0, 5.0)),
			speed = f32(rng.nextFloat(0.05, 0.6)),
			zOffset = f32(rng.nextFloat(0.0, 80.0)),
			size = 94.0
		)
		fresh = k % 9 == 0
		angle = f32(rng.nextFloat(0.0, 360.0)) if k % 7 != 0
			else f32(rng.nextFloat(0.0, 4.0)) * 45.0
		last = world.moonNever if fresh else f32(rng.nextFloat(0.0, 24.0))
		hour = f32(rng.nextFloat(0.0, 24.0))
		starsAlpha = f32(rng.nextFloat(0.0, 1.0)) if k % 3 != 0 else 1.0
		for (at, v) in [
			(moon + 0xB0, settings.fadeStart),
			(moon + 0xB4, settings.fadeEnd),
			(moon + 0xB8, settings.earlyFade),
			(moon + 0xBC, settings.speed),
			(moon + 0xC0, settings.zOffset),
			(moon + 0xCC, angle),
			(moon + 0xD0, last),
			(sky + 0x1B0, hour),
			(stars + 0x18, starsAlpha),
			(moonProp + 0x94, f32.fromBits(0xFFFF_FFFF)),
			(shadowProp + 0x94, f32.fromBits(0xFFFF_FFFF))]:
			m.mem.write(at, 4, bitsOf(v))
		m.mem.write(moon + 0xC8, 4, 0)
		_ = m.call(0x1_4040_e0f0, [.Int(moon), .Int(sky)]) ?? fail
		gotAngle = m.mem.read(moon + 0xCC, 4)
		mineAngle = world.moonAngleAfter(angle, last, hour, settings.speed)
		if gotAngle != bitsOf(mineAngle):
			if differ < 5: print("angle {angle} {last} {hour}: exe {f32.fromBits(u32.wrap(gotAngle))}, port {mineAngle}")
			differ += 1
			continue
		expect m.mem.read(moon + 0xD0, 4) == bitsOf(hour)
		# the alphas: written only where they are above 0 (the moon's, the shadow's), else left
		moonSeen = f32.fromBits(u32.wrap(m.mem.read(moonProp + 0x94, 4)))
		shadowSeen = f32.fromBits(u32.wrap(m.mem.read(shadowProp + 0x94, 4)))
		moonAlpha = settings.moonAlpha(mineAngle)
		shadowAlpha = settings.moonShadowAlpha(mineAngle, starsAlpha)
		if moonAlpha > 0.0:
			shown += 1
			if bitsOf(moonSeen) != bitsOf(moonAlpha):
				if differ < 5: print("moon alpha at {mineAngle}: exe {moonSeen}, port {moonAlpha}")
				differ += 1
		elif bitsOf(moonSeen) != 0xFFFF_FFFF:
			differ += 1
		if shadowAlpha > 0.0:
			if bitsOf(shadowSeen) != bitsOf(shadowAlpha):
				if differ < 5:
					print("shadow alpha at {mineAngle}: exe {shadowSeen}, port {shadowAlpha}")
				differ += 1
		elif bitsOf(shadowSeen) != 0xFFFF_FFFF:
			differ += 1
		# the root's rotation: columns right, center and up
		cols = (0..3).map(Vec3(
			f32.fromBits(u32.wrap(m.mem.read(root + 0x48 + u64(4 * it), 4))),
			f32.fromBits(u32.wrap(m.mem.read(root + 0x54 + u64(4 * it), 4))),
			f32.fromBits(u32.wrap(m.mem.read(root + 0x60 + u64(4 * it), 4)))
		))
		place = world.moonPlaceAt(mineAngle, settings.zOffset)
		close = (cols[0] - place.right).length() < 0.0001 and
			(cols[1] * 512.0 - place.center).length() < 0.05 and
			(cols[2] - place.up).length() < 0.0001
		if not close:
			if differ < 5:
				print("placement at {mineAngle}, {settings.zOffset}: exe {cols}, port {place}")
			differ += 1
	expect shown > inputs / 4
	expect differ == 0

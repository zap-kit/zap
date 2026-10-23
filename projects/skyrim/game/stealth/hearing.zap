# Detection events: the noises that reach an actor outside its sight, the second half of
# Actor::CalculateDetection (0x1406a33b0). Whatever makes a noise worth hearing (a spell cast, an
# explosion, an impact, a papyrus CreateDetectionEvent) stores it in the process of the actor
# that made it (SetActorsDetectionEvent 0x1406f2560, at AIProcess +0x3d8): its sound level's value,
# where it was made and when; one for each actor, the next replacing it, gone
# fDetectionEventExpireTime (5 s) after (0x1406f26e0). A watcher whose own sight gave no level above
# 0 reads the watched's event, and the watched's projectiles in the air, as sounds of a source
# that is not the watched's own action (the sum 0x14041d230, detection.zap's heardLevel); one it
# hears makes its level 0 and keeps the place of the sound (DetectionState +0x3c), which is a noise
# heard and no one seen: the alarm of a crime (0x140682ed0) asks for a level above 0.
#
# It listens only when it does not count the watched among its allies or friends (its faction
# reaction at 2 or 3 skips it), and when it or the watched is in combat or, for the player, when it
# would attack him on sight (IsHostileToActor 0x14068c9d0). The event reaches
# fDetectEventDistancePlayer (1536; the NPCs' 512 are for watched that are not the player), twice
# that for a very loud sound (fDetectEventDistanceVeryLoudMult); the projectiles
# fDetectProjectileDistancePlayer (1024) from the watcher's head, each heard as a Normal sound. The
# exe compares the angle to the event, in radians, with half the view cone in degrees, so any
# sound whose point the watcher's eye reaches counts as in its cone, whatever way it faces.

import game.sim

# the watcher, as the hearing reads it
pub type Ear:
	feet Vec3
	eye Vec3
	heading f32 = 0.0   # radians from north toward east
	sleeping bool = false
	exterior bool = false
	friendly bool = false   # its faction reaction to the watched is ally or friend
	fights bool = false   # it is in combat (it holds a combat controller)
	watchedFights bool = false   # the watched is in combat
	hostile bool = false   # it would attack the watched on sight
	eventClear bool = true   # its eye reaches the place of the event (a ray on the cell's geometry)
	projectileClear bool = true   # the same for a projectile

# a sound heard: where it came from
pub type Heard:
	at Vec3

# the value of a sound level code of a record (0 Loud, 1 Normal, 2 Silent, 3 Very Loud): 0x14041d3f0
pub fn soundValue(settings {str: f64}, code i64) i64:
	name = match code:
		0: "isoundlevelloud"
		1: "isoundlevelnormal"
		2: "isoundlevelsilent"
		3: "isoundlevelveryloud"
		_: return 0
	i64(settings.gmst(name))

# the actor makes a noise at this place: the event its process keeps (0x1406f2560) and, as the
# callers do (0x14069fe50), the sound level of its last action
pub fn createEvent(mut w sim.GameWorld, source i64, at Vec3, sound i64, cause i64 = 0):
	w.stealth.events[source] = sim.DetectionEvent(sound, at, time = w.stealth.clock, owner = cause)
	if source == w.player: w.makeNoise(sound)

# the actor's event that has not expired (0x1406f26e0 drops it past fDetectionEventExpireTime)
pub fn eventOf(w sim.GameWorld, source i64) sim.DetectionEvent?:
	ev = try w.stealth.events.get(source)
	if w.stealth.clock - ev.time > w.settings.gmst("fdetectioneventexpiretime"): return none
	ev.copy()

# whether the watcher listens at all
pub fn canHear(e Ear) bool:
	not e.friendly and (e.fights or e.watchedFights or e.hostile)

# how far a sound of this level carries to a watcher of the player
pub fn eventReach(settings {str: f64}, sound i64) f32:
	reach = settings.gmst("fdetecteventdistanceplayer")
	if sound >= i64(settings.gmst("isoundlevelveryloud")):
		reach *= settings.gmst("fdetecteventdistanceveryloudmult")
	reach

# Whether the watcher's view cone holds the sound: the exe's comparison of the angle in radians
# with half of the cone in degrees, true wherever its eye reaches the sound.
pub fn isInCone(settings {str: f64}, clear bool, angle f32) bool:
	clear and angle < settings.gmst("fdetectionviewcone") * 0.5

# the sound of this level at this place, as the watcher hears it, none when it does not
fn hearSound(settings {str: f64}, e Ear, at Vec3, sound i64, clear bool) Heard?:
	angle = angleToward(e.heading, e.feet, at)
	level = settings.heardLevel(
		sound,
		e.feet.distance(at),
		clear,
		settings.isInCone(clear, angle),
		e.sleeping,
		e.exterior
	)
	Heard(at) if level > 0 else none

# the watched's event, as the watcher hears it: within its reach
pub fn hearEvent(settings {str: f64}, e Ear, ev sim.DetectionEvent) Heard?:
	if e.feet.distance(ev.at) >= settings.eventReach(ev.sound): return none
	settings.hearSound(e, ev.at, ev.sound, e.eventClear)

# the first of the watched's projectiles in the air the watcher hears: each a Normal sound, those
# within fDetectProjectileDistancePlayer of its head
pub fn hearProjectiles(
	settings {str: f64},
	e Ear,
	shots sim.FlyingProjectile[]
) Heard?:
	reach = settings.gmst("fdetectprojectiledistanceplayer")
	normal = settings.soundValue(1)
	for shot in shots:
		if e.eye.distance(shot.at) >= reach: continue
		if settings.hearSound(e, shot.at, normal, e.projectileClear) is heard: return heard
	none

# What the game keeps of the player's stealth: whether he sneaks (the actor state's sneaking bit,
# toggled by the Sneak command, SneakHandler 0x1407b3a80), and for each actor that could notice him
# the detection state it holds against him (DetectionState 0x1407c6510: the level at 0x10, the
# view-cone and line-of-sight flags at 0x14 and 0x15), which the formulas of game/stealth fill. An
# actor has detected him while its level is above 0 (Actor.IsDetectedBy, 0x140a00ef0).

# the level an actor holds before it has looked (the detection request's default, 0xfffffc18)
pub notLooked = -1000

pub type Detection:
	level i64 = notLooked
	inCone bool = false   # the player is inside its view cone and its sight reaches him
	lineOfSight bool = false
	at f32 = -1000.0   # the stealth clock when it was worked out
	heard bool = false   # level 0 because it heard a detection event (not a sight): noiseAt is where
	noiseAt Vec3 = Vec3(0, 0, 0)   # where the sound it holds came from (DetectionState +0x3c)

# What an actor's process keeps of the last noise it made (SetActorsDetectionEvent 0x1406f2560,
# at AIProcess +0x3d8): the sound level's value, where it was made, the stealth clock then and
# who made it. One for each actor; the next replaces it, and it expires after
# fDetectionEventExpireTime seconds (0x1406f26e0).
pub type DetectionEvent:
	sound i64
	at Vec3
	time f32
	owner i64 = 0

# a projectile in flight that someone fired: what the watcher hears of the shooter (0x1406a33b0)
pub type FlyingProjectile:
	owner i64
	at Vec3

pub type Stealth:
	sneaking bool = false
	clock f32 = 0.0   # seconds the detections have run
	detections {i64: Detection} = {}   # by the watcher's reference: how it detects the player
	roll i64 = 17   # the pickpocket rolls' random state
	action i64 = 0   # the sound level of the player's last noisy action (Actor.actionValue, 0x11c)
	actionUntil f32 = 0.0   # the clock it fades at (fActorAlertSoundTimer after the action)
	events {i64: DetectionEvent} = {}   # the last noise of each actor, by the actor that made it
	flying FlyingProjectile[] = []   # the projectiles in the air

# whether the actor has detected the player
pub fn isDetectedBy(w GameWorld, watcher i64) bool:
	(w.stealth.detections.get(watcher)?.level ?? notLooked) > 0

# Whether the player may pickpocket the actor: it lives, is not the player, its race allows it and
# the player sneaks (the activation text, 0x1403c1000).
pub fn canPickpocket(w GameWorld, victim i64) bool:
	a = w.actors.get(victim) ?? return false
	w.stealth.sneaking and victim != w.player and not a.dead and a.pickpocketable

# the actors that have detected the player
pub fn detectorsOf(w GameWorld) i64[]:
	w.stealth.detections.keys().filter(w.isDetectedBy(it)).sorted()

# The highest level any actor holds against the player (ProcessLists 0x140786350), and how many of
# the actors' states have a line of sight to him.
pub fn highestLevel(w GameWorld) (i64, i64):
	best = notLooked
	seeing = 0
	for d in w.stealth.detections.values():
		best = best.max(d.level)
		if d.lineOfSight: seeing += 1
	(best, seeing)

# The Sneak command (SneakHandler 0x1407b3a80 sends the graph's sneak events): sneaking starts, or
# stops when it was on; whether he sneaks now.
pub fn toggleSneak(mut w GameWorld) bool:
	w.stealth.sneaking = not w.stealth.sneaking
	w.stealth.sneaking

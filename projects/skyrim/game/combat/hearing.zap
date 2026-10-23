# What a fight's bystanders do with a noise they hear and did not see (game/stealth/hearing.zap):
# the exe stores it in the watcher's detection state as level 0 with the place of the sound, which
# is not a detection, so no one joins, flees or witnesses a crime for it (the alarm of an assault,
# 0x140682ed0, asks for a level above 0): the actor only looks up. An idle actor that heard turns
# to the sound and is on the alert; one that fights, flees or already watches goes on.

# The player's noise heard now: every idle fighter whose reading of him is a sound turns to its
# place and is on the alert.
pub fn listen(mut f Fight):
	f.lookAtPlayer()
	for k in 0..f.fighters.len:
		x = f.fighters[k]
		if x.player or x.mode != .Idle: continue
		d = f.w.stealth.detections.get(x.refId) ?? continue
		if not d.heard: continue
		f.face(k, d.noiseAt)
		f.fighters[k].mode = .Alert
		f.note("{x.name} hears a noise and looks up")

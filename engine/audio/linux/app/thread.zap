# An Android app's audio thread (engine/audio/audio.zap's): no class to join, the system schedules
# AAudio's own thread.

fn raiseAudioPriority():
	0

fn lowerAudioPriority(task i64):
	pass

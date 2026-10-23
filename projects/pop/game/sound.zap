# The sounds the game asks for (SDLPoP's seg000.c play_sound, play_next_sound and seg009.c's
# playing): one sound a frame by priority, and how long the one playing lasts, which the game
# waits on (death, the level's end, the feather's fall).

soundPrioTable = [
	0x14,
	0x1E,
	0x23,
	0x66,
	0x32,
	0x37,
	0x30,
	0x30,
	0x4B,
	0x50,
	0x0A,
	0x12,
	0x0C,
	0x0B,
	0x69,
	0x6E,
	0x73,
	0x78,
	0x7D,
	0x82,
	0x91,
	0x96,
	0x9B,
	0xA0,
	0x01,
	0x01,
	0x01,
	0x01,
	0x01,
	0x13,
	0x01,
	0x01,
	0x01,
	0x01,
	0x01,
	0x01,
	0x01,
	0x01,
	0x01,
	0x00,
	0x01,
	0x01,
	0x01,
	0x01,
	0x87,
	0x8C,
	0x0F,
	0x10,
	0x19,
	0x16,
	0x01,
	0x00,
	0x01,
	0x01,
	0x01,
	0x01,
	0x01,
	0x00
]
pub soundInterruptibleStart = [
	0,
	1,
	1,
	1,
	1,
	1,
	0,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	0,
	0,
	1,
	1,
	0,
	1,
	1,
	1,
	1,
	1,
	0,
	0,
	0,
	0,
	0,
	1,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	1,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0
]

# play_sound: the sound for the end of the frame, unless one more important is asked
pub fn playSound(mut g Game, soundId i64):
	if g.nextSound < 0 or soundPrioTable[soundId] <= soundPrioTable[g.nextSound]:
		if g.sounds.exists(soundId):
			g.nextSound = soundId

pub fn playNextSound(mut g Game):
	if g.nextSound >= 0:
		if not g.isSoundPlaying() or
			(
				g.soundInterruptible[g.currentSound] != 0 and
					soundPrioTable[g.nextSound] <= soundPrioTable[g.currentSound]
			):
			g.currentSound = g.nextSound
			g.startSound(g.currentSound)
	g.nextSound = -1

# play_sound_from_buffer: it plays at once, over the one playing
pub fn startSound(mut g Game, soundId i64):
	if not g.sounds.exists(soundId) or not g.soundOn or g.skippingReplay: return
	g.soundTicksLeft = g.sounds.ticks(soundId)
	g.soundPlaying = g.soundTicksLeft > 0
	g.soundsPlayed.push(soundId)

pub fn stopSounds(mut g Game):
	g.soundPlaying = false
	g.soundTicksLeft = 0
	g.soundsStopped = true

pub fn isSoundPlaying(g Game) bool:
	g.soundPlaying

# the time of a frame passed for the sound playing
pub fn tickSounds(mut g Game, ticks i64):
	if not g.soundPlaying: return
	g.soundTicksLeft -= ticks
	if g.soundTicksLeft <= 0:
		g.soundPlaying = false
		g.soundTicksLeft = 0

# The game's sounds as the AdLib driver's effects (adlib.dat's 18, numbered from 1): which one the
# DOS game asks for at each cue, read from the oracle's log of the driver's channels.

# the driver's effect for a cue, 0 for none
pub fn effectOf(c Cue) i64:
	match c:
		Trap(sound): sound
		LetsGo: 3
		Entrance: 2
		SkillButton: 1
		AssignSkill: 4
		OhNo: 5
		Splat: 8
		Explosion: 12
		Yippee: 16
		Drowning: 17
		Vaporizing: 13
		BuilderWarning: 18
		HitsSteel: 10

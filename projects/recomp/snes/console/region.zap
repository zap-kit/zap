# The console the cartridge is made for: NTSC (262 lines a frame, a 21,477,270 Hz master clock,
# 60.1 frames a second) or PAL (312 lines, 21,281,370 Hz, 50.0), as its header's destination says
# and Mesen 2 picks. The SPC700's clock is the same on both, so its pace against the master clock
# is not.

ntscMasterRate = 21_477_270.0
palMasterRate = 21_281_370.0

fn setRegion(pal bool):
	linesPerFrame = 312 if pal else 262
	masterRate = palMasterRate if pal else ntscMasterRate
	spcTicksPerMaster = (sampleRate * 64) / masterRate
	framesPerSecond = masterRate / (linesPerFrame * cyclesPerLine)

# the master clock's rate on the console the cartridge runs on
fn masterRateNow():
	palMasterRate if linesPerFrame == 312 else ntscMasterRate

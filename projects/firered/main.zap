# Pokemon FireRed recompiled into native Zap: the cartridge's ARM and Thumb code translated ahead
# of time into Zap (projects/firered/prepare.zap), built into one executable with the GBA's hardware
# written in Zap on the engine (projects/firered/gba). Needs the player's own dump of the cartridge at
# projects/firered/rom/firered.gba only to prepare, which this does first when projects/firered/recomp/ is missing;
# it then builds build/firered.exe when it is missing and runs it. Run from the repository root:
#
#   zap run projects/firered/main.zap         the arrows move, Z is A, X is B, Enter Start, Backspace
#                                         Select, A and S the shoulders; closing the window leaves
#   zap run projects/firered/main.zap --frames 2400 --hash --headless   (the title screen's hash, no window)
#   zap run projects/firered/main.zap --frames 2400 --shot title.png    (the frame saved)
#   zap run projects/firered/main.zap --uncapped                        (as fast as it runs)
#   needs: projects/firered/rom/firered.gba (the player's dump, never committed)

import fs
import translate

compiler = "build/zap{exeSuffix()}"
game = "build/firered{exeSuffix()}"

if not fs.exists("{translate.recompDir}/firered.zap"):
	print("FireRed prepares itself from projects/firered/rom/firered.gba (once; zap run projects/firered/prepare.zap does it ahead)...")
	translate.prepareGame("projects/firered/rom/firered.gba", false)
if not fs.exists(game):
	print("building {game}...")
	if Process.run("{compiler} build {translate.recompDir}/firered.zap") != 0: exit(1)
exit(Process.run("{game} {args.join(" ")}"))

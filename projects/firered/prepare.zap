# Prepares Pokemon FireRed from the player's own cartridge dump (projects/firered/rom/firered.gba, USA,
# revision 0; nothing of the game is in the repository): checks it, finds its functions, writes
# them recompiled into projects/firered/recomp/ (a Zap program, projects/firered/recomp/firered.zap) and the
# cartridge's data the code reads into projects/firered/assets/. The game then needs no ROM. Run from the
# repository root:
#
#   zap run projects/firered/prepare.zap [--rom <file>] [--trace]
#
# --trace writes code that keeps the functions it last entered, which the game prints when it
# stops on an error or with --calls.

import translate

translate.prepareGame(
	args.option("--rom") ?? "projects/firered/rom/firered.gba",
	args.hasFlag("--trace")
)

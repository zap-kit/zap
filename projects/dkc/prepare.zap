# Prepares Donkey Kong Country from the player's own dump (projects/dkc/rom/dkc1.sfc, USA v1.0;
# nothing of the game is in the repository): checks it, finds its functions from the cfg's
# tables and writes them recompiled by recomp.snes into projects/dkc/recomp/ (a Zap program,
# projects/dkc/recomp/dkc.zap, built with `zap build projects/dkc/recomp/dkc.zap`). Run from the
# repository root:
#
#   zap run projects/dkc/prepare.zap [--rom <file>]

import cartridge

cartridge.prepare(args.option("--rom") ?? cartridge.romPath)

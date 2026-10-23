# Prepares what Skate 3 draws and touches from the user's Skate 3 disc into projects/skate3/assets/ (not
# committed): the district's world (its models in batches, their textures, its collision) and the
# skater. The game runs this itself when the files are missing; run it again by hand after a
# change to the decoding. Run from the repository root:
#
#   zap run projects/skate3/prepare.zap                         University and the skater
#   zap run projects/skate3/prepare.zap --district DIST_MegaPark
#   zap run projects/skate3/prepare.zap --iso D:/skate3.iso

import skate

district = args.option("--district") ?? skate.defaultDistrict
if skate.prepareAll(args.option("--iso"), district) is why:
	fail(why)

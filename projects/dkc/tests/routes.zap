# The routes of tests/routes/ played by the Zap build from power-on and compared frame by frame
# with the hashes Mesen 2 wrote for them (tools/oracle.lua): every frame's picture and work RAM the
# same. Without the dump the file is skipped, with a line.
#   needs: projects/dkc/rom/dkc1.sfc (the player's dump, never committed)

import playing

# the title (the logos, Start, the intro and their music), then a new game: the file select, Kongo
# Jungle's map and Jungle Hijinxs' first walk and jumps
test "the game, prepared and built, plays its routes as Mesen 2 does":
	playing.preparedAndBuilt()
	playing.playsAsMesen("title", 900)
	playing.playsAsMesen("jungle", 3700)

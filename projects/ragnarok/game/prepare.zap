# Preparing the game from the player's Ragnarok Online LATAM install: the map and the hero read
# out of its GRF archives once and written ready to use into projects/ragnarok/assets/prepared/, which
# the game then only reads (see world/prepared.zap).

import ragnarok
import world

# the map the game opens in: Prontera (data\prontera.rsw and the files it names)
pub startMap = "prontera"

fn openInstallAt(dir str):
	ragnarok.openInstall(dir) ?? fail

# the map `map`, the hero and the cursors prepared from the install in `dir`
pub fn prepareGame(dir str, map str):
	started = clockSeconds()
	i = openInstallAt(dir)
	i.prepareZone(map)
	i.prepareFigures()
	i.prepareCursors()
	print("prepared {map}, the hero and the cursors from {dir} into {world.preparedDir} in {(clockSeconds() - started):.1} s")

# the hero and the cursors alone prepared from the install in `dir`
pub fn prepareFiguresAndCursors(dir str):
	i = openInstallAt(dir)
	i.prepareFigures()
	i.prepareCursors()

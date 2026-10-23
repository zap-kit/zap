# The player's Ragnarok Online install: its GRF archives, searched in order (data.grf first),
# from which everything of the game is read where it lies.

import fs
import ragnarok.grf

# where the install is looked for when no --install dir is given
pub defaultInstall = "C:/Gravity/Ragnarok"

pub type Install:
	grfs grf.Grf[]

# the archives of the install in `dir`, or why there are none
pub fn openInstall(dir str) Install ? str:
	grfs = []
	for file in ["data.grf", "event.grf"]:
		path = "{dir}/{file}"
		if fs.exists(path):
			match grf.openGrf(path):
				g: grfs.push(g)
				error: eprint("skipped: {error}")   # event.grf is an old 0x102 archive, not needed
	if grfs.isEmpty:
		return "no data.grf in {dir}: give the dir of your Ragnarok Online LATAM install"
	Install(grfs)

# the bytes of the entry with this key (grfKey) in the first archive that has it; none when no
# archive has it, and the program stops when one has it damaged
pub fn installRead(i Install, key str) u8[]?:
	for g in i.grfs:
		if g.grfHas(key): return g.grfRead(key) ?? fail("{key}: {error}")
	none

# the entry at a path written in UTF-8 (Korean in CP949, as the archives spell it)
pub fn installReadPath(i Install, path str) u8[]?:
	i.installRead(grfPath(path))

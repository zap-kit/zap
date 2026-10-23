# Donkey Kong Country (USA, v1.0) as recomp.snes prepares it: the player's dump checked, the
# community's tables (tables/), the program's name and the widescreen's patches (patches.zap).

import digest
import fs
import recomp.snes.snes

pub romPath = "projects/dkc/rom/dkc1.sfc"
pub recompDir = "projects/dkc/recomp"
expectedSha256 = "fa8cacf5bbfc39ee6bbaa557adf89133d60d42f6cf9e1db30d5a36a469f74d15"

# what is wrong with the dump, or none for Donkey Kong Country (USA, v1.0)
pub fn romProblem(rom u8[]) str?:
	if rom.len != 0x40_0000:
		return "it is {rom.len} bytes, not 4 MB (a dump with a copier's header?)"
	sha = digest.sha256(rom).map("{it:02x}").join("")
	if sha != expectedSha256: return "its SHA-256 is {sha}, not {expectedSha256}"
	none

pub fn game(rom str = romPath) snes.Game:
	snes.Game(
		name = "dkc",
		romPath = rom.copy(),
		recompDir = recompDir,
		tablesDir = "projects/dkc/tables",
		imports = ["wide"],
		setup = ["wide.install()"],
		patches = widePatches()
	)

# Prepares from the dump at `rom`; stops the program with the reason when it is not the game's.
pub fn prepare(rom str = romPath):
	bytes = fs.readBytes(rom) ?? fail("no ROM at {rom}: {error}")
	if romProblem(bytes) is why: fail("{rom} is not Donkey Kong Country (USA, v1.0): {why}")
	game(rom).prepareGame()

# Any cartridge through the tool alone: prepared with no tables of its own (the flow from the
# vectors, the interpreter for what it cannot see), built, and a route of random buttons played
# from power-on, every frame's picture and work RAM the same as Mesen 2's for that route
# (check.zap wrote both). Without the dumps the file is skipped, with a line.
#   needs: projects/recomp/snes/rom/smw.sfc (the player's dump, never committed)
#   needs: projects/recomp/snes/rom/zelda.sfc (the player's dump, never committed)

import recomp.snes.mesen

routes = "projects/recomp/snes/tests/routes"

# the game prepared from its dump and built, its route played for `frames` and compared
fn playsAsMesen(name str, frames i64, options str):
	prepared = Process.output(
		"{zapPath()} run projects/recomp/snes/main.zap projects/recomp/snes/rom/{name}.sfc --out projects/recomp/snes/out/tests/{name} --build"
	)
	expect prepared.code == 0
	verdict = mesen.playedAgainst(
		builtExe(name),
		"{routes}/{name}.txt",
		"{routes}/{name}-mesen.txt",
		"build/games-{name}.txt",
		frames,
		options
	)
	expect verdict == mesen.allEqual(frames)

test "Super Mario World, through the tool alone, plays as Mesen 2 does":
	playsAsMesen("smw", 3000, "")

test "Zelda, through the tool alone, plays as Mesen 2 does":
	playsAsMesen("zelda", 3000, "")

# the interpreter alone, no translated function run, is the same machine
test "Super Mario World interpreted whole plays as Mesen 2 does":
	playsAsMesen("smw", 1500, "--interpret")

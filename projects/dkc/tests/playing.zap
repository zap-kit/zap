import fs
import recomp.snes.mesen

# What the route tests share: a route played by the Zap build from power-on and compared frame by
# frame with the hashes Mesen 2 wrote for it (tools/oracle.lua).

routes = "projects/dkc/tests/routes"

# the route `name` played for `frames` frames, every one the same as Mesen 2's
pub fn playsAsMesen(name str, frames i64):
	playsAsMesenWith(name, frames, "")

# the same with more options for the game (`--wide --wide-native-logic`: drawn wide, the cartridge's
# work RAM and native picture still Mesen's)
pub fn playsAsMesenWith(name str, frames i64, options str):
	verdict = mesen.playedAgainst(
		builtExe("dkc"),
		"{routes}/{name}.txt",
		"{routes}/{name}-mesen.txt",
		"build/dkc-{name}.txt",
		frames,
		options
	)
	expect verdict == mesen.allEqual(frames)

# the game prepared from the dump and built
pub fn preparedAndBuilt():
	expect Process.output("{zapPath()} run projects/dkc/prepare.zap").code == 0
	expect Process.output("{zapPath()} build projects/dkc/recomp/dkc.zap").code == 0

# The route `name` played wide (--wide) for `frames` frames: a line "frame hash wide" for each, the
# hash of the wide picture and whether its scene was drawn wide (else the native frame on black).
pub fn wideLines(name str, frames i64) str[]:
	path = "build/dkc-wide-{name}.txt"
	played = Process.output(
		"{builtExe("dkc")} --headless --wide --frames {frames} --route {routes}/{name}.txt --wide-hashes {path}"
	)
	expect played.code == 0
	(fs.readFile(path) ?? "").lines()

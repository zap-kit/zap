# Brings everything of the player's Skyrim install that the game reads into the repository's
# projects/skyrim/assets/game/, laid out as the install is, so the project reads the game from
# there alone: Data's archives (BSA), plugins (ESM, ESL, ESP: the base game, its updates, the DLC
# and the Creation Club ones the Anniversary Edition loads) and videos, and the install's own
# Skyrim.ccc and default ini files. The executable is not copied (what the project uses of it is
# in reference/exe as text). The dir is ignored by git and never committed. In a worktree of the
# repository the main checkout's dir is filled and this one's is a junction to it. A file already
# there with the same size and time is not copied again. Run from the repository root:
#
#   zap run projects/skyrim/fetch.zap [--install <the install's dir>]

import fs
import skyrim.esm

# where Steam put the player's Skyrim Anniversary Edition
defaultSource = "C:/games/Skyrim Anniversary Edition"
# what of the install's own dir the game reads
rootFiles = ["Skyrim.ccc", "Skyrim_Default.ini", "Low.ini", "Medium.ini", "High.ini", "Ultra.ini"]
# what of its Data dir it reads
dataFiles = ["*.bsa", "*.esm", "*.esl", "*.esp"]

fn quoted(path str):
	"\"{path.replace("/", "\\")}\""

# Copies the files matching `patterns` from `from` into `to` (dirs made), with robocopy, which
# streams them and skips those already equal; `recurse` takes the subdirs too. Robocopy's codes
# under 8 are success.
fn copyFiles(from str, to str, patterns str[], recurse bool):
	line = "robocopy {quoted(from)} {quoted(to)} {patterns.join(" ")} /R:1 /W:1 /NP /NJH /NDL"
	code = Process.run(line + (" /E" if recurse else ""))
	if code >= 8: fail("robocopy failed ({code}): {line}")

# the main checkout of the repository when this one is a worktree of it (.git is a file naming
# the main one's git dir), none in the main checkout
fn mainCheckout() str?:
	text = fs.readFile(".git") ?? return none
	gitDir = text.trimmed().replace("gitdir: ", "").replace("\\", "/")
	at = try gitDir.indexOf("/.git/worktrees/")
	gitDir[..at].copy()

esm.requireRepoRoot()
args.options([ArgOption("--install", true, "the install's dir (holding SkyrimSE.exe and Data)")])
source = args.option("--install") ?? defaultSource
target = "projects/skyrim/assets/game"
if not fs.exists("{source}/Data/Skyrim.esm"): fail("no Data/Skyrim.esm in {source}: give --install")
# a worktree fills the main checkout's copy and links its own dir to it
copy = "{mainCheckout() ?? "."}/{target}"
copyFiles(source, copy, rootFiles, false)
copyFiles("{source}/Data", "{copy}/Data", dataFiles, false)
copyFiles("{source}/Data/Video", "{copy}/Data/Video", ["*.*"], true)
if copy != "./{target}" and not fs.exists("{target}/Data/Skyrim.esm"):
	fs.createDir("projects/skyrim/assets") ?? fail("cannot make projects/skyrim/assets")
	if Process.run("cmd /c mklink /J {quoted(target)} {quoted(copy)}") != 0:
		fail("cannot link {target} to {copy}")
print("the game's files are in {copy}")

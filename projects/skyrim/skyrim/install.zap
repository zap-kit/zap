# The game's Data dir (fetch.zap's copy in the repository by default): the base game's BSA
# archives ("Skyrim - *.bsa", not the creation club's), searched in order, from which everything
# of the game is read where it lies.

import fs
import image.dds
import skyrim.bsa
import skyrim.esm

# the Data dir read when no --install dir is given
pub defaultInstall = esm.defaultData

# the Data dir the command line names with --install, the default without it
pub fn installDir() str:
	args.option("--install") ?? defaultInstall

# declares the tool's options, --install first, and gives the Data dir --install names
pub fn declareWithInstall(options ArgOption[]) str:
	all = [installOption]
	for o in options: all.push(o.copy())
	args.options(all)
	installDir()

# the option every tool reading the game takes
pub installOption = ArgOption("--install", true, "the game's Data dir")

pub type Install:
	archives bsa.Bsa[]
	names str[]
	data str   # the Data dir it was opened on

# the default install and its Skyrim.esm, none (and a line saying so) without them: where a check
# that reads the game starts
pub fn installAndPlugin() (Install, esm.Esm)?:
	if not fs.exists(esm.defaultEsm()):
		eprint("skipped: no {esm.defaultEsm()} (zap run projects/skyrim/fetch.zap)")
		return none
	install = openInstall(defaultInstall) ?? fail
	(install, esm.openEsm(esm.defaultEsm()) ?? fail)

# the default install, none (and a line saying so) without it
pub fn installOfArchives() Install?:
	if not fs.exists(esm.defaultEsm()):
		eprint("skipped: no {esm.defaultEsm()} (zap run projects/skyrim/fetch.zap)")
		return none
	openInstall(defaultInstall) ?? fail

# the base game's archives in the Data dir `dir`, or why it has none
pub fn openInstall(dir str) Install ? str:
	archives = []
	names = []
	for name in (fs.list(dir) ?? []).sorted():
		lower = name.lower()
		if lower.startsWith("skyrim - ") and lower.endsWith(".bsa"):
			match bsa.openBsa("{dir}/{name}"):
				b:
					archives.push(b)
					names.push(name)
				error: eprint("skipped: {error}")
	if archives.isEmpty:
		return "no Skyrim - *.bsa in {dir}: run zap run projects/skyrim/fetch.zap, or give the Data dir"
	Install(archives, names, data = dir.copy())

# the path of the plugin `name` ("Skyrim.esm") in the install's Data dir
pub fn installPlugin(i Install, name str) str:
	esm.pluginPath(i.data, name)

# the bytes of the file with this key (bsaKey): the first archive's that has it; none when none
# has it, and the program stops when one has it damaged
pub fn installRead(i Install, key str) u8[]?:
	for b in i.archives:
		if b.bsaHas(key): return b.bsaRead(key) ?? fail("{key}: {error}")
	none

# where the file with this key is read from, as a stamp that changes when the file may: the
# archive's name, size and time ("" when none has it)
pub fn installStamp(i Install, key str) str:
	for k in 0..i.archives.len:
		b = i.archives[k]
		if b.bsaHas(key): return "{i.names[k]} {b.file.len} {fs.modified(b.path) ?? 0}"
	""

# whether an archive has the file with this key
pub fn installHas(i Install, key str) bool:
	i.archives.any(.bsaHas(key))

# the keys that start with prefix, in order, each once
pub fn installFind(i Install, prefix str) str[]:
	found {str: bool} = {}
	for b in i.archives:
		for key in b.bsaKeys():
			if key.startsWith(prefix): found[key] = true
	found.keys().sorted()

# the DDS texture with this key, or why it cannot be had
pub fn installTexture(i Install, key str) dds.Dds ? str:
	bytes = i.installRead(key) ?? return "{key} is in no archive"
	dds.readDds(bytes)

test "a real barrel texture and its normal map decode (skipped without the install)":
	if not fs.exists(defaultInstall): return
	install = openInstall(defaultInstall) ?? fail
	for key in ["textures/clutter/barrel01.dds", "textures/clutter/barrel01_n.dds"]:
		tex = install.installTexture(key) ?? fail
		expect tex.width >= 64 and tex.levels > 1
		img = tex.decodeLevel(0)
		expect img.width == tex.width and img.height == tex.height
		first = img.cells[0]
		differing = 0
		for c in img.cells:
			if c != first: differing += 1
		expect differing > img.cells.len / 4

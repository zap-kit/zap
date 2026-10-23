# The presentation a released program starts with (main.zap --release: the widescreen by default):
# options as on the command line, which a command line's own override; `--native` drops them.

import fs

pub mut presets str[] = []

fn presetsApply():
	not args.hasFlag("--native")

# the option's value on the command line, else in the presets
pub fn presetOption(name str) str?:
	if args.option(name) is given: return given.copy()
	if not presetsApply(): return none
	for k, word in presets:
		if word == name and k + 1 < presets.len: return presets[k + 1].copy()
	none

# whether the flag is on the command line or in the presets
pub fn hasPresetFlag(name str) bool:
	args.hasFlag(name) or (presetsApply() and name in presets)

# The dump the program plays: --rom's, else the one it was written for, else <name>.sfc (or .smc)
# beside the executable, where a released program finds the player's own.
pub fn romPath(written str, name str) str:
	if args.option("--rom") is given: return given.copy()
	if fs.exists(written): return written.copy()
	for extension in [".sfc", ".smc"]:
		beside = fs.join(fs.dirOf(exePath()), "{name}{extension}")
		if fs.exists(beside): return beside
	fail("no cartridge: put your dump of the game beside the program as {name}.sfc, or run it with --rom <file>")
	""

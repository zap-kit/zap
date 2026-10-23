# The player's own dumps brought into the project: every file of the dirs given is recognised by
# its SHA-1 (a cartridge or a coprocessor's firmware the project knows) and copied into
# projects/recomp/snes/rom/ under the name the project's tools and tests use. Nothing of them is
# committed (.gitignore: rom/). Run from the repository root:
#
#   zap run projects/recomp/snes/tools/gather.zap <dir>...
#
# A dump the table does not know is left where it is, named in the output.

import digest
import fs

romDir = "projects/recomp/snes/rom"

type Known:
	sha1 str
	name str
	what str

known = [
	Known("6b47bb75d16514b6a476aa0c73a683a2a4c18765", "smw.sfc", "Super Mario World (USA)"),
	Known("6d4f10a8b10e10dbe624cb23cf03b88bb8252973", "zelda.sfc", "Zelda: A Link to the Past (USA)"),
	Known("0fcee45d9af5d2f62995ed4b04d22146b906c86b", "dkcg.sfc", "Donkey Kong Country (USA)"),
	Known("bd5fea18ce7456cc0231a39473927d8ea9c6589b", "aladdin.sfc", "Aladdin (USA)"),
	Known("35b72a3942851aac9c37da07bd39efe1a79e9071", "sf2t.smc", "Street Fighter II Turbo (Europe)"),
	Known("47e103d8398cf5b7cbb42b95df3a3c270691163b", "smk.sfc", "Super Mario Kart (USA)"),
	Known("a4f7539054c359fe3f360b0e6b72e394439fe9df", "smrpg.sfc", "Super Mario RPG (USA)"),
	Known("188d471fefea71eb53f0ee7064697ff0971b1014", "dsp1.rom", "DSP-1 firmware"),
	Known("78b724811f5f18d8c67669d9390397eb1a47a5e2", "dsp1b.rom", "DSP-1B firmware"),
	Known("198c4b1c3bfc6d69e734c5957af3dbfa26238dfb", "dsp2.rom", "DSP-2 firmware"),
	Known("558da7cb3bd3876a6ca693661ffc6c110e948cf9", "dsp3.rom", "DSP-3 firmware"),
	Known("af6478aecb6f1b67177e79c82ca04c56250a8c72", "dsp4.rom", "DSP-4 firmware"),
	Known("6472828403de3589433a906e2c3f3d274c0ff008", "st010.rom", "ST010 firmware"),
	Known("fecbae2cec76c710422486baa186ffa7ca1cf925", "st011.rom", "ST011 firmware"),
	Known("91383b92745cc7cc4f15409ac5bc2c2f699a43f1", "st018.rom", "ST018 firmware")
]

dirs = args.positional()
if dirs.isEmpty: fail("usage: zap run projects/recomp/snes/tools/gather.zap <dir>...")
fs.createDir(romDir) ?? fail("cannot make {romDir}: {error}")
copied = 0
for dir in dirs:
	for name in fs.list(dir) ?? fail("cannot read {dir}: {error}"):
		path = fs.join(dir, name)
		bytes = fs.readBytes(path) ?? continue
		sha = digest.sha1(bytes)
		match known.filter(.sha1 == sha).first:
			k:
				target = fs.join(romDir, k.name)
				if (fs.readBytes(target) ?? []) != bytes:
					fs.writeBytes(target, bytes) ?? fail("cannot write {target}: {error}")
					copied += 1
				print("{k.what}: {target}")
			none: print("not known, left: {path}")
print("{copied} files copied into {romDir}")

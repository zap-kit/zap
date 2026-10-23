# Lists a Skyrim install's archives and the files under a prefix, or extracts one file.
#
#   zap run projects/skyrim/list.zap [--install dir] [prefix]
#   zap run projects/skyrim/list.zap [--install dir] --extract meshes/x.nif out.nif

import fs
import skyrim
import skyrim.bsa

dir = args.option("--install") ?? skyrim.defaultInstall
install = skyrim.openInstall(dir) ?? fail
extract = args.option("--extract")
args.options([skyrim.installOption, ArgOption("--extract", true, "the key to write out")])
rest = args.positional()
if extract != none:
	key = extract ?? ""
	bytes = install.installRead(key) ?? fail("{key} is in no archive")
	fs.writeBytes(rest[0], bytes) ?? fail("cannot write {rest[0]}")
	print("{key}: {bytes.len} bytes")
	return
for i in 0..install.archives.len:
	b = install.archives[i]
	print("{install.names[i]}: {b.bsaCount()} files, {b.bsaCompressedCount()} compressed")
for key in install.installFind(rest[0] if not rest.isEmpty else ""):
	print(key)

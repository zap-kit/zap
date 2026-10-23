# Prepares Excel from the user's own copy of the two Microsoft Excel 1.00 disks (Applesauce
# .moof images at projects/excel1/disks/, never committed): reads each disk once (the GCR sectors of each
# track, the MFS volume, each file's forks) and writes what they hold into projects/excel1/assets/, a
# folder a disk, each file's data fork (.data) and resource fork (.rsrc) as the Mac kept them, its
# directory entry's Finder information, dates and attributes (.info), the names in the directory's
# order (directory.txt), the bits of each track as the drive's head reads them, for the emulated
# floppy drive (<volume>.tracks), and
# projects/excel1/assets/files.txt, the list of what was written: each file's type, creator and forks'
# sizes, each resource, and the code's real size. A second run with nothing changed writes nothing.
# Run from the repository root:
#
#   zap run projects/excel1/prepare.zap [--disks <dir>]

import disk
import fs

assetsDir = "projects/excel1/assets"

# writes the bytes unless the file holds them already: whether it wrote
fn writeChanged(path str, bytes u8[]):
	fs.writeChanged(path, bytes) ?? fail("cannot write {path}: {error}")

# a file's directory entry as the Mac's File Manager gives it: its 16 bytes of Finder information,
# its creation and modification dates, its attributes, its number and its forks' first blocks
fn infoBytes(f disk.MacFile):
	out = f.finderInfo.copy()
	out.pushU32be(f.created)
	out.pushU32be(f.modified)
	out.push(f.attributes)
	out.push(0)
	out.pushU32be(f.number)
	out.pushU16be(f.dataStart)
	out.pushU16be(f.resourceStart)
	out

fn listResources(mut lines str[], fork u8[]):
	match disk.readResources(fork):
		error: lines.push("    resources unreadable: {error}")
		resources: listOf(lines, resources)

fn listOf(mut lines str[], resources disk.Resource[]):
	code = 0
	pcode = 0
	for r in resources:
		named = "" if r.name.isEmpty else " \"{disk.fileName(r.name)}\""
		lines.push("    {r.kind} {r.id}{named} {r.bytes.len}")
		if r.kind == "CODE" and r.id > 0: code += r.bytes.len - 4
		if r.kind == "PCOD": pcode += r.bytes.len
	if code > 0: lines.push("    68000 code in CODE resources: {code} bytes")
	if pcode > 0: lines.push("    Microsoft p-code in PCOD resources: {pcode} bytes")

# The disk's files written under assets/<volume>/: the lines of the list for them, and how many
# files were written.
fn prepareDisk(path str, mut lines str[]):
	image = fs.readBytes(path) ?? fail("cannot read {path}: {error}")
	moof = disk.readMoof(image) ?? fail("{path}: {error}")
	volume = moof.readVolume()
	mfs = disk.readMfs(volume.bytes) ?? fail("{path}: {error}")
	dir = "{assetsDir}/{disk.fileName(mfs.name)}"
	_ = fs.createDir(dir)
	lines.push("volume {disk.fileName(mfs.name)} ({fs.fileName(path)}), {mfs.files.len} files")
	if not volume.unread.isEmpty:
		lines.push("  blocks no turn of their track reads whole: {volume.unread}")
	written = 0
	names = mfs.files.map(disk.fileName(.name))
	if writeChanged("{dir}/directory.txt", "{names.join("\n")}\n".bytes()): written += 1
	for f in mfs.files:
		name = disk.fileName(f.name)
		lines.push("  {name}: type {f.fileType}, creator {f.creator}, data {f.dataFork.len}, resources {f.resourceFork.len}")
		if not f.dataFork.isEmpty and writeChanged("{dir}/{name}.data", f.dataFork): written += 1
		if writeChanged("{dir}/{name}.info", f.infoBytes()): written += 1
		if not f.resourceFork.isEmpty:
			if writeChanged("{dir}/{name}.rsrc", f.resourceFork): written += 1
			listResources(lines, f.resourceFork)
	if writeChanged("{dir}.tracks", moof.tracksBytes()): written += 1
	written

disksDir = args.option("--disks") ?? "projects/excel1/disks"
mut lines = []
mut written = 0
for name in (fs.list(disksDir) ?? fail("no disks at {disksDir}: {error}")).sorted():
	if name.endsWith(".moof"): written += prepareDisk("{disksDir}/{name}", lines)
if writeChanged("{assetsDir}/files.txt", "{lines.join("\n")}\n".bytes()): written += 1
print("{written} files written to {assetsDir}")

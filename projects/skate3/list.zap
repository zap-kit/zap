# Lists what the user's Skate 3 disc holds: every file of the image's XDVDFS tree with its size,
# or, given a BIG archive's path on the disc, the files inside it. Run from the repository root:
#
#   zap run projects/skate3/list.zap                                   the disc's files
#   zap run projects/skate3/list.zap data/content/worldDIST_University.big
#   zap run projects/skate3/list.zap --iso D:/skate3.iso ...           another image than projects/skate3/disc/*.iso

import ea
import skate
import xbox

disc = xbox.openUserDisc(args.option("--iso")) ?? fail
args.options([skate.isoOption])
if args.positional().find(.lower().endsWith(".big")) is archive:
	disc.listBig(archive)
	return
print("{disc.path}: game partition at 0x{disc.partition:X}, {disc.files.items.len} files")
mut total = 0
for f in disc.files.items:
	print("{f.size:>12}  {f.path}")
	total += f.size
print("{total} bytes in all")

fn listBig(disc xbox.Disc, path str):
	big = disc.openBig(path) ?? fail
	print("{path}: {big.entries.items.len} entries")
	for e in big.entries.items:
		print("{e.size:>12} {e.stored:>12} c{e.compression}  {e.path}")

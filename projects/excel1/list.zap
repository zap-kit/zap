# Lists a prepared code resource's 68000 instructions from the start, one after the other (no
# flow followed, so data between functions lists as instructions too). Run from the repository
# root after projects/excel1/prepare.zap:
#
#   zap run projects/excel1/list.zap "Excel Program/Microsoft Excel" CODE 1 [from hex offset]

import disk
import fs
import m68k

file = args[0] if not args.isEmpty else "Excel Program/Microsoft Excel"
kind = args[1] if args.len > 1 else "CODE"
id = arg(2, 1)
fork = fs.readBytes("projects/excel1/assets/{file}.rsrc") ?? fail("no prepared {file}: {error}")
resources = disk.readResources(fork) ?? fail
code = resources.find(.kind == kind and .id == id) ?? fail("no {kind} {id} in {file}")
mut at = i64.parse(args[3] if args.len > 3 else "") ?? (4 if kind == "CODE" else 0)
while at < code.bytes.len:
	i = m68k.decode(code.bytes, at)
	print("{at:05x}: {i.length} {i.text()}")
	at += i.length

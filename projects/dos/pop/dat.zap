# The .DAT files of DOS Prince of Persia (v1.4): a resource table at the offset the head gives,
# each resource a checksum byte and its bytes, as SDLPoP (David Nagy, GPL-3, seg009.c open_dat,
# load_from_opendats_metadata) reads them.

import fs

# where the DOS game is installed (the player's own copy, never committed)
pub defaultInstall = "C:/Games/Prince of Persia"

pub type Dat:
	name str
	resources {i64: u8[]}

	# a resource's bytes; none when the file has no such resource
	pub fn resource(id i64) ref u8[]?:
		resources.get(id)

	# a resource the game cannot do without
	pub fn need(id i64) ref u8[]:
		resources.get(id) ?? fail("{name} has no resource {id}")

# the bytes and their checksum byte add up to 0xFF
fn checksumHolds(file u8[], at i64, size i64):
	sum = 0
	for i in at..at + 1 + size:
		sum += file[i]
	sum & 0xFF == 0xFF

# every resource of a .DAT file's bytes
pub fn datOf(name str, file u8[]) Dat:
	if file.len < 6: fail("{name} is too short for a .DAT head")
	tableAt = i64(file.u32le(0))
	count = i64(file.u16le(tableAt))
	resources {i64: u8[]} = {}
	for i in 0..count:
		entry = tableAt + 2 + i * 8
		id = i64(file.u16le(entry))
		at = i64(file.u32le(entry + 2))
		size = i64(file.u16le(entry + 6))
		if at + 1 + size > file.len: fail("{name}: resource {id} runs past the end")
		if not checksumHolds(file, at, size): fail("{name}: resource {id} fails its checksum")
		resources[id] = file[at + 1..at + 1 + size].copy()
	Dat(name = name.copy(), resources)

# the .DAT file `name` of the install dir
pub fn loadDat(dir str, name str) Dat:
	file = fs.readBytes("{dir}/{name}") ?? fail("cannot read {dir}/{name}: {error}")
	datOf(name, file)

# a resource of the first of the files open that has it, as the game looks through the chain of
# files it opened (a guard's pictures in GUARD.DAT, their palette in GUARD1.DAT)
pub type DatChain = Dat[]

pub fn resource(chain DatChain, id i64) ref u8[]?:
	for i in 0..chain.len:
		if chain[i].resources.get(id) is b: return b
	none

pub fn need(chain DatChain, id i64) ref u8[]:
	chain.resource(id) ?? fail("no file open has resource {id}")

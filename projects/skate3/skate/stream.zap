# The streams a district of Skate 3's world is cut into (data/content/world/stream/<district>/ in
# the district's BIG): for each stream (Pres: what is drawn, Sim: what is touched, Tex: textures)
# an ATOC table of contents (<district>_<stream>.xst) and SFIL files, one per cell of the map and a
# global one (c<stream>_<x>_<z>_high.xsf), holding the assets. An asset is an RW4 arena (rw4/):
# its CPU part and its GPU part (the base resources), each stored raw or RefPack-compressed; an
# asset shared by cells is stored in each of them.
#
# ATOC (big-endian): "ATOC", version 3, ..., the count at 16, then 64-byte records from 24: the
# asset's 64-bit id, its processor, its total size, header size, alignment, GPU size (at 32) and
# type (at 36: 1 simulation, 4 model, 0x1000 texture).
# SFIL: "SFIL", the first asset's offset at 16; each asset then: its id, the stored size, the size
# of its header, the stride to the next asset; stored whole after its header, or as the sizes and
# compression of its CPU part (the words at 128..140) and its GPU part (160..172), their bytes from
# 208.

import ea

pub assetSimulation = 1
pub assetModel = 4
pub assetTexture = 0x1000

pub type AssetRecord:
	id i64
	total i64
	kind i64

# an asset of a stream: its record, and where its stored bytes are in the BIG
pub type StreamAsset:
	id i64
	kind i64
	total i64
	entry i64   # the SFIL file: an index of the BIG's entries
	at i64   # the asset's header in that file

pub type Stream:
	assets StreamAsset[]   # in the order of the table of contents

# The records of an ATOC table, or why it cannot be read.
pub fn readAtoc(d u8[]) AssetRecord[] ? str:
	if not d.startsWith("ATOC") or d.u32be(4) != 3: return "not an ATOC table of version 3"
	count = i64(d.u32be(16))
	if 24 + count * 64 != d.len: return "an ATOC table of {d.len} bytes for {count} records"
	out = []
	for i in 0..count:
		r = 24 + i * 64
		out.push(
			AssetRecord(
				id = d.i64be(r),
				total = d.u32be(r + 12),
				kind = d.u32be(r + 36)
			)
		)
	out

# The stream `name` (Pres, Sim, Tex) of the district whose files are in the BIG, each asset found
# in the first cell that holds it; or why it cannot be read.
pub fn openStream(big ea.Big, district str, name str) Stream ? str:
	dir = "data/content/world/stream/{district}"
	records = try readAtoc(try big.readBigFile("{dir}/{district}_{name}.xst"))
	byId {i64: i64} = {}
	for i in 0..records.len:
		byId[records[i].id] = i
	found = fill(records.len, false)
	where = records.map(r:
		StreamAsset(id = r.id, kind = r.kind, total = r.total, entry = -1, at = 0)
	)
	prefix = "{dir}/c{name}_".lower()
	files = []
	for k, e in big.entries.items:
		lower = e.path.lower()
		if lower.startsWith(prefix) and lower.endsWith(".xsf"):
			files.push(k)
	for f in files.sortedBy(big.entries.items[it].path):
		path = big.entries.items[f].path
		d = try big.readBigEntry(big.entries.items[f])
		if not d.startsWith("SFIL"): return "{path} is not an SFIL stream"
		at = i64(d.u32be(16))
		first = at
		while at + 208 <= d.len:
			id = d.i64be(at)
			stride = i64(d.u32be(at + 16))
			if id == 0 and stride == 0: break
			i = byId.get(id) ??
				return "{path}: asset {ea.hex64(id)} is not in the table of contents"
			if not found[i]:
				found[i] = true
				where[i].entry = f
				where[i].at = at
			if stride < first or stride % first != 0:
				return "{path}: asset {ea.hex64(id)} has a stride of {stride}"
			at += stride
	for i in 0..records.len:
		if not found[i]: return "{district} {name}: asset {ea.hex64(records[i].id)} is in no cell"
	Stream(assets = where)

# The bytes of an asset (its arena: the CPU part, then the GPU part), read from its SFIL file in
# `file` (that file's bytes); or why it cannot be.
pub fn assetBytes(file u8[], a StreamAsset) u8[] ? str:
	at = a.at
	stored = i64(file.u32be(at + 8))
	headerSize = i64(file.u32be(at + 12))
	if stored == a.total and headerSize >= 128:
		whole = []
		whole.extend(file[at + headerSize..at + headerSize + stored])
		return whole
	cpuSize = i64(file.u32be(at + 128))
	cpuStored = i64(file.u32be(at + 132))
	cpuPacking = file.u32be(at + 136)
	gpuSize = i64(file.u32be(at + 160))
	gpuStored = i64(file.u32be(at + 164))
	gpuPacking = file.u32be(at + 168)
	if stored != 0x50 + cpuStored + gpuStored or cpuSize + gpuSize != a.total or
		at + 208 + cpuStored + gpuStored > file.len:
		return "asset {ea.hex64(a.id)} has inconsistent sizes"
	out = []
	from = at + 208
	out.extend(try section(file, from, cpuSize, cpuStored, cpuPacking))
	out.extend(try section(file, from + cpuStored, gpuSize, gpuStored, gpuPacking))
	if out.len != a.total: return "asset {ea.hex64(a.id)} gave {out.len} of {a.total} bytes"
	out

fn section(file u8[], at i64, size i64, stored i64, packing i64) u8[] ? str:
	if size == 0:
		empty u8[] = []
		return empty
	bytes = file[at..at + stored]
	if packing == 0:
		out = []
		out.extend(bytes)
		return out
	if packing == 1: return ea.unpackRefPack(bytes, size)
	"an asset section packed with method {packing}"

# A texture arena: its Texture object (0x000200E8, 52 bytes: seven words of the D3D resource,
# then the GPU's texture fetch constant at 28), the texels in the base resource before it, and
# the table of contents naming it ("0x<id>.Texture", the 64-bit id materials refer to it by).

import image
import xbox

pub type ArenaTexture:
	id i64   # from the table of contents, 0 when it has none
	name str
	fetch xbox.TextureFetch
	image image.Image?   # none when its format is not read

# The textures of an arena (most hold one), decoded.
pub fn arenaTextures(a Arena) ArenaTexture[]:
	names = a.tableOfContents()
	out = []
	lastResource = -1
	for i in 0..a.entries.len:
		e = a.entries[i]
		if e.kind == typeBaseResource:
			lastResource = i
		if e.kind != typeTexture: continue
		fetch = xbox.readFetch(a.bytes, e.at + 28)
		id = 0
		name = ""
		for n in names:
			if n.object == i:
				id = n.id
				name = n.name.copy()
		from = a.entries[lastResource].at if lastResource >= 0 else a.resourceBase
		out.push(ArenaTexture(id, name, fetch, image = fetch.decodeTexture(a.bytes, from)))
	out

# an entry of an arena's table of contents: a name, a 64-bit id, the object it names
pub type TocName:
	name str
	id i64
	kind i64   # a hash of the object's kind
	object i64

# The arena's table of contents (0x00EB000B): a count, the entries' offset, then 24-byte entries
# of a name offset, a word, the id, a kind and the object's dictionary index.
pub fn tableOfContents(a Arena) TocName[]:
	out = []
	for k in a.objectsOf(typeTableOfContents):
		at = a.entries[k].at
		count = a.bytes.u32be(at)
		entries = i64(a.bytes.u32be(at + 4))
		for i in 0..count:
			e = at + entries + i * 24
			if e + 24 > a.bytes.len: break
			nameAt = i64(a.bytes.u32be(e))
			out.push(
				TocName(
					name = a.bytes.cStringAt(at + nameAt, 256),
					id = a.bytes.i64be(e + 8),
					kind = a.bytes.u32be(e + 16),
					object = a.bytes.u32be(e + 20)
				)
			)
	out

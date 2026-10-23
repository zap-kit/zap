# The fields of a record's data: a type of four letters, a u16 size, the data. A field XXXX
# carries in its u32 the size of the field after it, whose own size is then 0.

pub type Field:
	tag str
	at i64
	size i64

pub fn fieldsOf(body u8[]) Field[]:
	out = []
	at = 0
	big = -1
	while at + 6 <= body.len:
		tag = str(body[at..at + 4])
		size = i64(body.u16le(at + 4))
		if tag == "XXXX":
			big = body.u32le(at + 6)
			at += 10
			continue
		if big >= 0:
			size = big
			big = -1
		out.push(Field(tag, at = at + 6, size))
		at += 6 + size
	out

# the offset of the data of the first field with this tag, or none
pub fn dataOf(fields Field[], tag str) i64?:
	for f in fields:
		if f.tag == tag: return f.at
	none

# the NUL-ended text of the first field with this tag, or "" when there is none
pub fn textOf(body u8[], fields Field[], tag str) str:
	at = dataOf(fields, tag) ?? return ""
	body.cStringAt(at)

# the form ids of every field with this tag, in order: a field of one (PKID, TCLT) or an array of
# them (KWDA)
pub fn formsOf(body u8[], fields Field[], tag str) i64[]:
	out = []
	for f in fields:
		if f.tag != tag: continue
		for k in 0..f.size / 4:
			out.push(i64(body.u32le(f.at + k * 4)))
	out

# the bytes of the first field with this tag, empty when there is none
pub fn bytesOf(body u8[], fields Field[], tag str) u8[]:
	f = fields.find(.tag == tag) ?? return []
	body[f.at..f.at + f.size].copy()

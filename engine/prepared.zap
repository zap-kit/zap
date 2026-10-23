# The files a game prepares once from the player's install and then only reads: packed by
# PackedParts.pack under the game's magic and the format's version, the head (a Zap value,
# toBytes) then the body, the bytes the head's spans point into (pixels as the GPU takes them,
# vertices laid out as the GPU reads them), sent to the GPU without being read value by value. A
# file of another version is not read: the game prepares again.

import fs

# where a run of bytes lies in the body
pub type Span:
	at i64
	len i64

# a prepared file read: its bytes and where its head and body lie in them
pub type Prepared:
	file u8[]
	parts PackedParts

pub fn headOf(p Prepared) ref u8[]:
	p.file[p.parts.headAt..p.parts.bodyAt]

pub fn bodyOf(p Prepared) ref u8[]:
	p.file[p.parts.bodyAt..p.parts.end]

# the body grown by `part`: where it lies
pub fn append(mut body u8[], part u8[]) Span:
	at = body.len
	body.extend(part)
	Span(at, len = part.len)

# the bytes of a span of the body
pub fn bytesAt(body u8[], s Span) ref u8[]:
	body[s.at..s.at + s.len]

# the file written, its dir made first
pub fn writePreparedFile(
	path str,
	magic str,
	version i64,
	head u8[],
	body u8[]
) ? fs.Error:
	_ = fs.createDir(fs.dirOf(path))
	# written beside it, then moved: a reader meanwhile finds the old file or the new one whole
	beside = "{path}.part"
	try fs.writeBytes(beside, PackedParts.pack(magic, version, head, body))
	try fs.moveFile(beside, path)

# the file read, none when it is missing, not of this magic, or of another version; `body` false
# reads the head alone (the body is empty), for what needs no more
pub fn readPreparedFile(path str, magic str, version i64, body bool = true) Prepared?:
	if not body: return readPreparedHead(path, magic, version)
	file = fs.readBytes(path) ?? return none
	parts = try file.unpack(magic, version)
	Prepared(file, parts)

fn readPreparedHead(path str, magic str, version i64) Prepared?:
	file = fs.open(path) ?? return none
	prefix = file.readAt(0, 16) ?? return none
	if prefix.len < 16 or not prefix.startsWith(magic) or prefix.u32le(4) != version: return none
	bodyAt = 16 + prefix.i64le(8)
	head = file.readAt(0, bodyAt) ?? return none
	Prepared(head, PackedParts(headAt = 16, bodyAt, end = bodyAt))

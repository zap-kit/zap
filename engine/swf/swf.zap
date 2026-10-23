# SWF movies read in Zap (Adobe's SWF file format specification v19; Scaleform's GFX tags as the
# JPEXS Free Flash Decompiler reads them): the header ("FWS" plain, "CWS" zlib, "ZWS" LZMA, which
# is refused; Scaleform's "GFX" and "CFX" the same two), the stage's size, the frame rate and the
# tags, each a code and a length (long form past 62 bytes). The definitions go into an index of
# characters by id, the main timeline's control tags into its frames (timeline.zap); tags.zap
# reads each tag. Tags not known are passed over and counted, never a failure. The drawer
# (draw.zap) plays the display list on the engine. `import engine.swf`, then
# `movie = swf.readSwf(bytes) ?? fail(error)`.

import deflate

# an asset taken from another movie
pub type Import:
	url str   # the movie the asset comes from
	name str   # its exported name
	id i64   # the id it takes in this movie

# DoInitAction: a sprite's ActionScript run once before its first use
pub type InitAction:
	sprite i64
	code u8[]   # ActionScript 2 bytecode, not run
	library i64 = 0   # the movie it came from (mergeLibrary), 0 this one

# Scaleform's ExporterInfo (tag 1000): the gfxexport that made the file
pub type ExporterInfo:
	version i64
	flags i64
	bitmapFormat i64
	prefix str
	swfName str

# a movie: its header, its characters by id and its main timeline
pub type Swf:
	signature str   # FWS, CWS, ZWS, GFX or CFX
	version i64
	stage Rect   # twips
	frameRate f32
	timeline Timeline
	background Vec4 = Vec4(1.0, 1.0, 1.0, 1.0)
	kinds {i64: i64} = {}   # every character's id to the tag that defined it
	shapes {i64: Shape} = {}
	sprites {i64: Sprite} = {}
	bitmaps {i64: Bitmap} = {}
	externalImages {i64: ExternalImage} = {}
	subImages {i64: SubImage} = {}
	fonts {i64: Font} = {}
	texts {i64: StaticText} = {}
	editTexts {i64: EditText} = {}
	buttons {i64: Button} = {}
	scalingGrids {i64: Rect} = {}   # DefineScalingGrid: a character's nine-slice centre
	exports {str: i64} = {}
	linkages {i64: str} = {}   # a character to the name it is exported by, merged libraries' too
	libraryOf {i64: i64} = {}   # a merged library's character to its library's number (from 1)
	libraryCount i64 = 0
	imports Import[] = []
	initActions InitAction[] = []
	jpegTables u8[] = []
	exporter ExporterInfo? = none
	tagCounts {i64: i64} = {}   # every tag's code to how many the file has
	unknown {i64: i64} = {}   # the codes not known, passed over
	problems str[] = []   # tags cut short or running past their end

# the movie in a file's bytes, or why it cannot be read
pub fn readSwf(bytes u8[]) Swf ? str:
	if bytes.len < 8: return "too short for a SWF"
	signature = str(bytes[..3].copy())
	if signature not in ["FWS", "CWS", "ZWS", "GFX", "CFX"]:
		return "not a SWF (FWS, CWS, ZWS, GFX or CFX)"
	if signature == "ZWS": return "an LZMA-compressed SWF is not read"
	length = i64(bytes.u32le(4))
	d u8[] = bytes[..8].copy()
	if signature == "CWS" or signature == "CFX":
		d.extend(try deflate.inflateZlib(bytes[8..], length - 8))
	else:
		d.extend(bytes[8..])
	r = newReader(d, 8, d.len)
	stage = r.rect()
	frameRate = f32(r.u16()) / 256.0
	frameCount = r.u16()
	if r.short: return "the SWF header is cut short"
	s = Swf(signature, version = bytes[3], stage, frameRate,
		timeline = Timeline(frameCount, frames = []))
	t = Timeline(frameCount, frames = [])
	s.readTags(d, r.at, d.len, t)
	s.timeline = t
	s

# the tags from `start` to `end` into the index and into the timeline t (the main one, or a
# sprite's)
fn readTags(mut s Swf, d ref u8[], start i64, end i64, mut t Timeline):
	at = start
	frame = Frame()
	while at + 2 <= end:
		head = i64(d.u16le(at))
		code = head >> 6
		length = head & 63
		at += 2
		if length == 63:
			if at + 4 > end: break
			length = d.u32le(at)
			at += 4
		if at + length > end:
			s.problems.push("tag {code} at {at} runs past the end")
			length = end - at
		s.tagCounts[code] = (s.tagCounts.get(code) ?? 0) + 1
		if code == 0: break
		r = newReader(d, at, at + length)
		s.readTag(code, r, t, frame)
		if r.short: s.problems.push("{tagName(code)} at {at} is cut short")
		at += length
	if not frame.commands.isEmpty or not frame.actions.isEmpty or not frame.label.isEmpty:
		t.frames.push(frame)

# DefineSprite (tag 39): its frames read as a timeline of its own
fn readSprite(mut s Swf, mut r TagReader):
	id = r.u16()
	t = Timeline(frameCount = r.u16(), frames = [])
	s.readTags(r.d, r.at, r.end, t)
	r.at = r.end
	s.kinds[id] = 39
	s.sprites[id] = Sprite(id, timeline = t)

# ExportAssets (56), ImportAssets (57) or ImportAssets2 (71)
fn readAssets(mut s Swf, mut r TagReader, code i64):
	if code == 56:
		loop r.u16():
			id = r.u16()
			name = r.text()
			if s.linkages.get(id) == none: s.linkages[id] = name.copy()
			s.exports[name] = id
		return
	url = r.text()
	if code == 71: r.u16()   # two reserved bytes
	loop r.u16():
		id = r.u16()
		s.imports.push(Import(url = url.copy(), name = r.text(), id))

fn readExporterInfo(mut r TagReader):
	version = r.u16()
	flags = r.u32() if version >= 0x10A else 0
	ExporterInfo(
		version,
		flags,
		bitmapFormat = r.u16(),
		prefix = r.shortText(),
		swfName = r.shortText()
	)

fn readExternalImage(mut r TagReader, code i64):
	id = r.u16()
	if code == 1009: r.u16()   # the id's kind
	format = r.u16()
	width = r.u16()
	height = r.u16()
	exportName = r.shortText()
	fileName = r.shortText() if r.remaining() > 0 else ""
	ExternalImage(id, format, width, height, exportName, fileName)

fn readSubImage(mut r TagReader):
	SubImage(id = r.u16(), image = r.u16(), x0 = r.u16(), y0 = r.u16(), x1 = r.u16(), y1 = r.u16())

# the id an exported name has in a library of the movie (0 the movie itself), else in any; none
# when nothing is exported by it
pub fn exported(s Swf, name str, library i64) i64?:
	for id in s.linkages.keys():
		if s.linkages[id] == name and (s.libraryOf.get(id) ?? 0) == library: return id
	s.exports.get(name)

# the stage's size in pixels
pub fn stageSize(s Swf) Vec2:
	Vec2((s.stage.xmax - s.stage.xmin) / 20.0, (s.stage.ymax - s.stage.ymin) / 20.0)

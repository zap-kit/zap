# long: the tag table and its dispatch, one line per tag
#
# The tags known, by code (SWF specification v19 and Scaleform's 1000 to 1009), and what reading
# each does: definitions go into the movie's index, control tags into the timeline being read,
# the rest is passed over by its length.

names = [
	(0, "End"), (1, "ShowFrame"), (2, "DefineShape"), (4, "PlaceObject"), (5, "RemoveObject"),
	(6, "DefineBits"), (7, "DefineButton"), (8, "JPEGTables"), (9, "SetBackgroundColor"),
	(10, "DefineFont"), (11, "DefineText"), (12, "DoAction"), (13, "DefineFontInfo"),
	(14, "DefineSound"), (15, "StartSound"), (17, "DefineButtonSound"), (18, "SoundStreamHead"),
	(19, "SoundStreamBlock"), (20, "DefineBitsLossless"), (21, "DefineBitsJPEG2"),
	(22, "DefineShape2"), (23, "DefineButtonCxform"), (24, "Protect"), (26, "PlaceObject2"),
	(28, "RemoveObject2"), (32, "DefineShape3"), (33, "DefineText2"), (34, "DefineButton2"),
	(35, "DefineBitsJPEG3"), (36, "DefineBitsLossless2"), (37, "DefineEditText"),
	(39, "DefineSprite"), (41, "ProductInfo"), (43, "FrameLabel"), (45, "SoundStreamHead2"),
	(46, "DefineMorphShape"), (48, "DefineFont2"), (56, "ExportAssets"), (57, "ImportAssets"),
	(58, "EnableDebugger"), (59, "DoInitAction"), (60, "DefineVideoStream"), (61, "VideoFrame"),
	(62, "DefineFontInfo2"), (63, "DebugID"), (64, "EnableDebugger2"), (65, "ScriptLimits"),
	(66, "SetTabIndex"), (69, "FileAttributes"), (70, "PlaceObject3"), (71, "ImportAssets2"),
	(73, "DefineFontAlignZones"), (74, "CSMTextSettings"), (75, "DefineFont3"),
	(76, "SymbolClass"), (77, "Metadata"), (78, "DefineScalingGrid"), (82, "DoABC"),
	(83, "DefineShape4"), (84, "DefineMorphShape2"), (86, "DefineSceneAndFrameLabelData"),
	(87, "DefineBinaryData"), (88, "DefineFontName"), (89, "StartSound2"), (90, "DefineBitsJPEG4"),
	(91, "DefineFont4"), (1000, "ExporterInfo"), (1001, "DefineExternalImage"),
	(1002, "FontTextureInfo"), (1003, "DefineExternalGradient"), (1004, "DefineGradientMap"),
	(1005, "DefineCompactedFont"), (1006, "DefineExternalSound"),
	(1007, "DefineExternalStreamSound"), (1008, "DefineSubImage"), (1009, "DefineExternalImage2")
]

# the tag's name, "Tag<code>" for one not known
pub fn tagName(code i64) str:
	for (c, name) in names:
		if c == code: return name.copy()
	"Tag{code}"

# whether the code is in the table of tags
pub fn isKnownTag(code i64) bool:
	for (c, _) in names:
		if c == code: return true
	false

# one tag read into the movie and the timeline t, whose frame being built is `frame`
fn readTag(mut s Swf, code i64, mut r TagReader, mut t Timeline, mut frame Frame):
	if code == 1:
		t.frames.push(move frame)
	elif code in [2, 22, 32, 83]:
		s.addShape(
			r.readShape(1 if code == 2 else 2 if code == 22 else 3 if code == 32 else 4),
			code
		)
	elif code in [4, 26, 70]:
		frame.commands.push(.Place(r.readPlace(1 if code == 4 else 2 if code == 26 else 3)))
	elif code == 5 or code == 28:
		frame.commands.push(.Remove(r.readRemove(1 if code == 5 else 2)))
	elif code in [6, 20, 21, 35, 36, 90]:
		s.addBitmap(r, code)
	elif code == 7 or code == 34:
		s.addButton(r.readButton(1 if code == 7 else 2), code)
	elif code == 8:
		s.jpegTables = r.rest()
	elif code == 9:
		s.background = r.rgb()
	elif code == 11 or code == 33:
		s.addText(r.readText(1 if code == 11 else 2), code)
	elif code == 12:
		frame.actions.push(r.rest())
	elif code == 37:
		s.addEditText(r.readEditText())
	elif code == 39:
		s.readSprite(r)
	elif code == 43:
		frame.label = r.text()
	elif code == 48 or code == 75:
		s.addFont(r.readFont(2 if code == 48 else 3), code)
	elif code in [56, 57, 71]:
		s.readAssets(r, code)
	elif code == 59:
		sprite = r.u16()
		s.initActions.push(InitAction(sprite, code = r.rest()))
	elif code == 78:
		id = r.u16()
		s.scalingGrids[id] = r.rect()
	elif code == 88:
		s.nameFont(r.readFontName())
	elif code == 1000:
		s.exporter = r.readExporterInfo()
	elif code == 1001 or code == 1009:
		s.addExternalImage(r.readExternalImage(code), code)
	elif code == 1008:
		s.addSubImage(r.readSubImage())
	elif not isKnownTag(code):
		s.unknown[code] = (s.unknown.get(code) ?? 0) + 1
	r.at = r.end

fn addShape(mut s Swf, move shape Shape, code i64):
	s.kinds[shape.id] = code
	s.shapes[shape.id] = shape

fn addBitmap(mut s Swf, mut r TagReader, code i64):
	id = r.u16()
	s.kinds[id] = code
	s.bitmaps[id] = Bitmap(id, tag = code, data = r.rest())

fn addButton(mut s Swf, move b Button, code i64):
	s.kinds[b.id] = code
	s.buttons[b.id] = b

fn addText(mut s Swf, move text StaticText, code i64):
	s.kinds[text.id] = code
	s.texts[text.id] = text

fn addEditText(mut s Swf, move text EditText):
	s.kinds[text.id] = 37
	s.editTexts[text.id] = text

fn addFont(mut s Swf, move font Font, code i64):
	s.kinds[font.id] = code
	s.fonts[font.id] = font

fn nameFont(mut s Swf, move named (i64, str)):
	id, name = named
	if s.fonts.get(id) is f:
		if f.name.isEmpty: s.fonts[id].name = name.copy()

fn addExternalImage(mut s Swf, move img ExternalImage, code i64):
	s.kinds[img.id] = code
	s.externalImages[img.id] = img

fn addSubImage(mut s Swf, move img SubImage):
	s.kinds[img.id] = 1008
	s.subImages[img.id] = img

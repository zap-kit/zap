# An app's AndroidManifest.xml as Android reads it from the APK: binary XML (the chunks of
# frameworks/base's ResourceTypes.h: a string pool, the attributes' resource ids, the namespace,
# then each element's start and end). The app is the framework's NativeActivity, no code of Java
# (hasCode false), the program its library libmain.so (android.app.lib_name), started from the
# launcher.

# the app's oldest Android (7.0: APK Signature Scheme v2, which signs it) and the one it targets
appMinSdk = 24
appTargetSdk = 35

androidUri = "http://schemas.android.com/apk/res/android"

# an attribute: its name, its resource id (android's; 0 for one of no namespace), and its value: a
# text, else a number (kind 0x10, an integer) or a truth (0x12)
type XmlAttr:
	name str
	id i64
	kind i64
	text str
	number i64

# an element's start (its attributes) or, with none and end, its end
type XmlEvent:
	name str
	attrs XmlAttr[]
	end bool = false

fn text(name str, id i64, value str):
	XmlAttr(name.copy(), id, 3, value.copy(), 0)

fn number(name str, id i64, value i64):
	XmlAttr(name.copy(), id, 0x10, "", value)

fn reference(name str, id i64, value i64):
	XmlAttr(name.copy(), id, 1, "", value)

fn truth(name str, id i64, value bool):
	XmlAttr(name.copy(), id, 0x12, "", -1 if value else 0)

# android's attributes' resource ids (frameworks/base/core/res/res/values/public.xml)
attrTheme = 0x0101_0000
attrLabel = 0x0101_0001
attrIcon = 0x0101_0002
attrName = 0x0101_0003
attrHasCode = 0x0101_000C
attrExported = 0x0101_0010
attrScreenOrientation = 0x0101_001E
attrConfigChanges = 0x0101_001F
attrValue = 0x0101_0024
attrMinSdk = 0x0101_020C
attrVersionCode = 0x0101_021B
attrTargetSdk = 0x0101_0270

fn opening(name str, attrs XmlAttr[]):
	XmlEvent(name.copy(), attrs.copy())

fn closing(name str):
	XmlEvent(name.copy(), [], end = true)

# The activity: wide, as a game is (sensorLandscape, either way up), and kept through a turn of
# the device, a keyboard plugged or a resize (configChanges: orientation, keyboard, keyboardHidden,
# navigation, screenLayout, uiMode, screenSize, smallestScreenSize), which would otherwise end it
# and make it anew.
landscape = 6
keptThrough = 0xFF0

# its theme: no title and no status bar over the picture (Theme.NoTitleBar.Fullscreen)
fullscreenTheme = 0x0103_000A

# the manifest of the app of this package and label, its icon resources.zap's when it has one, as
# its elements' starts and ends
fn manifestEvents(package str, label str, icon bool):
	application = [text("label", attrLabel, label), truth("hasCode", attrHasCode, false)]
	if icon: application.push(reference("icon", attrIcon, appIconId))
	[
		opening("manifest", [text("package", 0, package), number("versionCode", attrVersionCode, 1)]),
		opening("uses-sdk", [number("minSdkVersion", attrMinSdk, appMinSdk), number("targetSdkVersion", attrTargetSdk, appTargetSdk)]),
		closing("uses-sdk"),
		opening("application", application),
		opening(
			"activity",
			[
				reference("theme", attrTheme, fullscreenTheme),
				text("name", attrName, "android.app.NativeActivity"),
				truth("exported", attrExported, true),
				number("screenOrientation", attrScreenOrientation, landscape),
				number("configChanges", attrConfigChanges, keptThrough)
			]
		),
		opening("meta-data", [text("name", attrName, "android.app.lib_name"), text("value", attrValue, "main")]),
		closing("meta-data"),
		opening("intent-filter", []),
		opening("action", [text("name", attrName, "android.intent.action.MAIN")]),
		closing("action"),
		opening("category", [text("name", attrName, "android.intent.category.LAUNCHER")]),
		closing("category"),
		closing("intent-filter"),
		closing("activity"),
		closing("application"),
		closing("manifest")
	]

# The binary XML of the events: android's attribute names first in the string pool (the resource
# map gives their ids), the attributes of each element in the order of their ids
fn binaryXml(events XmlEvent[]):
	ids {str: i64} = {}
	for e in events:
		for at in e.attrs:
			if at.id != 0: ids[at.name.copy()] = at.id
	pool = StringPool()
	for name in ids.keys().sortedBy(ids.get(it) ?? 0):
		pool.add(name)
	pool.add("android")
	pool.add(androidUri)
	for e in events:
		pool.add(e.name)
		for at in e.attrs:
			pool.add(at.name)
			if at.kind == 3: pool.add(at.text)
	body = []
	body.extend(stringPool(pool.strings))
	resources = []
	for s in pool.strings[..ids.len]:
		resources.pushU32le(ids.get(s) ?? 0)
	body.extend(xmlChunk(0x180, 8, resources))
	body.extend(namespaceChunk(0x100, pool.place("android"), pool.place(androidUri)))
	for e in events:
		element = []
		element.pushU32le(1)   # the line
		element.pushU32le(0xFFFF_FFFF)   # no comment
		element.pushU32le(0xFFFF_FFFF)   # no namespace
		element.pushU32le(pool.place(e.name))
		if e.end:
			body.extend(xmlChunk(0x103, 16, element))
			continue
		for half in [20, 20, e.attrs.len, 0, 0, 0]:   # where the attributes start, their size, count
			element.pushU16le(half)
		for at in e.attrs.sortedBy(.id):
			element.pushU32le(0xFFFF_FFFF if at.id == 0 else pool.place(androidUri))
			element.pushU32le(pool.place(at.name))
			element.pushU32le(pool.place(at.text) if at.kind == 3 else 0xFFFF_FFFF)
			element.pushU16le(8)   # Res_value's size
			element.push(0)
			element.push(u8(at.kind))
			element.pushU32le(pool.place(at.text) if at.kind == 3 else at.number & 0xFFFF_FFFF)
		body.extend(xmlChunk(0x102, 16, element))
	body.extend(namespaceChunk(0x101, pool.place("android"), pool.place(androidUri)))
	xmlChunk(3, 8, body)

# the strings in the order they were added, each once, and where each is
type StringPool:
	strings str[] = []
	at {str: i64} = {}

	fn add(s str):
		if at.get(s) == none:
			at[s.copy()] = strings.len
			strings.push(s.copy())

	# where the string is in the pool
	fn place(s str):
		at.get(s) ?? 0

# a chunk: its type, its header's size and its whole size, then the rest of its header and its
# content
fn xmlChunk(kind i64, headerSize i64, rest u8[]):
	out = []
	out.pushU16le(kind)
	out.pushU16le(headerSize)
	out.pushU32le(8 + rest.len)
	out.extend(rest)
	out

fn namespaceChunk(kind i64, prefix i64, uri i64):
	rest = []
	for word in [1, 0xFFFF_FFFF, prefix, uri]:
		rest.pushU32le(word)
	xmlChunk(kind, 16, rest)

# the strings in UTF-16, each its length first and a zero after
fn stringPool(strings str[]):
	chars = []
	offsets = []
	for s in strings:
		offsets.pushU32le(chars.len)
		units = []
		for c in s.chars():
			code = c.charCode()
			if code < 0x1_0000:
				units.push(code)
			else:   # a surrogate pair
				units.push(0xD800 + ((code - 0x1_0000) >> 10))
				units.push(0xDC00 + ((code - 0x1_0000) & 0x3FF))
		chars.pushU16le(units.len)
		for u in units:
			chars.pushU16le(u)
		chars.pushU16le(0)
	while chars.len % 4 != 0:
		chars.push(0)
	rest = []
	for word in [strings.len, 0, 0, 28 + offsets.len, 0]:   # strings, styles, flags, where they start
		rest.pushU32le(word)
	rest.extend(offsets)
	rest.extend(chars)
	xmlChunk(1, 28, rest)

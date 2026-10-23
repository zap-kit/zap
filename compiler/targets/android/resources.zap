# An app's resources.arsc, when it has an icon (--icon): a table of one package (0x7f) of one type
# (drawable) of two entries, `icon` and `picture`, whose values are paths of files the APK carries
# (frameworks/base's ResourceTypes.h: ResTable, ResTable_package, ResTable_typeSpec,
# ResTable_type). `picture` is the PNG, density-free so the launcher scales it; `icon`, which the
# manifest names, is the PNG itself before Android 8 and from it an adaptive icon whose background
# is the picture, so it fills the launcher's shape instead of sitting small in a white one.

appPicturePath = "res/drawable-nodpi-v4/picture.png"
appAdaptivePath = "res/drawable-anydpi-v26/icon.xml"
appIconId = 0x7F01_0000   # package 0x7f, type 1, entry 0
appPictureId = 0x7F01_0001

# ResTable_config: its size, where its density and its oldest Android are in it, and the densities
configBytes = 64
configDensityAt = 14
configSdkAt = 24
densityNone = 0xFFFF
densityAny = 0xFFFE
configChanges = 0x0500   # what the icon's configurations differ by: density and version
noEntry = 0xFFFF_FFFF

# android:drawable, and @android:color/transparent
attrDrawable = 0x0101_0199
transparent = 0x0106_000D

# the adaptive icon's XML: the picture behind, nothing in front
fn adaptiveIconXml():
	binaryXml([
		opening("adaptive-icon", []),
		opening("background", [reference("drawable", attrDrawable, appPictureId)]),
		closing("background"),
		opening("foreground", [reference("drawable", attrDrawable, transparent)]),
		closing("foreground"),
		closing("adaptive-icon")
	])

fn resourceTable(package str):
	rest = []
	rest.pushU32le(1)   # packages
	rest.extend(stringPool([appPicturePath, appAdaptivePath]))
	rest.extend(resourcePackage(package))
	xmlChunk(2, 12, rest)

# the package: its id and name, its types' and keys' names, the drawable type's spec and its two
# configurations
fn resourcePackage(package str):
	types = stringPool(["drawable"])
	keys = stringPool(["icon", "picture"])
	headerBytes = 288
	rest = []
	rest.pushU32le(0x7F)
	name = []
	for c in package.bytes():
		name.pushU16le(c)
	while name.len < 256:
		name.push(0)
	rest.extend(name)
	for word in [headerBytes, 1, headerBytes + types.len, 2, 0]:   # where the names are, the last public, no id offset
		rest.pushU32le(word)
	rest.extend(types)
	rest.extend(keys)
	spec = [u8(1), 0, 0, 0]   # the type's id, no reserved bits
	spec.pushU32le(2)   # its entries
	spec.pushU32le(configChanges)
	spec.pushU32le(0)
	rest.extend(xmlChunk(0x202, 16, spec))
	rest.extend(resourceType(densityNone, 4, [0, 0]))
	rest.extend(resourceType(densityAny, 26, [1, -1]))
	xmlChunk(0x200, headerBytes, rest)

# The drawable type in one configuration (a density, an oldest Android): each entry's value a
# string of the table's pool, or none (-1).
fn resourceType(density i64, sdk i64, values i64[]):
	headerBytes = 20 + configBytes
	rest = [u8(1), 0, 0, 0]
	rest.pushU32le(values.len)
	rest.pushU32le(headerBytes + 4 * values.len)   # where the entries start, past their offsets
	config = fill(configBytes, u8(0))
	config.setU32le(0, u32(configBytes))
	config.setU16le(configDensityAt, u16(density))
	config.setU16le(configSdkAt, u16(sdk))
	rest.extend(config)
	at = 0
	for v in values:
		rest.pushU32le(noEntry if v < 0 else at)
		if v >= 0: at += 16
	for i, v in values:
		if v < 0: continue
		for half in [8, 0]:   # ResTable_entry: its size, no flags
			rest.pushU16le(half)
		rest.pushU32le(i)   # its key
		rest.pushU16le(8)   # Res_value: its size, a string of the pool
		rest.push(0)
		rest.push(3)
		rest.pushU32le(v)
	xmlChunk(0x201, headerBytes, rest)

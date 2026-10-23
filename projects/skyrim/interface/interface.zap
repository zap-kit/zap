# Skyrim's interface: the Scaleform menus of "Skyrim - Interface.bsa" (interface/*.swf and the
# GFX-wrapped interface/exported/*.gfx), read with the engine's SWF reader and played with their
# ActionScript by the engine's AVM1 (engine/swf/avm1), as the game shows them: the fonts of
# interface/fontconfig.txt, the "$KEY" texts of interface/translate_english.txt, and
# the safe zone of the ini's [Interface] fSafeZoneX and fSafeZoneY.

import engine.swf
import engine.swf.avm1
import skyrim.bsa
import skyrim

# fSafeZoneX and fSafeZoneY: no ini of the install sets them, so the executable's defaults
safeZone = 15.0

# the movie with this key in the install ("interface/hudmenu.swf"), or why it cannot be had
pub fn openMovie(install skyrim.Install, key str) swf.Swf ? str:
	bytes = install.installRead(key) ?? return "{key} is in no archive"
	swf.readSwf(bytes) ?? return "{key}: {error}"

# the keys of every movie of the interface
pub fn movieKeys(install skyrim.Install) str[]:
	install.installFind("interface/").filter(.endsWith(".swf") or .endsWith(".gfx"))

# A menu's scene: the movie with the font libraries and face map of interface/fontconfig.txt,
# whose library paths ("Interface\fonts_en.swf") are keys of the archives once folded.
pub fn openScene(install skyrim.Install, key str) swf.Scene ? str:
	movie = try install.openMovie(key)
	install.mergeLibraries(movie, 0)
	scene = swf.newScene(movie)
	text = install.installRead("interface/fontconfig.txt") ?? return scene
	config = swf.readFontConfig(str(move text))
	for lib in config.libraries:
		match install.openMovie(bsa.bsaKey(lib.bytes())):
			movie: scene.libraries.push(movie)
			error: eprint("font library skipped: {error}")
	scene.fontMap = config.map
	scene

# The movies the movie imports from merged into it ("Inventory components/InventoryLists.swf" is
# interface/inventory components/inventorylists.swf), theirs first; the font libraries' faces
# come from the font map instead.
fn mergeLibraries(install skyrim.Install, mut movie swf.Swf, depth i64):
	urls str[] = []
	for i in movie.imports:
		if i.url not in urls and not i.url.lower().endsWith("gfxfontlib.swf"):
			urls.push(i.url.copy())
	libs = []
	for url in urls:
		match install.openMovie(bsa.bsaKey("interface/{url}".bytes())):
			lib: libs.push(lib)
			error:
				eprint("library skipped: {error}")
				libs.push(swf.Swf(signature = "", version = 0, stage = swf.Rect(), frameRate = 1.0,
					timeline = swf.Timeline()))
	for k in 0..libs.len:
		if depth < 4: install.mergeLibraries(libs[k], depth + 1)
	for url in urls:
		movie.mergeLibrary(libs.remove(0), url)

# the translation file's "$KEY<tab>text" lines (UTF-16), empty without it
pub fn readTranslations(install skyrim.Install) {str: str}:
	out {str: str} = {}
	bytes = install.installRead("interface/translate_english.txt") ?? return out
	for line in str.fromUtf16(bytes).lines():
		parts = line.split("\t")
		if parts.len >= 2 and parts[0].startsWith("$"): out[parts[0].copy()] = parts[1].copy()
	out

# the menus the game fits whole into the window ("showAll"): at 1280x960 the tween menu's bottom
# bar stands at 824, where a whole 16:9 stage centered puts it
showAllMenus = ["interface/tweenmenu.swf"]

# A menu played in a window of width x height pixels, its first frame run, the stage stretched to
# the window as the game shows its menus ("exactFit": at 1280x960 the game's HUD meters and
# compass, the inventory's lists and bottom bar, the journal and the message and wait boxes are a
# third taller than at 16:9 and sit where an exact fit puts them, measured on the captures of
# assets/reference/), the tween menu fit whole.
pub fn openPlayer(install skyrim.Install, key str, width i64, height i64) avm1.Player ? str:
	scene = try install.openScene(key)
	mode = "showAll" if key in showAllMenus else "exactFit"
	view = avm1.Viewport(width, height, scaleMode = mode,
		safeX = safeZone, safeY = safeZone)
	program = avm1.newProgram(scene)
	program.translations = install.readTranslations()
	avm1.startPlayer(program, view)

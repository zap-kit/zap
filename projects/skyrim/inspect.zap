# Reads an interior cell of Skyrim's plugin and prints it: its lighting and water, each
# reference with its base record's type, editor id and model, and a count by type. Run from the
# repository root:
#
#   zap run projects/skyrim/inspect.zap                              the Sleeping Giant Inn
#   zap run projects/skyrim/inspect.zap WhiterunBanneredMare         another cell, by editor id
#   zap run projects/skyrim/inspect.zap --esm D:/Data/Skyrim.esm     another plugin file
#   zap run projects/skyrim/inspect.zap --install D:/Data             another install's Skyrim.esm

import skyrim
import skyrim.esm

fn showColor(c esm.Color):
	"({c.r} {c.g} {c.b})"

fn lightNote(b esm.Base):
	match b.light:
		l: " radius {l.radius} color {l.color.showColor()}"
		none: ""

args.options([ArgOption("--esm", true, "the plugin to read"), skyrim.installOption])
words = args.positional()
path = args.option("--esm") ??
	esm.pluginPath(args.option("--install") ?? esm.defaultData, "Skyrim.esm")
name = words[0] if not words.isEmpty else "RiverwoodSleepingGiantInn"
mut plugin = esm.openEsm(path.copy()) ?? fail
cell = plugin.findCell(name) ?? fail("no interior cell {name} in {path}")
print("{cell.editorId} {cell.formId:08X} flags 0x{cell.flags:X} template {cell.template:08X} image space {cell.imageSpace:08X}")
match plugin.imageSpaceOf(cell.imageSpace if cell.imageSpace != 0 else esm.defaultImageSpace):
	s: print("{s}")
	none: print("no image space")
match cell.lighting:
	l:
		print("ambient {l.ambient.showColor()} directional {l.directional.showColor()} fade {l.directionalFade:.2}")
		print("fog {l.fogNearColor.showColor()} near {l.fogNear:.0} far {l.fogFar:.0} far color {l.fogFarColor.showColor()} max {l.fogMax:.2} power {l.fogPower:.2} clip {l.fogClip:.0}")
		print("cube {l.ambientCube.map(.showColor())} specular {l.specular.showColor()} fresnel {l.fresnelPower:.2} rotation {l.directionalRotationXY} {l.directionalRotationZ}")
		print("light fade {l.lightFadeBegin:.0}..{l.lightFadeEnd:.0} inherits 0x{l.inherits:X}")
	none: print("no lighting of its own")
match cell.water:
	w: print("water at {w:.1}")
	none: print("no water")
print("{cell.refs.len} references")
kinds {str: i64} = {}
unresolved = 0
for r in cell.refs:
	label = "?"
	match plugin.baseRecord(r.base):
		b:
			label = b.kind.copy()
			print("{r.formId:08X} {b.kind} {b.editorId} {b.model} at {r.position.x:.1} {r.position.y:.1} {r.position.z:.1}{b.lightNote()}")
		none:
			unresolved += 1
			print("{r.formId:08X} ? base {r.base:08X}")
	kinds.add(label, 1)
for k in kinds.keys().sorted():
	print("{k}: {kinds.get(k) ?? 0}")
print("unresolved: {unresolved}")

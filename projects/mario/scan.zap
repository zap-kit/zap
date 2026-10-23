# What the cartridge's scripts say of Castle Grounds: its banks, models, objects and collision.
#   zap run projects/mario/scan.zap

import n64

rom, lv = n64.readCastleGrounds()
print("area geo {lv.areaGeo}, terrain {lv.terrain}, macros {lv.macros}")
print("mario at {lv.marioX} {lv.marioY} {lv.marioZ} yaw {lv.marioYaw}")
print("{lv.models.len} models, {lv.objects.len} objects")
col = lv.segments.readCollision(rom, lv.terrain)
print("collision: {col.vertices.len / 3} vertices, {col.surfaces.len} triangles, {col.specials.len} specials, {col.water.len} water boxes")
for w in col.water:
	print("  water {w.id}: x {w.x1}..{w.x2} z {w.z1}..{w.z2} y {w.y}")
mut models {i64: i64} = {}
for p in col.specials:
	models.add(p.model, 1)
print("special models: {models}")
macros = lv.segments.readMacroObjects(rom, lv.macros)
mut macroModels {i64: i64} = {}
for p in macros:
	macroModels.add(p.model, 1)
print("macro objects: {macros.len}, models {macroModels}")
for seg in 0..32:
	if not lv.segments.banks[seg].isEmpty:
		print("segment {seg}: {lv.segments.banks[seg].len} bytes")

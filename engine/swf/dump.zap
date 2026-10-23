# A movie described as lines of text, as swfdump does: the header, the tags counted, the
# characters by id, the assets exported and imported, the main timeline's frames, and the tree of
# instances its first frame shows.

import image

# the signature, version, stage, frame rate and Scaleform's exporter
pub fn headerLines(s Swf) str[]:
	size = s.stageSize()
	out = [
		"{s.signature} version {s.version}, stage {size.x:.0}x{size.y:.0}, {s.frameRate:.2} fps, {s.timeline.frameCount} frames"
	]
	if s.exporter is e:
		out.push("Scaleform exporter {e.version:x}, flags {e.flags:x}, bitmaps {e.bitmapFormat}, prefix \"{e.prefix}\", name \"{e.swfName}\"")
	out

# each tag's name and count, the unknown ones and the problems after
pub fn tagLines(s Swf) str[]:
	out = []
	for code in s.tagCounts.keys().sorted():
		out.push("{tagName(code)} ({code}): {s.tagCounts[code]}")
	for code in s.unknown.keys().sorted():
		out.push("unknown tag {code}: {s.unknown[code]}, passed over")
	for p in s.problems:
		out.push("problem: {p}")
	out

# one line per character, by id
pub fn characterLines(s Swf) str[]:
	out = []
	for id in s.kinds.keys().sorted():
		out.push("{id}: {tagName(s.kinds[id])} {s.characterSummary(id)}")
	out

fn characterSummary(s Swf, id i64):
	if s.shapes.get(id) is sh:
		fills = sh.fills.map(.showFill()).join(" ")
		return "{sh.bounds.showRect()}, fills [{fills}], {sh.lines.len} lines, {sh.edges.len} edges"
	if s.sprites.get(id) is sp:
		labels = []
		for k, f in sp.timeline.frames:
			if not f.label.isEmpty: labels.push("{f.label}@{k}")
		return "{sp.timeline.frameCount} frames {labels.join(" ")}"
	if s.bitmaps.get(id) is b:
		w, h = b.bitmapSize()
		return "{w}x{h}" if w > 0 else "{b.data.len} bytes"
	if s.fonts.get(id) is f: return "\"{f.name}\" {f.glyphs.len} glyphs"
	if s.editTexts.get(id) is t:
		return "{t.bounds.showRect()} font {t.font} {t.height / 20.0:.1}px var \"{t.variable}\" text \"{t.text.short()}\""
	if s.texts.get(id) is t: return "{t.records.len} records"
	if s.buttons.get(id) is b: return "{b.records.len} records"
	if s.externalImages.get(id) is e:
		return "{e.width}x{e.height} \"{e.fileName}\" ({e.exportName})"
	if s.subImages.get(id) is e: return "of {e.image}: {e.x0},{e.y0} .. {e.x1},{e.y1}"
	""

fn showFill(f Fill):
	match f:
		Solid(c): "solid {c.showColor()}"
		Gradient(
			g
		): "{"radial" if g.radial else "linear"} {g.stops.map(.color.showColor()).join(",")}"
		Bitmap(id, m, repeat, smooth): "bitmap {id}"

fn showColor(c Vec4):
	"#{image.unitToByte(c.x):02x}{image.unitToByte(c.y):02x}{image.unitToByte(c.z):02x}{image.unitToByte(c.w):02x}"

fn short(text str):
	one = text.replace("\n", " ").replace("\r", " ")
	one[..one.len.min(60)].copy()

fn showRect(r Rect):
	"[{r.xmin / 20.0:.1},{r.ymin / 20.0:.1} .. {r.xmax / 20.0:.1},{r.ymax / 20.0:.1}]"

# the names exported and imported, and the sprites' init actions
pub fn assetLines(s Swf) str[]:
	out = []
	for name in s.exports.keys().sorted():
		out.push("export {s.exports[name]} as \"{name}\"")
	for i in s.imports:
		out.push("import \"{i.name}\" from {i.url} as {i.id}")
	for a in s.initActions:
		out.push("init actions of {a.sprite}: {a.code.len} bytes")
	out

# the timeline's frames: labels, places and removals, actions
pub fn timelineLines(t Timeline, indent str) str[]:
	out = []
	for k, f in t.frames:
		label = " \"{f.label}\"" if not f.label.isEmpty else ""
		out.push("{indent}frame {k}{label}: {f.commands.len} commands, {f.actions.len} actions")
		for c in f.commands:
			match c:
				Place(p):
					name = " \"{p.name}\"" if not p.name.isEmpty else ""
					what = "move" if p.moves else "place"
					clip = " clips to {p.clipDepth}" if p.clipDepth > 0 else ""
					out.push("{indent}  {what} {p.character} at {p.depth}{name}{clip}")
				Remove(depth): out.push("{indent}  remove at {depth}")
	out

# The instances a timeline shows at a frame, as a tree: each its depth, character, kind, name and
# place in pixels, sprites opened at their first frame, `depth` levels at most.
pub fn treeLines(s Swf, t Timeline, frame i64, indent str, depth i64) str[]:
	out = []
	for p in t.displayList(frame):
		kind = tagName(s.kinds.get(p.character) ?? 0)
		name = " \"{p.name}\"" if not p.name.isEmpty else ""
		hidden = " hidden" if not p.visible else ""
		alpha = " alpha {p.color.mul.w:.2}" if p.color.mul.w < 1.0 else ""
		clip = " clips to {p.clipDepth}" if p.clipDepth > 0 else ""
		out.push("{indent}{p.depth}: {p.character} {kind}{name}{clip} at {p.matrix.tx / 20.0:.1},{p.matrix.ty / 20.0:.1} scale {p.matrix.a:.2},{p.matrix.d:.2}{alpha}{hidden}")
		if depth > 1 and s.sprites.get(p.character) is sp:
			out.extend(s.treeLines(sp.timeline, 0, "{indent}  ", depth - 1))
	out

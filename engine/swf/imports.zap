# ImportAssets resolved by merging: a library movie (Scaleform's shared components, such as
# Skyrim's "Inventory components/InventoryLists.swf") put into the movie that imports from it, its
# characters given ids past the movie's own, its exports, imports and init actions kept, and each
# place of the movie that named an imported id naming the library's character instead. One movie
# then holds every character its display list and code use.

# the movie with the library from `url` merged in, its imports from there resolved
pub fn mergeLibrary(mut s Swf, move lib Swf, url str):
	offset = s.nextFreeId()
	base = s.libraryCount
	s.libraryCount += lib.libraryCount + 1
	for id in lib.kinds.keys():
		s.kinds[id + offset] = lib.kinds[id]
		s.libraryOf[id + offset] = base + 1 + (lib.libraryOf.get(id) ?? 0)
	for id in lib.linkages.keys():
		s.linkages[id + offset] = lib.linkages[id].copy()
	for id in lib.shapes.keys():
		shape = lib.shapes[id].copy()
		shape.id += offset
		for k in 0..shape.fills.len:
			if shape.fills[k] is Bitmap(b, matrix, repeat, smooth):
				if b != 65_535: shape.fills[k] = .Bitmap(b + offset, matrix, repeat, smooth)
		s.shapes[id + offset] = shape
	for id in lib.sprites.keys():
		sprite = lib.sprites[id].copy()
		sprite.id += offset
		sprite.timeline.shiftCharacters(offset, -1, 0)
		s.sprites[id + offset] = sprite
	s.mergeTexts(lib, offset)
	for id in lib.bitmaps.keys():
		b = lib.bitmaps[id].copy()
		b.id += offset
		s.bitmaps[id + offset] = b
	for id in lib.subImages.keys():
		sub = lib.subImages[id]
		s.subImages[id + offset] = SubImage(id = sub.id + offset, image = sub.image + offset,
			x0 = sub.x0, y0 = sub.y0, x1 = sub.x1, y1 = sub.y1)
	for id in lib.buttons.keys():
		b = lib.buttons[id].copy()
		b.id += offset
		for mut record in b.records:
			record.character += offset
		s.buttons[id + offset] = b
	for id in lib.scalingGrids.keys():
		s.scalingGrids[id + offset] = lib.scalingGrids[id]
	s.mergeAssets(lib, offset, url, base)

fn mergeTexts(mut s Swf, lib Swf, offset i64):
	for id in lib.fonts.keys():
		f = lib.fonts[id].copy()
		f.id += offset
		s.fonts[id + offset] = f
	for id in lib.texts.keys():
		t = lib.texts[id].copy()
		t.id += offset
		for mut record in t.records:
			record.font += offset
		s.texts[id + offset] = t
	for id in lib.editTexts.keys():
		t = lib.editTexts[id].copy()
		t.id += offset
		if t.font >= 0: t.font += offset
		s.editTexts[id + offset] = t

# the library's exports, imports and init actions taken over (its init actions run first, as
# the library loads before the movie's code), and the movie's imports from it resolved
fn mergeAssets(mut s Swf, lib Swf, offset i64, url str, base i64):
	for name in lib.exports.keys():
		if s.exports.get(name) == none: s.exports[name.copy()] = lib.exports[name] + offset
	for i in lib.imports:
		s.imports.push(Import(url = i.url.copy(), name = i.name.copy(), id = i.id + offset))
	actions = lib.initActions.map(InitAction(sprite = .sprite + offset, code = .code.copy(),
		library = base + 1 + it.library))
	actions.extend(s.initActions.map(.copy()))
	s.initActions = actions
	for i in s.imports.copy():
		if i.url != url: continue
		target = lib.exports.get(i.name) ?? continue
		s.timeline.shiftCharacters(target + offset - i.id, i.id, 0)
		for id in s.sprites.keys():
			s.sprites[id].timeline.shiftCharacters(target + offset - i.id, i.id, 0)
		s.kinds[i.id] = lib.kinds.get(target) ?? 0

# Every PlaceObject's character moved by `by`: all of them when `only` is -1, else those naming
# `only`. The ids from `from` on.
fn shiftCharacters(mut t Timeline, by i64, only i64, from i64):
	for f in 0..t.frames.len:
		for k in 0..t.frames[f].commands.len:
			if t.frames[f].commands[k] is Place(p):
				if p.character < from or (only >= 0 and p.character != only): continue
				q = p.copy()
				q.character += by
				t.frames[f].commands[k] = .Place(q)

# an id past every character and import of the movie
fn nextFreeId(s Swf):
	top = 0
	for id in s.kinds.keys():
		top = top.max(id)
	for i in s.imports:
		top = top.max(i.id)
	top + 1

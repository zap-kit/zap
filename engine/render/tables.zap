# Textures read by number: a program's texture array (`textures Texture[]` in its parameters,
# bindless on the GPU) holds a table's textures, each once, at the index it was first given, so a
# model's vertices or its materials (a storage buffer of records) name their textures by index
# and a whole scene of many textures is drawn in a few draws.
#
#   mut table = engine.TextureTable()
#   materials.push(Material(color = table.indexOf(stone), ...))
#   engine.setParams(p, Params(textures = table.textures, materials = materials, ...))

# a program's texture array, each texture once
pub type TextureTable:
	textures Texture[] = []
	places {i64: i32} = {}   # a texture's id: its index

	# the texture's index in the table: added at the end the first time
	pub mut fn indexOf(t Texture) i32:
		if places.get(t.id) is i: return i
		i = i32(textures.len)
		textures.push(t)
		places[t.id] = i
		i

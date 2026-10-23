# A texture table: the textures a program reads by number, each at the index it was first given.

import engine

test "a texture keeps the index it was first given":
	table = engine.TextureTable()
	a = engine.Texture(id = 7, width = 1, height = 1)
	b = engine.Texture(id = 3, width = 1, height = 1)
	c = engine.Texture(id = 9, width = 1, height = 1)
	print("{table.indexOf(a)} {table.indexOf(b)} {table.indexOf(a)} {table.indexOf(c)}")
	prints """
		0 1 0 2
		"""

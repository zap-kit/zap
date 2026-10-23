# The textures a model names, as the archive keys they are stored under.

import skyrim.bsa

# the archive key of a texture path as a model names it ("textures\x.dds", or "x.dds" under it)
pub fn textureKey(path str) str:
	key = bsa.bsaKey(path.bytes())
	if key.startsWith("data/"): key = key[5..].copy()   # as the baked heads name their tints
	key if key.startsWith("textures/") else "textures/{key}"

# the keys of every texture the model names, each once, in block order: all the slots of its
# texture sets, and the source and greyscale textures of its effect shaders (fire, smoke and the
# particle systems use those)
pub fn textureKeys(n Nif) str[]:
	paths = []
	for b in n.blocks:
		match b:
			TextureSetBlock(set): paths.extend(set.copy())
			EffectBlock(shader):
				paths.push(shader.sourceTexture.copy())
				paths.push(shader.greyscaleTexture.copy())
			_: pass
	seen {str: bool} = {}
	out = []
	for path in paths:
		if path.isEmpty: continue
		key = textureKey(path)
		if key in seen: continue
		seen[key.copy()] = true
		out.push(key)
	out

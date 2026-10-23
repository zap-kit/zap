# The files the preparation writes into projects/ragnarok/assets/prepared/ and the game reads at
# once: the engine's prepared files (engine/prepared.zap) under "ZNRK" and the format's version.

import engine
import image
import fs

# raised whenever what is prepared, or how, changes
pub formatVersion = 6
pub preparedDir = "projects/ragnarok/assets/prepared"

pub type PreparedTexture:
	width i64
	height i64
	blended bool   # partly see-through, drawn blended
	pixels engine.Span   # RGBA, rows from the top

# a batch of triangles drawn with one texture
pub type PreparedBatch:
	texture i64
	twoSided bool
	vertices engine.Span   # the vertices' bytes, as the GPU reads them

pub fn appendTexture(mut body u8[], img image.Image, blended bool) PreparedTexture:
	PreparedTexture(
		width = img.width,
		height = img.height,
		blended,
		pixels = body.append(img.cells.bytes())
	)

pub fn appendBatch<V>(
	mut body u8[],
	texture i64,
	twoSided bool,
	vertices V[]
) PreparedBatch:
	PreparedBatch(
		texture = texture,
		twoSided = twoSided,
		vertices = body.append(vertices.rawBytes())
	)

# the texture's image, its pixels copied out of the body
pub fn imageAt(body u8[], t PreparedTexture) image.Image:
	image.fromBytes(t.width, t.height, body.bytesAt(t.pixels).copy())

# the file written
pub fn writePrepared(path str, head u8[], body u8[]) ? fs.Error:
	try engine.writePreparedFile(path, "ZNRK", formatVersion, head, body)

# the file read, none when it is missing, not ours, or of another version
pub fn readPrepared(path str) engine.Prepared?:
	engine.readPreparedFile(path, "ZNRK", formatVersion)

# The RSW's placed models made into triangles of the map's world, grouped by texture and by
# whether they show both sides: every model that stands still is built once into the static
# batches; one whose nodes turn (Prontera's clock hands, its swinging signs) is built again each
# frame at the moment of its animation. Each vertex is lit by the sun as the client lights it:
# not at all (the bare cap), by its face's normal, or by its smoothing group's.

import engine
import world.shaders
import ragnarok.rsm
import ragnarok.rsw

pub type ModelBatch:
	texture i64   # the scene's texture index
	twoSided bool
	vertices shaders.ModelVertex[]

pub type ModelBatches:
	batches ModelBatch[] = []
	byKey {i64: i64} = {}   # texture * 2 + both sides -> batch

	fn clearAll():
		for mut batch in batches:
			batch.vertices.clear()

	fn batchFor(texture i64, twoSided bool):
		key = texture * 2 + (1 if twoSided else 0)
		if byKey.get(key) is b: return b
		at = batches.len
		batches.push(ModelBatch(texture, twoSided, vertices = []))
		byKey[key] = at
		at

# a model's normals in its nodes' own space, which no pose changes: per node, each face's and
# (smooth shading) each corner's within its smoothing group
pub type ModelNormals:
	faces Vec3[,]
	corners Vec3[,]

pub fn normalsOf(model rsm.Rsm) ModelNormals:
	out = ModelNormals(faces = [], corners = [])
	for n in model.nodes:
		out.faces.push(
			n.faces.map(f:
				engine.faceNormal(
					n.vertices[f.vertices[0]],
					n.vertices[f.vertices[1]],
					n.vertices[f.vertices[2]]
				)
			)
		)
		out.corners.push(n.smoothNormals() if model.shade == rsm.shadeSmooth else [])
	out

# The model posed by `nodes` and placed by `placed`, its triangles added to the batches; its
# texture i is the scene's textures[i].
pub fn bakeModel(
	model rsm.Rsm,
	normals ModelNormals,
	nodes Mat4[],
	placed Mat4,
	textures i64[],
	sun rsw.Sun,
	toward Vec3,
	mut into ModelBatches
):
	for i, n in model.nodes:
		m = placed @ nodes[i]
		mirrored = m.determinant3() < 0.0
		sign f32 = -1.0 if mirrored else 1.0
		faceNormals = normals.faces[i]
		cornerNormals = normals.corners[i]
		world = n.vertices.map(m.applyPoint(it))
		for fi, f in n.faces:
			if f.texture < 0 or f.texture >= n.textures.len: continue
			modelTexture = n.textures[f.texture]
			if modelTexture < 0 or modelTexture >= textures.len: continue
			b = into.batchFor(textures[modelTexture], f.twoSided)
			# a mirroring transform turns the winding round: the corners go in the other order so
			# the front stays the front
			for j in 0..3:
				k = 3 - j if mirrored and j > 0 else j
				normal Vec3? = none
				if model.shade == rsm.shadeFlat:
					normal = (m.applyDirection(faceNormals[fi]) * sign).normalized()
				elif model.shade == rsm.shadeSmooth:
					normal = (m.applyDirection(cornerNormals[fi * 3 + k]) * sign).normalized()
				uv = n.uvs[f.uvs[k]]
				into.batches[b].vertices.push(shaders.ModelVertex(
					position = world[f.vertices[k]],
					uvAlpha = Vec3(uv.x, uv.y, model.alpha),
					light = sunlight(
						sun,
						toward,
						normal
					), texture = i32(textures[modelTexture])))

# a node's normal at each corner of its faces (three a face), smooth within a smoothing group
fn smoothNormals(n rsm.Node):
	indices i64[] = []
	for f in n.faces:
		indices.extend([f.vertices[0], f.vertices[1], f.vertices[2]])
	engine.groupNormals(n.vertices, indices, n.faces.map(.smoothGroup))

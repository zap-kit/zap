# A vertex seen from the light, for the shadow map; depth only, the holes in leaves letting the
# light through.

import engine

pub type Shadow:
	lightViewProjection Mat4
	time f32   # 0: the leaves held still in the maps (a swaying shadow reads as a flicker)
	chunkOrigin Vec3
	tiles engine.TextureArray

pub fn shadowVertex(v CornerWord, p Shadow) (Vec4, Vec3):
	c = unpack(v.word, p.chunkOrigin, p.time)
	(p.lightViewProjection @ c.position.withW(1.0), c.uvLayer)

pub fn shadowPixel(uvLayer Vec3, p Shadow):
	if p.tiles.sample(uvLayer.xy, uvLayer.z).a < 0.5:
		discard()

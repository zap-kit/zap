# The furniture markers a model carries (BSFurnitureMarkerNode, an extra data of its root): where
# an actor sits, sleeps or leans, facing which way, and from which sides it may get on. Layout after
# NifSkope's nif.xml (FurniturePosition, Bethesda version above 34).

# a marker's animation type
pub furnitureSit = 1
pub furnitureSleep = 2
pub furnitureLean = 4

pub type FurnitureMarker:
	offset Vec3   # in the model's space
	heading f32   # radians about z
	kind i64   # furnitureSit, furnitureSleep or furnitureLean
	entries i64   # the sides it is entered from: 1 front, 2 behind, 4 right, 8 left, 16 up

fn readFurniture(mut s Reader):
	s.skip(4)   # the name
	out = []
	loop s.u32():
		offset = s.vec3()
		heading = s.f32()
		kind = s.u16()
		out.push(FurnitureMarker(offset, heading, kind, entries = s.u16()))
		if s.short: break
	out

# the model's furniture markers, in the order the file gives them
pub fn furnitureMarkers(n Nif) FurnitureMarker[]:
	out = []
	for b in n.blocks:
		if b is FurnitureBlock(markers): out.extend(markers)
	out

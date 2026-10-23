# The vertices of every mesh: placed by the model matrix, or, for a mesh drawn in copies, by
# each copy's place, turn about y and scale (scale 0 when not a copy). What the lit programs
# read is one struct, a Surface: the view, the model, the material, the sun and the sky, the
# point lights, the shadow map, the relief, the storage block of many lights.

import engine

# a vertex of a mesh: where it is, its normal, its texture place (u, v, 0) and a spare value
pub type MeshVertex:
	position Vec3
	normal Vec3
	extra Vec3
	spare f32

# a copy of a mesh: where it stands (x, y, z) and its turn about y, its scale (0: not a copy)
# and its number (a color of the palette)
pub type Copy:
	place Vec4
	scale f32
	number f32

# a point light: where it is and how far it reaches (0: off); its color and strength
pub type PointLight:
	at Vec4
	color Vec3

pub type Surface:
	viewProj Mat4
	model Mat4
	eye Vec3
	albedo Vec3
	metal f32
	rough f32
	emissive Vec3
	sunDir Vec3   # toward the sun
	sunLight Vec3   # the sun's radiance
	night f32
	lights PointLight[4]
	shadowViewProj Mat4
	shadowed bool   # the sun casts the shadow map's shadows
	checker bool   # the albedo checkered by the texture place
	paletted bool   # the albedo picked by the copy's number
	depthScale f32   # the relief's depth
	lightCount i32   # the lights in the storage block
	shadowMap engine.ShadowMap
	relief engine.Texture   # the relief's color, its height in alpha
	many Vec4[]   # the storage block: two a light (where, reach; color)

pub type MeshPoint:
	worldPos Vec3
	worldNormal Vec3
	texPlace Vec2
	tag i32   # a copy's number, else the vertex's spare value

pub fn meshVertex(v MeshVertex, copy Copy, p Surface) (Vec4, MeshPoint):
	at = v.position
	n = v.normal
	tag = i32(v.spare)
	if copy.scale > 0.0:
		c = copy.place.w.cos()
		s = copy.place.w.sin()
		at = Vec3(c * at.x + s * at.z, at.y, -s * at.x + c * at.z) * copy.scale + copy.place.xyz
		n = Vec3(c * n.x + s * n.z, n.y, -s * n.x + c * n.z)
		tag = i32(copy.number)
	w = p.model @ at.withW(1.0)
	(
		p.viewProj @ w,
		MeshPoint(
			worldPos = w.xyz,
			worldNormal = Mat3(p.model) @ n,
			texPlace = v.extra.xy,
			tag = tag
		)
	)

# A shadow map's pass: only the depth is written.
pub fn depthPixel(b MeshPoint, p Surface):
	pass

# A light's bulb: a small sphere drawn once per light, placed and colored by the storage block.
pub fn bulbVertex(v MeshVertex, light i32, p Surface) (Vec4, Vec3):
	at = p.many[light * 2]
	glow = p.many[light * 2 + 1].rgb * 1.5
	(p.viewProj @ (at.xyz + v.position * 0.12).withW(1.0), glow)

pub fn bulbPixel(glow Vec3, p Surface) Vec4:
	glow.withW(1.0)

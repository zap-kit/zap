# Grass as Skyrim's grass shader draws it (Community Shaders' RunGrass.hlsl, the vanilla permutation:
# the plain Grass shader, not the Grass Lighting feature): each plant an instance of its kind's
# model, put by the basis stored in the instance, stretched by its delta, swayed by the wind
# (GrassWindDisplacement: the instance's phase and the vertex color's alpha as its weight), lit by
# the sun's color and the ambient along the surface's normal, faded with distance, alpha tested.
#
# The model's and the instance's axes are the game's (z up); the vertex stage turns the plant's
# world position into the engine's y-up space.

import engine

# a vertex of a grass model (the game's axes): its place, texture coordinate and color (the tint
# and, in alpha, how far the wind moves it)
pub type GrassVertex:
	position Vec3
	uv Vec2
	color Vec4

# One plant: its place (game axes) and shade, the three rows of the basis turning the model (the
# phase of its wind in the first's w, its delta in the second's, its kind in the third's).
pub type GrassInstance:
	place Vec4
	rowX Vec4
	rowY Vec4
	rowZ Vec4

pub type GrassPoint:
	world Vec3
	uv Vec2
	color Vec4
	shade f32
	kind f32
	fade f32

pub type GrassParams:
	projection Mat4
	view Mat4
	eye Vec4
	ambient Vec4[6]
	sunColor Vec4
	fogNearColor Vec4
	fogFarColor Vec4
	fog Vec4   # near, far, power, max
	textures engine.Texture[]
	# by kind: the diffuse texture's index, the wave period, 1 for a kind scaled every way (else along
	# its z only)
	kinds Vec4[]
	seconds f32
	windMagnitude f32   # units the wind moves a plant at most
	fadeStart f32 = 7000.0
	fadeRange f32 = 1000.0
	normalPass f32 = 0.0

pub fn grassVertex(v GrassVertex, i GrassInstance, p GrassParams) (Vec4, GrassPoint):
	kind = p.kinds[i32(i.rowZ.w + 0.5)]
	mask = Vec3(kind.z, kind.z, 1.0)
	grown = v.position * (mask * i.rowY.w + Vec3(1.0, 1.0, 1.0))
	local = Vec3(i.rowX.xyz @ grown, i.rowY.xyz @ grown, i.rowZ.xyz @ grown)
	# the wind: GrassWindDisplacement's sway of the plant's phase, a timer of the kind's wave period
	timer = p.seconds * kind.y / 600.0 * tau
	angle = 0.4 * (i.rowX.w + timer)
	s = angle.sin()
	c = angle.cos()
	sway = ((pi * s).sin() + (tau * s).sin()) * 0.3 + 0.2 * (pi * c).cos()
	power = p.windMagnitude * (sway * (0.5 * v.color.a * v.color.a))
	game = i.place.xyz + local + Vec3(0.0, power, 0.0)
	world = inEngine(game)
	clip = p.projection @ p.view @ world.withW(1.0)
	away = (world - p.eye.xyz).length()
	fade = 1.0 - ((away - p.fadeStart) / p.fadeRange).clamp(0.0, 1.0)
	(
		clip,
		GrassPoint(
			world,
			uv = v.uv,
			color = v.color,
			shade = i.place.w,
			kind = i.rowZ.w,
			fade
		)
	)

# the alpha test's reference, 100 / 255 (the grass models' NiAlphaProperty)
grassAlphaRef f32 = 0.39215687

pub fn grassPixel(b GrassPoint, p GrassParams) Vec4:
	kind = p.kinds[i32(b.kind + 0.5)]
	texel = p.textures[engine.tileSlot(kind.x)].sample(b.uv)
	if texel.a * b.fade < grassAlphaRef:
		discard()
	toEye = (p.eye.xyz - b.world).normalized()
	flat = b.world.ddx().cross(b.world.ddy()).normalized()
	n = flat if (flat @ toEye) > 0.0 else flat * -1.0
	if p.normalPass > 0.5:
		return (p.view @ n.withW(0.0)).xyz.withW(1.0)
	albedo = texel.rgb * b.color.rgb * b.shade
	light = p.sunColor.rgb + ambientCube(n, p.ambient)
	c = light * albedo
	amount = (((away(b, p) - p.fog.x) / (p.fog.y - p.fog.x).max(1.0)).clamp(0.0, 1.0))
		.pow(p.fog.z.max(0.01))
		.min(p.fog.w)
	fogged = c.lerp(p.fogNearColor.rgb.lerp(p.fogFarColor.rgb, amount), amount)
	fogged.withW(1.0)

fn away(b GrassPoint, p GrassParams) f32:
	(p.eye.xyz - b.world).length()

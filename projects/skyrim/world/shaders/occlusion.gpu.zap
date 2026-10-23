# Skyrim's ambient occlusion (SkyrimPrefs.ini's bSAOEnable), from its DXBC in Skyrim - Shaders.bsa
# (shaders011.fxp; with TAA on, bUseTAA=1, the game draws ISSAORawAO's temporal form): McGuire, Mara
# and Luebke's Scalable Ambient Obscurance (2012) as the game compiled it (five taps on a spiral of
# two turns, turned by a random angle each frame, each its occluder's (r² - v.v)³ (v.n - bias) /
# (v.v + 0.01), a bias that grows toward the corners and past 2100 units; the 2 x 2 quad's
# gradient taken out where the depth is smooth; then blended with the last frame's by how close
# the two are, fSAOValueDiffFactor, and their depth keys), then ISSAOBlurH and V (seven taps two
# texels apart, kept on the same depth), and ISSAOComposite's product: the lit color times the
# occlusion. The normals are the opaque parts' normal-mapped view-space normals, as the game's
# normal buffer holds them.

import engine

pub type RawOcclusion:
	depth engine.Texture   # the scene's
	unproject Vec4   # the projection's 1 / m[0], 1 / m[5], m[10] and m[14]
	extent Vec4   # the target's width and height, and their inverses
	# the radius in world units over the view's depth at a distance of 1, in pixels; the radius
	# squared; the intensity over radius^6; the bias in world units
	shape Vec4
	normals engine.Texture   # the opaque parts' view-space normals, 0 where none was drawn
	contrast f32   # 0.5 leaves the occlusion as it is, below darkens it, above lightens it
	history engine.Texture   # the last frame's raw occlusion and depth key
	toPrevious Mat4   # this frame's view space into the last frame's
	turn f32   # this frame's random angle
	steadiness f32   # fSAOValueDiffFactor: how fast a change of the occlusion leaves the history
	fresh f32   # 1 on the first frame, with no history

# where the scene's surface at uv lies in view space (looking down -z)
fn viewAt(uv Vec2, p RawOcclusion) Vec3:
	viewAtDepth(p.depth, p.unproject, uv)

# the nearer of two neighbors' steps from c, so an edge does not bend the normal
fn stepTo(c Vec3, a Vec3, b Vec3) Vec3:
	(a - c) if (a.z - c.z).abs() < (c.z - b.z).abs() else (c - b)

# the surface's normal at uv (toward the eye) from its neighbors' depths
fn normalAt(uv Vec2, c Vec3, p RawOcclusion) Vec3:
	dx = Vec2(p.extent.z, 0.0)
	dy = Vec2(0.0, p.extent.w)
	across = stepTo(c, viewAt(uv + dx, p), viewAt(uv - dx, p))
	down = stepTo(c, viewAt(uv + dy, p), viewAt(uv - dy, p))
	n = across.cross(down).normalized()
	n * -1.0 if n @ c > 0.0 else n

# The full-resolution texel the game's depth pyramid (ISSAOMinify) keeps at texel (x, y) of its
# level: each level takes, of the four texels under one of its own, the odd or the even one by the
# parity of its index.
fn keptTexel(x i32, y i32, level i32) (i32, i32):
	kx = x
	ky = y
	loop level:
		kx = kx * 2 + (1 if (kx & 1) == 0 else 0)
		ky = ky * 2 + (1 if (ky & 1) == 0 else 0)
	(kx, ky)

# The view-space point of a tap: the pixel's own place, at the depth the pyramid's level holds
# around uvTap (ISSAORawAO takes the tap's depth from a level chosen by how far it lies).
fn tapAt(uvTap Vec2, pixel Vec2, level i32, p RawOcclusion) Vec3:
	scale = 1 << level
	across = i32(p.extent.x) / scale
	high = i32(p.extent.y) / scale
	tx = i32(uvTap.x * f32(across)).max(0).min(across - 1)
	ty = i32(uvTap.y * f32(high)).max(0).min(high - 1)
	# the game's rows count from the top
	kx, kyTop = keptTexel(tx, high - 1 - ty, level)
	ky = i32(p.extent.y) - 1 - kyTop
	d = p.depth.sampleLevel(
		Vec2((f32(kx) + 0.5) * p.extent.z, (f32(ky) + 0.5) * p.extent.w),
		0.0
	).r *
		2.0 -
		1.0
	z = -p.unproject.w / (d + p.unproject.z)
	at = pixel * p.extent.zw
	Vec3((at.x * 2.0 - 1.0) * -z * p.unproject.x, (at.y * 2.0 - 1.0) * -z * p.unproject.y, z)

# where the surface seen at uv was on the last frame's screen
fn lastUv(uv Vec2, p RawOcclusion) Vec2:
	v = viewAt(uv, p)
	q = p.toPrevious @ Vec4(v.x, v.y, v.z, 1.0)
	k = -1.0 / q.z
	Vec2(0.5 + 0.5 * q.x * k / p.unproject.x, 0.5 + 0.5 * q.y * k / p.unproject.y)

# the share of the ambient light that reaches uv (red) and its depth key (green: depth / 7000)
pub fn rawOcclusionPixel(uv Vec2, p RawOcclusion) Vec4:
	if p.depth.sampleLevel(uv, 0.0).r >= 1.0:
		return Vec4(1.0, 1.0, 0.0, 1.0)
	c = viewAt(uv, p)
	fade = (-c.z / 7000.0).clamp(0.0, 1.0)
	if fade >= 1.0:
		return Vec4(1.0, 1.0, 0.0, 1.0)
	buffered = p.normals.sampleLevel(uv, 0.0).rgb
	n = buffered if (buffered @ buffered) > 0.25 else normalAt(uv, c, p)
	n = n * -1.0 if n @ c > 0.0 else n
	texel = (uv * p.extent.xy).floor()
	x = i32(texel.x)
	y = i32(texel.y)
	# the game counts rows from the top and its taps' y downward, ours from the bottom upward
	top = i32(p.extent.y) - 1 - y
	turn = f32((3 * x) ^ (x * top + top)) * 10.0
	disk = p.shape.x / -c.z
	ndc = uv * 2.0 - Vec2(1.0, 1.0)
	bias = 2.0 * (ndc @ ndc) + p.shape.w + (fade - 0.3).max(0.0) * 10.0
	if fade <= 0.5:
		turn += p.turn
	sum f32 = 0.0
	for i in 0..5:
		along = f32(i) + 0.5
		angle = along * 2.512 + turn
		reach = disk * along / 5.0
		toward = Vec2(angle.cos(), angle.sin()) * reach
		offset = Vec2(toward.x, -toward.y)
		level = (i32((reach.ln() / 0.6931472).floor()) - 3).max(1).min(4)
		steps = toward.trunc()
		pixel = texel + Vec2(steps.x, -steps.y) + Vec2(0.5, 0.5)
		v = tapAt(uv + offset * p.extent.zw, pixel, level, p) - c
		vv = v @ v
		f = (p.shape.y - vv).max(0.0)
		sum += f * f * f * ((v @ n - bias) / (vv + 0.01)).max(0.0)
	a = (1.0 - sum * p.shape.z).max(0.0)
	k = p.contrast.clamp(1.0e-5, 0.99999)
	a = a.pow(2.0 * k) if k < 0.5 else a.pow(1.0 / (2.0 - 2.0 * k))
	# the quad's gradient taken out where the depth is smooth across it (rows from the bottom and
	# ddy upward here: with an even height the same quads and the same step as the game's)
	if c.z.ddx().abs() < 0.02:
		a -= a.ddx() * (f32(x & 1) - 0.5)
	if c.z.ddy().abs() < 0.02:
		a -= a.ddy() * (f32(y & 1) - 0.5)
	if p.fresh > 0.5:
		return Vec4(a, fade, 0.0, 1.0)
	motion = lastUv(uv, p) - uv
	moving f32 = 1.0
	if (motion @ motion) > 0.0:
		there = uv + motion.normalized() * 0.055
		moving = (1.0 - (motion - (lastUv(there, p) - there)).length() * 200.0).max(0.2)
	past = p.history.sampleLevel(uv + motion, 0.0)
	same = (1.0 - (fade - past.g).abs() * 200.0).max(0.0)
	keep = (1.0 - p.steadiness * (a - past.r).abs()).clamp(0.0, 1.0) * same * moving
	a = a + keep * (past.r - a)
	Vec4(a, fade, 0.0, 1.0)

# the blur's weights of the neighbors 2, 4 and 6 texels away (the pixel's own is 0.15317)
blurWeights f32[3] = [0.444893, 0.422649, 0.392902]

pub type OcclusionBlur:
	raw engine.Texture
	step Vec2   # two texels across, or two up

# ISSAOBlurH and V: the occlusion's six neighbors in a line, each weighed less as its depth key
# leaves the pixel's (none past 1/2000 of 7000 units, 3.5)
pub fn occlusionBlurPixel(uv Vec2, p OcclusionBlur) Vec4:
	here = p.raw.sample(uv)
	if here.g >= 1.0:
		return Vec4(1.0, 1.0, 0.0, 1.0)
	sum = here.r * 0.15317
	total f32 = 0.15317
	for k in 0..3:
		for side in 0..2:
			s = f32(side) * 2.0 - 1.0
			there = p.raw.sample(uv + p.step * (f32(k + 1) * s))
			w = (1.0 - (there.g - here.g).abs() * 2000.0).max(0.0) * blurWeights[k]
			sum += there.r * w
			total += w
	Vec4(sum / (total + 0.0001), here.g, 0.0, 1.0)

pub type OcclusionApplied:
	occlusion engine.Texture
	fade f32   # the fog fade the composite multiplies the whole picture by

# the lit color times the occlusion and the fog fade (ISSAOComposite's FogNearColor.w), drawn with
# premultiplied blending (dst * (1 - alpha))
pub fn occlusionAppliedPixel(uv Vec2, p OcclusionApplied) Vec4:
	Vec4(0.0, 0.0, 0.0, 1.0 - p.occlusion.sample(uv).r * p.fade)

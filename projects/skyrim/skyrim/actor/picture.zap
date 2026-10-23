# A figure drawn on the CPU for a look without the GPU: its triangles flat shaded, the nearest
# kept at each pixel (a depth buffer), seen from the front (from +Y, where an actor faces) and from its right
# side, side by side, with lines at the ground and at every 32 units up. A part whose texture is
# mostly see-through (a hairline, lashes) is left out, as flat triangles it would hide the face.

import image
import image.dds
import skyrim
import skyrim.esm
import skyrim.nif

viewWidth = 320
viewHeight = 480

# how much of the figure a picture shows: its scale and the height at its bottom
pub type Framing:
	pixelsPerUnit f32
	lowest f32

# the whole figure, 160 units from just below the feet
pub wholeFigure = Framing(pixelsPerUnit = 3.0, lowest = -10.0)

# the head and the neck of a standing human, 40 units
pub headAndNeck = Framing(pixelsPerUnit = 12.0, lowest = 95.0)

seeThroughAlpha = 90   # a tint's alpha below which its part is left out

# a camera along one axis: `across` is the picture's right, `toward` points at the eye
type View:
	across Vec3
	toward Vec3
	left i64   # where the view starts in the picture
	framing Framing

fn onScreen(v View, p Vec3):
	Vec2(
		f32(v.left + viewWidth / 2) + (p @ v.across) * v.framing.pixelsPerUnit,
		f32(viewHeight) - (p.z - v.framing.lowest) * v.framing.pixelsPerUnit
	)

fn shaded(tint image.Rgba8, corners Vec3[], v View):
	n = (corners[1] - corners[0]).cross(corners[2] - corners[0])
	light = (v.toward + Vec3(0.0, 0.0, 0.6)).normalized()
	k = 0.3 + 0.7 * ((n.normalized() @ light).abs() if n.length() > 0.0 else 0.0)
	image.Rgba8(u8(f32(tint.r) * k), u8(f32(tint.g) * k), u8(f32(tint.b) * k), 255)

fn cross2(a Vec2, b Vec2) f32:
	a.x * b.y - a.y * b.x

# the triangle's pixels (centers inside it) nearer the eye than what `depth` holds, in `color`
fn fillNearer(mut img image.Image, mut depth f32[], corners Vec3[], v View, color image.Rgba8):
	s = corners.map(v.onScreen(it))
	z = corners.map(it @ v.toward)
	area = cross2(s[1] - s[0], s[2] - s[0])
	if area.abs() < 1.0e-6: return
	x0 = i64(s.map(.x).min() ?? 0.0).max(v.left)
	x1 = i64((s.map(.x).max() ?? 0.0).ceil()).min(v.left + viewWidth - 1)
	y0 = i64(s.map(.y).min() ?? 0.0).max(0)
	y1 = i64((s.map(.y).max() ?? 0.0).ceil()).min(img.height - 1)
	for y in y0..=y1:
		for x in x0..=x1:
			p = Vec2(f32(x) + 0.5, f32(y) + 0.5)
			w0 = cross2(s[2] - s[1], p - s[1]) / area
			w1 = cross2(s[0] - s[2], p - s[2]) / area
			w2 = 1.0 - w0 - w1
			if w0 < 0.0 or w1 < 0.0 or w2 < 0.0: continue
			d = z[0] * w0 + z[1] * w1 + z[2] * w2
			at = y * img.width + x
			if d <= depth[at]: continue
			depth[at] = d
			img[x, y] = color

fn drawView(mut img image.Image, mut depth f32[], parts nif.Part[], tints image.Rgba8[], v View):
	for k, p in parts:
		if tints[k].a < seeThroughAlpha: continue
		for t in 0..p.indices.len / 3:
			corners = (0..3).map(p.positions[i64(p.indices[t * 3 + it])])
			img.fillNearer(depth, corners, v, tints[k].shaded(corners, v))

fn drawHeights(mut img image.Image, framing Framing):
	for h in (0..=160 step 32):
		y = i64(f32(viewHeight) - (f32(h) - framing.lowest) * framing.pixelsPerUnit)
		if y < 0 or y >= img.height: continue
		for x in 0..img.width:
			if x % 4 < 2 or h == 0: img[x, y] = image.Rgba8(90, 90, 120, 255)

# the parts (posed) from the front and from the side, part k in tints[k], framed as `framing`
pub fn drawFigure(parts nif.Part[], tints image.Rgba8[], framing Framing) image.Image:
	img = image.Image(viewWidth * 2, viewHeight, fill = image.Rgba8(24, 24, 32, 255))
	img.drawHeights(framing)
	depth f32[] = []
	loop img.width * img.height:
		depth.push(-1.0e30)
	front = View(across = Vec3(-1.0, 0.0, 0.0), toward = Vec3(0.0, 1.0, 0.0), left = 0, framing)
	img.drawView(depth, parts, tints, front)
	side = View(
		across = Vec3(0.0, 1.0, 0.0),
		toward = Vec3(1.0, 0.0, 0.0),
		left = viewWidth,
		framing
	)
	img.drawView(depth, parts, tints, side)
	img

# the average color of the texture a model names, read from a level about 32 pixels across, its
# alpha weighing each pixel when it is the part's opacity; none when the install lacks it
fn textureAverage(i skyrim.Install, path str, seeThrough bool) image.Rgba8?:
	tex = i.installTexture(nif.textureKey(path)) ?? return none
	level = 0
	while level + 1 < tex.levels and (tex.width >> level) > 32:
		level += 1
	sum = Vec4(0.0, 0.0, 0.0, 0.0)
	cells = tex.decodeLevel(level).cells
	for c in cells:
		a = f32(c.a) / 255.0 if seeThrough else 1.0
		sum += Vec4(f32(c.r) * a, f32(c.g) * a, f32(c.b) * a, a)
	if sum.w <= 0.0: return none
	count = f32(cells.len)
	image.Rgba8(
		u8(sum.x / sum.w),
		u8(sum.y / sum.w),
		u8(sum.z / sum.w),
		image.unitToByte(sum.w / count)
	)

# whether a texture is one the game tints with the hair color (hair, brows, beards)
fn isHairTexture(path str):
	t = path.lower()
	"hair" in t or "brows" in t or "beard" in t

fn tinted(c image.Rgba8, by esm.Color):
	image.Rgba8(u8(c.r * by.r / 255), u8(c.g * by.g / 255), u8(c.b * by.b / 255), c.a)

# whether a texture is skin, which the game lights with the actor's skin tone
fn isSkinTexture(path str):
	t = path.lower().replace("\\", "/")
	("actors/character/" in t or "facegendata" in t) and not t.isHairTexture() and
		"eye" not in t and "mouth" not in t

# a skin texture's color under the skin tone: twice their product, so a gray texture under white
# light shows as it is meant to (the preview's reading of the game's skin tint)
fn toned(c image.Rgba8, tone Vec3):
	image.Rgba8(
		image.unitToByte(2.0 * f32(c.r) / 255.0 * tone.x),
		image.unitToByte(2.0 * f32(c.g) / 255.0 * tone.y),
		image.unitToByte(2.0 * f32(c.b) / 255.0 * tone.z),
		c.a
	)

# The colors the parts are drawn in: each its diffuse texture's average, a hair texture's times
# the hair color as the game tints it, a skin texture's under the skin tone (white when none);
# gray for a part whose texture the install lacks.
pub fn figureTints(
	i skyrim.Install,
	parts nif.Part[],
	hair esm.Color?,
	skinTone Vec3?
) image.Rgba8[]:
	seen {str: image.Rgba8} = {}
	out = []
	for p in parts:
		if p.diffuse not in seen:
			seeThrough = p.alpha.blend or p.alpha.test
			average = i.textureAverage(p.diffuse, seeThrough) ?? image.Rgba8(128, 128, 128, 255)
			seen[p.diffuse.copy()] = average
		c = seen.get(p.diffuse) ?? image.Rgba8(128, 128, 128, 255)
		if hair is h and p.diffuse.isHairTexture(): c = c.tinted(h)
		if p.diffuse.isSkinTexture(): c = c.toned(skinTone ?? Vec3(1.0, 1.0, 1.0))
		out.push(c)
	out

# Compositing a character or a monster the way zrenderer (and the ragassets service built on
# it) does, so the sheets come out as the service drew them: each sprite of the figure (body,
# head, weapon, its slash, the shadow) is placed frame by frame from its ACT, the head on the
# body's anchor point, in the order the client draws them for that facing (the body's IMF says
# when the head goes behind), and every layer is mapped back pixel by pixel through its inverse
# transform (nearest pixel), tinted and blended over the canvas with zrenderer's integer formula.
# Its arithmetic is single precision in the same order as zrenderer's, so a mirrored, scaled or
# rotated layer lands on the same pixels. The feet are at (originX, originY) of the canvas.

import image
import ragnarok.act
import ragnarok.spr

pub kindBody = 0   # a player's body
pub kindHead = 1
pub kindWeapon = 2
pub kindShadow = 3
pub kindMonster = 4

pub type Sprite:
	act act.Act
	spr spr.Spr
	kind i64
	order i64   # a weapon 0, its slash 1

pub type Figure:
	sprites Sprite[]   # the body first, the shadow last
	imf act.Imf?   # a player's head priorities
	player bool

pub canvasSize = 128
pub originX = 64
pub originY = 116

# the 2D transform x' = m11 x + m12 y + m13, y' = m21 x + m22 y + m23 as a Mat3
fn affine(m11 f32, m12 f32, m13 f32, m21 f32, m22 f32, m23 f32):
	Mat3(Vec3(m11, m21, 0.0), Vec3(m12, m22, 0.0), Vec3(m13, m23, 1.0))

# one layer of a frame where it goes: its transform, the pixels it covers (x2 and y2 past the
# last), its tint; `valid` is false for a layer with no image
type Placed:
	valid bool
	m Mat3
	x1 i64
	y1 i64
	x2 i64
	y2 i64
	r i64
	g i64
	b i64
	a i64

fn noLayer():
	Placed(
		valid = false,
		m = Mat3(1.0),
		x1 = 0,
		y1 = 0,
		x2 = 0,
		y2 = 0,
		r = 0,
		g = 0,
		b = 0,
		a = 0
	)

# the image a layer shows, none when its index names none or the image is empty
fn imageOf(s spr.Spr, bank i64, index i64) ref image.Image?:
	if index < 0 or (bank != 0 and bank != 1): return none
	images = s.indexed if bank == 0 else s.rgba
	if index >= images.len or images[index].width <= 0 or images[index].height <= 0: return none
	images[index]

# a layer placed at the offset (px, py): translation, rotation, scale (mirrored: negative x),
# then the image's centre (rounded) moved to the origin
fn place(l act.Layer, w i64, h i64, px f32, py f32, shadow bool):
	m = Mat3(1.0)
	sizeX = 0.0
	sizeY = 0.0
	if l.a != 0:
		mirror = 1.0
		mirrorAdjust = 0.0
		if l.mirrored:
			mirror = -1.0
			mirrorAdjust = 0.5   # zrenderer's correction of the mirrored rounding
		xs = l.xScale
		ys = l.yScale
		if shadow:
			xs = 1.0   # the shadow's scale for every job
			ys = 1.0
		sizeX = f32(w) - mirrorAdjust
		sizeY = f32(h)
		k f32 = 0.017453292519943295
		rad = f32(l.rotation) * k
		sin = rad.sin()
		cos = rad.cos()
		m = m @ affine(1.0, 0.0, f32(l.x) + px, 0.0, 1.0, f32(l.y) + py)
		m = m @ affine(cos, -sin, 0.0, sin, cos, 0.0)
		m = m @ affine(xs * mirror, 0.0, 0.0, 0.0, ys, 0.0)
		half f32 = 0.5
		m = m @ affine(1.0, 0.0, (-sizeX * half).round(), 0.0, 1.0, (-sizeY * half).round())
	a = m @ Vec3(0.0, 0.0, 1.0)
	b = m @ Vec3(sizeX, 0.0, 1.0)
	c = m @ Vec3(0.0, sizeY, 1.0)
	d = m @ Vec3(sizeX, sizeY, 1.0)
	xa = a.x
	xb = b.x
	xc = c.x
	xd = d.x
	ya = a.y
	yb = b.y
	yc = c.y
	yd = d.y
	Placed(
		valid = true,
		m,
		x1 = i64(xa.min(xb).min(xc).min(xd)),
		y1 = i64(ya.min(yb).min(yc).min(yd)),
		x2 = i64(xa.max(xb).max(xc).max(xd)),
		y2 = i64(ya.max(yb).max(yc).max(yd)),
		r = l.r,
		g = l.g,
		b = l.b,
		a = l.a
	)

fn anchorOf(a act.Act, action i64, frame i64) act.Anchor?:
	frames = try a.framesOf(action)
	if frame < 0 or frame >= frames.len or frames[frame].anchors.isEmpty: return none
	frames[frame].anchors[0]

# The layers of every frame of an action of sprite k, placed; a head moved so that its anchor
# meets the body's anchor of the frame with the same number.
fn placeAction(fig Figure, k i64, action i64):
	s = fig.sprites[k]
	out = []
	if action < 0 or action >= s.act.actions.len: return out
	frames = s.act.actions[action]
	for f, frame in frames:
		px = 0.0
		py = 0.0
		if s.kind == kindHead:
			if fig.sprites[0].act.anchorOf(action, f) is p:
				px += f32(p.x)
				py += f32(p.y)
			if s.act.anchorOf(action, f) is p:
				px -= f32(p.x)
				py -= f32(p.y)
		placed = []
		for l in frame.layers:
			match s.spr.imageOf(l.bank, l.image):
				img: placed.push(l.place(img.width, img.height, px, py, s.kind == kindShadow))
				none: placed.push(noLayer())
		out.push(placed)
	out

# the pose of an action (standing 0, sitting 16, ...), 255 past the player's poses
fn poseOf(action i64):
	base = action - action % 8
	255 if base > 96 else base

fn standing(action i64):
	pose = poseOf(action)
	pose == 0 or pose == 16

# which frame of sprite k output frame i shows: (its geometry frame, the frame its images come
# from, the action), as zrenderer picks it: the shadow is frame 0 of action 0, a standing head
# turns through its three directions over the animation, and a short sprite repeats
type Pick:
	frame i64
	imageFrame i64
	action i64

fn pick(s Sprite, action i64, i i64, maxFrames i64, count i64):
	act = action
	frame = i
	offset = 0
	if s.kind == kindShadow:
		act = 0
		frame = 0
	elif s.kind == kindHead and standing(action):
		n = s.act.frameCount(action)
		if maxFrames >= 3:
			frame = i / (maxFrames / 3)
		elif n >= 3:
			offset = i * n / 3 - frame
	if frame >= count:
		frame = i / (maxFrames / 3) % count if count == 3 and maxFrames >= 3 else frame % count
	Pick(frame, imageFrame = frame + offset, action = act)

# the draw order of sprite k in output frame i: lower first
fn depthOf(fig Figure, k i64, action i64, i i64, maxFrames i64):
	s = fig.sprites[k]
	if s.kind == kindShadow: return -1
	f = i / (maxFrames - 1) if maxFrames > 3 and standing(action) else i
	headFirst = false
	if s.kind == kindHead:
		if fig.imf is m:
			headFirst = m.imfPriority(1, action, f) == 1
	dir = action % 8
	if dir >= 2 and dir <= 5:
		return 15 if s.kind == kindBody
			else (14 if headFirst else 20) if s.kind == kindHead
			else 30 - (2 - s.order) if s.kind == kindWeapon
			else 0
	10 if s.kind == kindBody
		else (9 if headFirst else 15) if s.kind == kindHead
		else 25 - (2 - s.order) if s.kind == kindWeapon
		else 0

# whether the shadow is drawn: not under a sitting or dead player, nor a dead monster
fn shadowShown(fig Figure, action i64):
	pose = action - action % 8
	pose != 16 and pose != 64 if fig.player else pose != 32

# Every frame of an action as zrenderer animates it, on canvases of `size` pixels whose origin
# (the feet) is at (ox, oy): canvasSize, its feet at (originX, originY), unless asked. An action
# whose body has one frame gives that one frame.
# a layer's depth, the first of its (depth, position) pair
fn orderDepth(layer (i64, i64)):
	depth, _ = layer
	depth

pub fn renderAction(
	fig Figure,
	action i64,
	size i64 = canvasSize,
	ox i64 = originX,
	oy i64 = originY
) image.Image[]:
	active = []
	for k, s in fig.sprites:
		if s.kind != kindShadow or fig.shadowShown(action):
			active.push(k)
	placed = []
	maxFrames = 0
	for k in active:
		p = fig.placeAction(k, 0 if fig.sprites[k].kind == kindShadow else action)
		maxFrames = maxFrames.max(p.len)
		placed.push(p)
	out = []
	if maxFrames == 0: return out
	frames = 1 if fig.sprites[0].act.frameCount(action) <= 1 else maxFrames
	for i in 0..frames:
		order = []   # (depth, position in active)
		for a, k in active:
			order.push((fig.depthOf(k, action, i, maxFrames), a))
		for x in 1..order.len:   # a stable insertion sort
			y = x
			while y > 0 and orderDepth(order[y - 1]) > orderDepth(order[y]):
				t = order[y]
				order[y] = order[y - 1]
				order[y - 1] = t
				y -= 1
		canvas = image.Image(size, size, fill = image.Rgba8(0, 0, 0, 0))
		for (_, a) in order:
			k = active[a]
			s = fig.sprites[k]
			count = placed[a].len
			if count == 0: continue
			p = s.pick(action, i, maxFrames, count)
			geometry = placed[a][p.frame]
			frameList = s.act.framesOf(p.action) ?? continue
			if p.imageFrame < 0 or p.imageFrame >= frameList.len: continue
			layers = frameList[p.imageFrame].layers
			for li, g in geometry:
				if li >= layers.len or not g.valid: continue
				if s.spr.imageOf(layers[li].bank, layers[li].image) is img:
					canvas.drawLayer(g, img, ox, oy)
		out.push(canvas)
	out

# a layer's pixels blended over the canvas: each canvas pixel of its box mapped back to the
# nearest image pixel
fn drawLayer(mut canvas image.Image, g Placed, img image.Image, ox i64, oy i64):
	if g.a == 0: return
	inv = g.m.inverse()
	w = (g.x2 - g.x1).abs()
	h = (g.y2 - g.y1).abs()
	bx = f32(g.x1)
	by = f32(g.y1)
	for ty in 0..h:
		dy = ty + g.y1 + oy
		if dy < 0 or dy >= canvas.height: continue
		fy = f32(ty) + by
		for tx in 0..w:
			dx = tx + g.x1 + ox
			if dx < 0 or dx >= canvas.width: continue
			fx = f32(tx) + bx
			source = inv @ Vec3(fx, fy, 1.0)
			sx = source.x.round()
			sy = source.y.round()
			if sx < 0.0 or sy < 0.0 or i64(sx) >= img.width or i64(sy) >= img.height: continue
			texel = img[i64(sx), i64(sy)]
			sa = i64(texel.a)
			if sa == 0: continue
			canvas[dx, dy] = blended(
				canvas[dx, dy],
				g.r * texel.r / 255,
				g.g * texel.g / 255,
				g.b * texel.b / 255,
				g.a * sa / 255
			)

# zrenderer's alpha blend of (r, g, b, a) over the canvas pixel c
fn blended(c image.Rgba8, r i64, g i64, b i64, a i64):
	da = i64(c.a)
	if da == 0 or a == 255: return image.Rgba8(u8(r), u8(g), u8(b), u8(a))
	na = a + da * (255 - a) / 255
	if na == 0: return image.Rgba8(0, 0, 0, 0)
	image.Rgba8(
		u8((r * a / 255 + c.r * da * (255 - a) / 65_025) * 255 / na),
		u8((g * a / 255 + c.g * da * (255 - a) / 65_025) * 255 / na),
		u8((b * a / 255 + c.b * da * (255 - a) / 65_025) * 255 / na),
		u8(na)
	)

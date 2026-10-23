# The hero drawn as the client draws a player: its sprites (body, head, weapon, shadow) read from
# the install and composited frame by frame (projects/ragnarok/render.zap) for standing and walking in
# the eight directions when the game is prepared, kept in one atlas in its prepared file, and
# shown as a quad facing the camera at its feet, sampled sharp at any size (a cell 35 texels
# wide), the frame the action's ACT interval picks (walking frames sped to the walk speed, as
# roBrowser does), shaded by the ground's baked shadow where it stands.

import engine
import ragnarok
import world
import game.shaders
import image

# what the hero's prepared file holds besides its atlas's pixels
pub type FigureHead:
	columns i64
	cellSize i64   # the canvas of a frame, its feet at (64, 116)
	atlas world.PreparedTexture
	actions i64[,]   # per action (stand 0-7, walk 8-15): its atlas cells
	delays f32[]   # per action: milliseconds a frame

pub type Figures:
	program engine.Program
	atlas engine.GpuTexture
	columns i64
	actions i64[,]
	delays f32[]
	quad engine.Model

# the hero's look: a knight (기사), male, head 4, with a sword
job = "기사"
head = 4
weapon = "_검"
pixelsPerCell f32 = 35.0
walkAction = 8
# how far toward the camera the figure's depth is taken (cells)
lift f32 = 1.5
# how much of the hero shows through what hides it
ghost f32 = 0.35

fn figuresPath():
	"{world.preparedDir}/hero.figure"

# The hero's frames composited from the install and written to its prepared file.
pub fn prepareFigures(i ragnarok.Install):
	shadow = i.needSprite("shadow", ragnarok.kindShadow)
	fig = i.playerFigure(job, false, head, weapon, shadow)
	images = []
	actions = []
	delays = []
	body = fig.sprites[0].act
	for action in 0..16:
		cells = []
		for img in fig.renderAction(action):
			cells.push(images.len)
			images.push(img)
		actions.push(cells)
		delays.push(body.delays[action] if action < body.delays.len else 100.0)
	size = ragnarok.canvasSize
	columns = 16
	pixels = []
	atlas = world.appendTexture(pixels, atlasOf(images, size, columns), false)
	head = FigureHead(columns, cellSize = size, atlas, actions, delays)
	world.writePrepared(figuresPath(), head.toBytes(), pixels) ??
		fail("cannot write {figuresPath()}: {error}")

# square images `size` wide in one image, `columns` to a row, left to right and top to bottom
fn atlasOf(images image.Image[], size i64, columns i64):
	rows = (images.len + columns - 1) / columns
	atlas = image.Image(columns * size, rows * size, fill = image.Rgba8(0, 0, 0, 0))
	for k, img in images:
		atlas.paste(img, (k % columns) * size, (k / columns) * size)
	atlas

# the hero's frames read from its prepared file and sent to the GPU (filtered, for the sprite
# shader's sharp sampling; no mipmaps), none when the file is missing or of another version
pub fn openFigures() Figures?:
	file = try world.readPrepared(figuresPath())
	h = try FigureHead.fromBytes(file.headOf().copy())
	if h.cellSize != ragnarok.canvasSize: return none
	atlas = engine.newTexture(
		world.imageAt(file.bodyOf(), h.atlas),
		engine.Sampling(
			smooth = true,
			mipmaps = false,
			repeat = false,
			mirror = 0,
			anisotropy = false
		)
	)
	Figures(
		program = engine.newProgram(shader(shaders.figureVertex, shaders.figurePixel)),
		atlas,
		columns = h.columns,
		actions = h.actions,
		delays = h.delays,
		quad = engine.newDynamicModel())

# the frame of an action shown `ms` into it: standing, the one of the head's direction (the
# composited standing frames are the body with the head ahead, then turned aside, never played
# in turn); walking, the frames at the action's interval sped to the walk speed, as the client
# times the body (the head and the weapon follow the body's frame)
fn frameOf(f Figures, h Hero, action i64):
	n = f.actions[action].len
	if not h.walking: return h.headDir.clamp(0, n - 1)
	delay = f.delays[action] * f32(walkSpeed) / 150.0
	i64((f32(h.animMs) / delay.max(1.0)).floor()) % n

# The hero's frame of the moment drawn at its place: blended over the map, tested against its
# depth but not written to it.
pub fn drawHero(
	mut r engine.Renderer,
	mut f Figures,
	h Hero,
	z world.Zone,
	projection Mat4,
	view Mat4,
	c Camera
):
	# the direction drawn: the hero's facing as the camera, turned, sees it
	shown = (h.facing + c.facingSteps()) % 8
	action = (walkAction if h.walking else 0) + shown
	cells = f.actions[action]
	if cells.isEmpty: return
	cell = cells[f.frameOf(h, action)]
	size = f32(ragnarok.canvasSize)
	tw = f32(f.atlas.width)
	th = f32(f.atlas.height)
	u0 = f32(cell % f.columns) * size / tw
	v0 = f32(cell / f.columns) * size / th
	u1 = u0 + size / tw
	v1 = v0 + size / th
	# the canvas's feet are at (64, 116); the corners in cells from them
	left = -64.0 / pixelsPerCell
	right = (size - 64.0) / pixelsPerCell
	top = 116.0 / pixelsPerCell
	bottom = -(size - 116.0) / pixelsPerCell
	at = h.place(z.gat)
	shade = z.shadowAt(at.x, -at.z)
	quad = []
	for (x, y, u, v) in [
		(left, bottom, u0, v1),
		(right, bottom, u1, v1),
		(right, top, u1, v0),
		(left, bottom, u0, v1),
		(right, top, u1, v0),
		(left, top, u0, v0)
	]:
		quad.push(
			shaders.FigureVertex(
				anchor = at,
				corner = Vec3(x, y, 0.0),
				uvShade = Vec3(u, v, shade)
			)
		)
	f.quad.fillModel(quad)
	r.setBlending(true)
	# first faint and over everything, so the hero shows through a house or a wall the camera
	# looks past (it never moves to see around them); then as it is, where nothing hides it
	params = shaders.FigureParams(
		projection,
		view,
		lift = lift,
		opacity = ghost,
		picture = f.atlas.texture()
	)
	f.program.setParams(params)
	r.setDepth(false, false, false)
	r.drawModel(f.program, f.quad)
	params.opacity = 1.0
	f.program.setParams(params)
	r.setDepth(true, false, false)
	r.drawModel(f.program, f.quad)
	r.setDepth(true, true, false)

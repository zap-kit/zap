# A pass as a backend keeps it: its targets, their size, formats and samples, and what its draws
# last set (a draw sets only what changes). The state a draw's pipeline needs besides its
# program and layout is packed in bits, the same for every backend.

# the pass being drawn, and what its draws last set
pub type Pass:
	active bool
	color i64   # a texture, screenTarget, or noTarget
	depth i64   # a texture, or noTarget
	width i64
	height i64
	colorFormat i64
	depthFormat i64
	samples i64
	screenTouched bool   # the swapchain image was drawn into this frame
	pipeline i64 = 0   # what the pass's draws last set
	index i64 = 0   # the index buffer (a backend's handle, 0 none)
	layout i64 = 0   # the pipeline layout or root signature they last set
	topology i64 = -1
	state i64 = -1   # the state bits (stateBits)

pub fn noPass() Pass:
	Pass(
		active = false,
		color = noTarget,
		depth = noTarget,
		width = 0,
		height = 0,
		colorFormat = fmtUndefined,
		depthFormat = fmtUndefined,
		samples = 1,
		screenTouched = false
	)

# The state of a draw into the pass, in bits: culling (bit 0), front faces counter-clockwise
# (bit 1 clear: the screen's) or clockwise (a target's: the same faces seen without the
# screen's flip), the depth test (2), the depth write (3), the depth bias (bits 4-5: 1 a shadow
# map's, pushed back; 2 a decal's, pulled forward).
pub fn stateBits(p Pass, call DrawCall) i64:
	withDepth = p.depth != noTarget
	cull = 1 if call.cull else 0
	front = 0 if p.color == screenTarget else 1
	test = 1 if call.depthTest and withDepth else 0
	write = 1 if call.depthWrite and withDepth else 0
	bias = 1 if call.depthBias else 2 if call.decal else 0
	cull | front << 1 | test << 2 | write << 3 | bias << 4

# the constant and the slope of a depth bias kind (bits 4-5 of the state)
pub fn depthBiasOf(kind i64) (f32, f32):
	if kind == 1: return (2.0, 4.0)
	if kind == 2: return (-2.0, -2.0)
	(0.0, 0.0)

# the pixels of a capture as r, g, b, a from the screen's b, g, r (its alpha opaque: the screen
# shows no see-through, its alpha is what blending left)
pub fn rgbaOf(move bgra u8[], pixels i64) u8[]:
	rgba = bgra
	for i in 0..pixels:
		blue = rgba[i * 4]
		rgba[i * 4] = rgba[i * 4 + 2]
		rgba[i * 4 + 2] = blue
		rgba[i * 4 + 3] = 255
	rgba

# The pass into the color target (a texture, the screen, or none) and the depth target (a
# texture or none): their size, formats and samples, open.
pub fn openPass(s DeviceState, color i64, depth i64) Pass:
	p = noPass()
	p.active = true
	p.color = color
	p.depth = depth
	p.screenTouched = s.pass.screenTouched or color == screenTarget
	if color == screenTarget:
		p.width = s.width
		p.height = s.height
		p.colorFormat = screenFormat
	elif color >= 0:
		t = s.textures[color]
		p.width = t.width
		p.height = t.height
		p.colorFormat = t.format
		p.samples = t.samples
	if depth >= 0:
		t = s.textures[depth]
		p.width = t.width
		p.height = t.height
		p.depthFormat = t.format
		p.samples = t.samples
	p

# Whether a draw draws anything (its counts are not 0), counted when it does. A draw outside a
# pass stops the program.
pub fn drawReady(mut s DeviceState, call DrawCall) bool:
	if not s.pass.active:
		fail("rhi: a draw outside a pass")
	if call.indirect < 0 and (call.count <= 0 or call.instances <= 0) or
		call.indirect >= 0 and call.drawCount <= 0:
		return false
	s.stats.draws += 1
	true

# Whether a draw binds its pipeline and its index buffer (0 none): each when it differs from what
# the pass's last draw bound, which it becomes. Counted.
pub fn drawBinds(mut s DeviceState, pipeline i64, index i64) (bool, bool):
	bindsPipeline = pipeline != s.pass.pipeline
	s.pass.pipeline = pipeline
	s.stats.pipelineBinds += 1 if bindsPipeline else 0
	s.stats.pipelinesSkipped += 0 if bindsPipeline else 1
	if index == 0: return (bindsPipeline, false)
	bindsIndex = index != s.pass.index
	s.pass.index = index
	s.stats.indexBinds += 1 if bindsIndex else 0
	s.stats.indexSkipped += 0 if bindsIndex else 1
	(bindsPipeline, bindsIndex)

# The draw recorded as its kind is: of the call's counts or of a buffer of commands, indexed when
# it names an index buffer.
pub fn recordDraw<B Backend>(mut b B, call DrawCall):
	indexed = call.indexBuffer != 0
	if call.indirect >= 0:
		b.drawIndirect(call, indexed)
	else:
		b.drawDirect(call, indexed)

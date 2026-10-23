# Drawing off the screen, for effects: render targets (a color texture, a depth texture, or
# both), read by shaders as a Texture (colorTexture) or a ShadowMap (shadowMap), and passes that
# run a pixel stage over a whole target (a sky, a blur, the final image).

import rhi
import rhi.core

pub type RenderTarget:
	color i64   # its color texture (-1: none)
	depth i64   # its depth texture (-1: none)
	width i64
	height i64
	samples i64   # 1, or a multisampled target's: read only by resolving it

	# its color texture, read by a shader's Texture
	pub fn colorTexture() Texture:
		Texture(id = color, width, height)

	# its depth texture, read by a shader's Texture (its depths in r)
	pub fn depthTexture() Texture:
		Texture(id = depth, width, height)

	# a shadow target's depth, read by a shader's ShadowMap
	pub fn shadowMap() ShadowMap:
		ShadowMap(id = depth, size = width)

	# its textures freed where it is dropped, the pass drawing into it ended first
	mut fn drop():
		drawQueued()
		p = gpu.currentPass()
		if p.active and (color >= 0 and p.color == color or depth >= 0 and p.depth == depth):
			gpu.endPass()
		for id in [color, depth]:
			if id >= 0:
				gpu.destroyTexture(id)

# a pass over a whole target: its program, drawn as one triangle that covers it
pub type ScreenPass:
	program Program

# a depth texture read with comparisons (a shadow map: smoothed between texels, lit beyond its
# edges), as a shader's ShadowMap
pub type ShadowMap:
	id i64
	size i64

# A target of w x h pixels with a color texture (half floats when `hdr`: values above 1 kept for
# bloom; smoothed when sampled) and, when `withDepth`, a depth texture.
pub fn newRenderTarget(w i64, h i64, hdr bool, withDepth bool) RenderTarget:
	color = gpu.newTexture(core.TextureDesc(
		width = w,
		height = h,
		layers = 1,
		levels = 1,
		format = core.fmtRgba16Float if hdr else core.fmtRgba8,
		samples = 1,
		array = false, target = true))
	rhi.setSampler(
		gpu,
		color,
		core.SamplerDesc(
			smooth = true,
			mipmaps = 0,
			repeat = false,
			mirror = 0,
			anisotropy = false,
			compare = false
		)
	)
	depth = -1
	if withDepth:
		depth = rhi.newTexture(
			gpu,
			core.TextureDesc(
				width = w,
				height = h,
				layers = 1,
				levels = 1,
				format = core.fmtD32,
				samples = 1,
				array = false,
				target = true
			)
		)
	RenderTarget(color, depth, width = w, height = h, samples = 1)

# A target of only depth, w x h, to draw on the screen with (useScreenWithDepth)
pub fn newDepthTarget(w i64, h i64) RenderTarget:
	depth = rhi.newTexture(
		gpu,
		core.TextureDesc(
			width = w,
			height = h,
			layers = 1,
			levels = 1,
			format = core.fmtD32,
			samples = 1,
			array = false,
			target = true
		)
	)
	RenderTarget(color = -1, depth, width = w, height = h, samples = 1)

# what the renderer draws next goes to the screen, tested against and written into the depth of
# `t` (the screen's size)
pub fn useScreenWithDepth(mut r Renderer, t RenderTarget):
	r.chooseTarget(core.screenTarget, t.depth)

# A target of only depth, size x size, for a shadow map: sampled with comparison (a shader's
# ShadowMap, smoothed between texels), lit beyond its edges.
pub fn newShadowTarget(size i64) RenderTarget:
	newShadowTargetBy(size, size)

# a shadow target of w x h
pub fn newShadowTargetBy(w i64, h i64) RenderTarget:
	depth = rhi.newTexture(
		gpu,
		core.TextureDesc(
			width = w,
			height = h,
			layers = 1,
			levels = 1,
			format = core.fmtD16,
			samples = 1,
			array = false,
			target = true
		)
	)
	rhi.setSampler(
		gpu,
		depth,
		core.SamplerDesc(
			smooth = true,
			mipmaps = 0,
			repeat = false,
			mirror = 0,
			anisotropy = false,
			compare = true
		)
	)
	RenderTarget(color = -1, depth, width = w, height = h, samples = 1)

# A target of w x h pixels drawn with `samples` samples a pixel (half-float color, depth): its
# edges smooth once it is resolved into a plain target of the same size.
pub fn newMultisampleTarget(w i64, h i64, samples i64) RenderTarget:
	color = rhi.newTexture(
		gpu,
		core.TextureDesc(
			width = w,
			height = h,
			layers = 1,
			levels = 1,
			format = core.fmtRgba16Float,
			samples,
			array = false,
			target = true
		)
	)
	depth = rhi.newTexture(
		gpu,
		core.TextureDesc(
			width = w,
			height = h,
			layers = 1,
			levels = 1,
			format = core.fmtD32,
			samples,
			array = false,
			target = true
		)
	)
	RenderTarget(color, depth, width = w, height = h, samples)

# a multisampled target's samples averaged into the color of `into` (a plain target)
pub fn resolveTarget(from RenderTarget, into RenderTarget):
	drawQueued()
	gpu.resolve(from.color, into.color)

# what the renderer draws next goes to the target (its whole area)
pub fn useTarget(mut r Renderer, t RenderTarget):
	chooseTarget(
		r,
		t.color if t.color >= 0 else core.noTarget,
		t.depth if t.depth >= 0 else core.noTarget
	)

# ---------- passes over a whole target ----------

# A pass whose pixel stage runs once per pixel of the target: the program the compiler built of
# a pixel stage alone (shader(blur.pixel)), whose first parameter is where it is across the
# target (0..1, a Vec2).
pub fn newScreenPass(code str) ScreenPass:
	ScreenPass(program = newProgram(code))

# runs the pass over the renderer's target with its parameters
pub fn drawScreenPass<P GpuParams>(r Renderer, pass ScreenPass, params P):
	setParams(pass.program, params)
	drawGenerated(r, pass.program, 3)

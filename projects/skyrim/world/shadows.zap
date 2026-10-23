# The shadow maps of a cell's shadow lights (the first of its lights, at most four as in Skyrim):
# each light's two hemispheres drawn into maps of their own every frame (shaders/shadow.gpu.zap)
# from the cell's opaque and cut-out runs, and read by the cell's pixel stage.

import engine
import world.shaders

# the most lights casting shadows at once, and a hemisphere's map's width (the game's
# iShadowMapResolution); the game draws both hemispheres into one map, each half its height
# (Community Shaders' Utility.hlsl, RENDER_SHADOWMASKDPB)
maxShadowLights = 4
mapSize = 2048

pub type CellShadows:
	program engine.Program
	count i64
	maps engine.RenderTarget[]   # two a light, then texels standing for the maps no light uses

pub fn newCellShadows(lights shaders.PointLight[]) CellShadows:
	count = lights.filter(.flicker.w > 0.5).len.min(maxShadowLights)
	CellShadows(
		program = engine.newProgram(shader(shaders.shadowVertex, shaders.shadowPixel)),
		count,
		maps = (0..maxShadowLights * 2).map(
			engine.newShadowTargetBy(
				mapSize if it < count * 2 else 1,
				mapSize / 2 if it < count * 2 else 1
			)
		)
	)

# the maps as the cell's params read them
pub fn useShadows(mut p shaders.CellParams, s CellShadows):
	p.shadowCount = i32(s.count)
	m = s.maps.map(.shadowMap())
	p.shadow0 = m[0]
	p.shadow1 = m[1]
	p.shadow2 = m[2]
	p.shadow3 = m[3]
	p.shadow4 = m[4]
	p.shadow5 = m[5]
	p.shadow6 = m[6]
	p.shadow7 = m[7]

# every shadow light's maps drawn as the lights are now
pub fn drawShadowMaps(mut r engine.Renderer, sc CellScene):
	s = sc.shadows
	p = sc.params.copy()
	r.setBlending(false)
	r.setDepthBias(true)
	for i in 0..s.count:
		for k in 0..2:
			r.useTarget(s.maps[i * 2 + k])
			r.clearTarget(engine.white)
			r.setDepth(true, true, false)
			p.shadowLight = p.lights[i].place
			p.shadowSide = 1.0 if k == 0 else -1.0
			s.program.setParams(p)
			for run in sc.runs:
				if run.kind != .Opaque and run.kind != .Tested: continue
				r.drawIndexed(s.program, sc.model, sc.indices, run.count, firstIndex = run.first)
	r.setDepthBias(false)

# A rail shaped like a rate curve: the DI1F31 future's settlement rates of a stretch of sessions
# (projects/skate3/assets/di1f31.csv: date;rate;pu, from B3's daily settlement file), one session every
# `spacing` meters, the height the rate, its end near the ground. A rider in shirt and tie
# (projects/skate3/assets/suit.glb, a skinned biped) grinds it down in a 50-50 on the game's board, pops
# off its end and lands; beside him, in Tony Hawk's style, the session's date, its rate and the
# return of the contract since the first session (its settlement price, PU, against the first
# one's): the rate falls, the price rises.
#
#   zap run projects/skate3/rail.zap --find                         a flat, open stretch for the rail
#   zap run projects/skate3/rail.zap                                watch it (Esc leaves)
#   zap run projects/skate3/rail.zap --record build/rail            each frame to build/rail/00000.png
#   ffmpeg -framerate 30 -i build/rail/%05d.png -c:v libx264 -pix_fmt yuv420p -crf 22 rail.mp4

import engine
import fs
import game
import graphics
import graphics.shaders
import image
import rw4
import skate
import image
import math

# where the rail starts (x, z) and the way it runs (radians about y; 0 is +x): --find's choice
railX f32 = 354.0
railZ f32 = -326.0
railYaw f32 = 4.7124
spacing f32 = 1.1   # meters between two sessions
metersPerPoint f32 = 2.2   # height per percentage point of rate
lowest f32 = 0.55   # the rail's lowest point above the ground
runout f32 = 16.0   # flat ground wanted past the rail's end
fps i64 = 30
grindSeconds f32 = 15.0
afterSeconds f32 = 4.5   # from leaving the rail to the end
gravity f32 = 9.8

type Session:
	date str
	rate f32
	pu f64

fn readSessions(path str):
	text = fs.readFile(path) ?? fail("{path}: run the download first")
	out = []
	for line in text.lines():
		parts = line.trimmed().split(";")
		if parts.len != 3 or parts[0] == "date": continue
		out.push(
			Session(
				date = parts[0].copy(),
				rate = f32(f64.parse(parts[1]) ?? 0.0),
				pu = f64.parse(parts[2]) ?? 0.0
			)
		)
	out

# ---------- the place ----------

# Places near the career start for the rail: its last stretch and the runout flat (where he
# comes down and rolls away), and nothing along it reaching up to the rail and the rider over
# it (heights from the ground at its end). The district's collision triangles are laid once on
# a map of 2 m cells, each cell the highest point of the triangles over it. Prints the best few,
# the nearest to the start first among the flattest.
fn findStretch(soup rw4.CollisionSoup, sessions Session[], low f32):
	cell f32 = 2.0
	span = 700
	x0 = 330.0 - f32(span) * cell / 2.0
	z0 = -710.0 - f32(span) * cell / 2.0
	heights = fill(span * span, -f32(1.0e9))
	c = soup.corners
	for t in 0..soup.surfaces.len:
		at = t * 9
		lx = i64(((c[at].min(c[at + 3]).min(c[at + 6]) - x0) / cell).floor()).max(0)
		hx = i64(((c[at].max(c[at + 3]).max(c[at + 6]) - x0) / cell).floor()).min(span - 1)
		lz = i64(((c[at + 2].min(c[at + 5]).min(c[at + 8]) - z0) / cell).floor()).max(0)
		hz = i64(((c[at + 2].max(c[at + 5]).max(c[at + 8]) - z0) / cell).floor()).min(span - 1)
		top = c[at + 1].max(c[at + 4]).max(c[at + 7])
		for gx in lx..=hx:
			for gz in lz..=hz:
				heights[gz * span + gx] = heights[gz * span + gx].max(top)
	heightAt = (p Vec3):
		ix = i64(((p.x - x0) / cell).floor())
		iz = i64(((p.z - z0) / cell).floor())
		-f32(1.0e9) if ix < 0 or iz < 0 or ix >= span or iz >= span else heights[iz * span + ix]
	last = f32(sessions.len - 1)
	length = last * spacing
	found = []   # (spread, x, z, yaw)
	for gx in -50..51:
		for gz in -50..51:
			for k in 0..24:
				x = 330.0 + f32(gx) * 12.0
				z = -710.0 + f32(gz) * 12.0
				yaw = f32(k) / 24.0 * 2.0 * pi
				along = Vec3(yaw.cos(), 0.0, -yaw.sin())
				side = Vec3(0.0, 1.0, 0.0).cross(along).normalized() * -1.0
				start = Vec3(x, 0.0, z)
				base = heightAt(start + along * length)
				if base < -1.0e8: continue
				spread = 0.0
				ok = true
				d = 0.0
				while d <= length + runout and ok:
					rail = lowest + (rateAt(sessions, d / spacing) - low) * metersPerPoint if d <=
						length
						else 0.0
					for off in [-1.2, 0.0, 1.2]:
						h = heightAt(start + along * d + side * f32(off)) - base
						if h < -1.0e8 or h > rail - 0.15 and d < length - 1.0 or
							h > 2.6 and rail < 0.1:
							ok = false
						spread = spread.max(h.abs())
					# the camera's side open: nothing above the rider's head between him and it
					if heightAt(start + along * d + side * 5.0) - base > rail + 2.0:
						ok = false
					d += 2.0
				if ok and spread < 0.3:
					found.push(
						(
							spread + (Vec3(x, 0.0, z) - Vec3(330.0, 0.0, -710.0)).length() * 0.002,
							x,
							z,
							yaw
						)
					)
	# the best few checked against the triangles themselves: ground under every step of the
	# landing, as flat as the map said
	shown = 0
	printed Vec3[] = []
	for (score, atX, atZ, heading) in found.sorted():
		if shown >= 12: break
		along = Vec3(heading.cos(), 0.0, -heading.sin())
		start = Vec3(atX, 0.0, atZ)
		base = game.groundBelow(
			soup,
			(start + along * length).x,
			(start + along * length).z,
			10000.0
		) ??
			-1.0e9
		ok = base > -1.0e8
		d = 0.0
		while d <= length + runout and ok:
			p = start + along * d
			h = soup.groundBelow(p.x, p.z, 10000.0) ?? -1.0e9
			ok = (h - base).abs() < 0.4
			d += 3.0
		if ok and not printed.any((it - start).length() < 40.0):
			print("score {score:.2} at {atX:.0}, {atZ:.0} yaw {heading:.4}")
			printed.push(start)
			shown += 1
	if shown == 0:
		print("no stretch found")

# ---------- geometry, in the skater's vertices ----------

fn pushTriangle(mut out shaders.SkaterVertex[], a Vec3, b Vec3, c Vec3):
	n = (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		out.push(
			shaders.SkaterVertex(
				position = p,
				normal = n,
				uv = Vec3(0.0, 0.0, 0.0),
				spare = 0.0
			)
		)

fn pushQuad(mut out shaders.SkaterVertex[], a Vec3, b Vec3, c Vec3, d Vec3):
	pushTriangle(out, a, b, c)
	pushTriangle(out, a, c, d)

# a prism of `sides` faces around the segment from a to b, `r` from it
fn pushTube(mut out shaders.SkaterVertex[], a Vec3, b Vec3, r f32, sides i64):
	axis = (b - a).normalized()
	helper = Vec3(1.0, 0.0, 0.0) if axis.y.abs() > 0.9 else Vec3(0.0, 1.0, 0.0)
	u = axis.cross(helper).normalized()
	v = axis.cross(u)
	ring = (0..sides).map(i:
		t = f32(i) / f32(sides) * 2.0 * pi
		u * (t.cos() * r) + v * (t.sin() * r)
	)
	for i in 0..sides:
		j = (i + 1) % sides
		pushQuad(out, a + ring[i], a + ring[j], b + ring[j], b + ring[i])
	for i in 1..sides - 1:
		pushTriangle(out, a + ring[0], a + ring[i + 1], a + ring[i])
		pushTriangle(out, b + ring[0], b + ring[i], b + ring[i + 1])

# the positions of a mesh of the skater's (its vertices' first three floats)
fn positionsOf(m skate.SkaterMesh):
	stride = 40
	(0..m.vertices.len / stride).map(i:
		Vec3(
			m.vertices.f32le(i * stride),
			m.vertices.f32le(i * stride + 4),
			m.vertices.f32le(i * stride + 8)
		)
	)

# the lowest and the highest point of the skater's meshes of a slot
fn heightsOf(s skate.Skater, slot str):
	lo f32 = 1.0e9
	hi f32 = -1.0e9
	for m in s.meshes:
		if m.slot != slot: continue
		for p in m.positionsOf():
			lo = lo.min(p.y)
			hi = hi.max(p.y)
	(lo, hi)

fn partOf(
	vertices shaders.SkaterVertex[],
	tint Vec4,
	white engine.Texture,
	program engine.Program
):
	graphics.SkaterPart(
		texture = white,
		tint,
		alphaTest = false,
		model = engine.newModel(vertices.rawBytes(), program.vertexStride)
	)

# ---------- the rail ----------

fn rateAt(sessions Session[], i f32):
	n = sessions.len
	k = i64(i.floor()).clamp(0, n - 1)
	t = (i - f32(k)).clamp(0.0, 1.0)
	sessions[k].rate * (1.0 - t) + sessions[(k + 1).min(n - 1)].rate * t

fn puAt(sessions Session[], i f32):
	n = sessions.len
	k = i64(i.floor()).clamp(0, n - 1)
	t = f64((i - f32(k)).clamp(0.0, 1.0))
	sessions[k].pu * (1.0 - t) + sessions[(k + 1).min(n - 1)].pu * t

fn railPoint(sessions Session[], i f32, origin Vec3, along Vec3, low f32):
	origin + along * (i * spacing) +
		Vec3(0.0, lowest + (rateAt(sessions, i) - low) * metersPerPoint, 0.0)

# ---------- the numbers ----------

# 61657.68 as "61.657,68"
fn brazilian(v f64, decimals i64):
	text = "{v:.3}" if decimals == 3 else "{v:.2}" if decimals == 2 else "{v:.0}"
	whole, cents = match text.indexOf("."):
		at: (text[..at].copy(), text[at + 1..].copy())
		none: (text.copy(), "")
	grouped = ""
	for i in 0..whole.len:
		if i > 0 and (whole.len - i) % 3 == 0:
			grouped += "."
		grouped += whole[i..i + 1]
	"{grouped},{cents}" if decimals > 0 else grouped

# "+12,15%"
fn returnText(r f64):
	"{"+" if r >= 0.0 else "-"}{brazilian(r.abs(), 2)}%"

months = ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"]

# "2026-07-09" as "09 JUL 2026"
fn dateText(d str):
	m = (i64.parse(d[5..7]) ?? 1).clamp(1, 12)
	"{d[8..10]} {months[m - 1]} {d[..4]}"

# text with a dark outline, Tony Hawk's way: drawn shifted around in black, then on top
fn outlined(mut r engine.Renderer, f engine.Font, text str, x f32, y f32, c Vec4, width f32):
	shade = Vec4(0.0, 0.0, 0.0, c.a * 0.9)
	for k in 0..12:
		a = f32(k) / 12.0 * 2.0 * pi
		r.drawText(f, text, x + a.cos() * width, y + a.sin() * width, shade)
	r.drawText(f, text, x, y, c)

fn outlinedCentered(
	mut r engine.Renderer,
	f engine.Font,
	text str,
	cx f32,
	y f32,
	c Vec4,
	width f32
):
	r.outlined(f, text, cx - f32(f.textWidth(text)) / 2.0, y, c, width)

# where a point of the world lands on a w x h screen (pixels from the top left), none behind
fn onScreen(p Vec3, viewProjection Mat4, w f32, h f32) Vec2?:
	c = viewProjection @ p.withW(1.0)
	if c.w <= 0.01: return none
	Vec2((c.x / c.w * 0.5 + 0.5) * w, (0.5 - c.y / c.w * 0.5) * h)

# ---------- the ride ----------

# where the board is at a moment (its middle: where the trucks meet the rail, or the wheels the
# ground) and its tilt, the session reached (fractional), and how far through the jump (0..1, -1
# not in the air) and since the landing (seconds, -1 before)
type Moment:
	at Vec3
	tilt f32
	session f32
	grinding bool
	air f32
	landed f32

# the ground past the rail's end, every `step` meters along the way he goes (the highest
# surface below the rail's end, so nothing overhead): what he lands on and rolls over
type GroundAhead:
	heights f32[]
	step f32

fn groundAhead(soup rw4.CollisionSoup, end Vec3, along Vec3, length f32, fallback f32):
	step f32 = 0.25
	heights = []
	last = fallback
	for k in 0..=i64(length / step):
		p = end + along * (f32(k) * step)
		last = soup.groundBelow(p.x, p.z, end.y + 0.3) ?? last
		heights.push(last)
	GroundAhead(heights, step)

fn groundAt(g GroundAhead, d f32):
	i = (d / g.step).clamp(0.0, f32(g.heights.len - 1))
	k = i64(i.floor())
	t = i - f32(k)
	g.heights[k] * (1.0 - t) + g.heights[(k + 1).min(len - 1)] * t

fn momentAt(
	seconds f32,
	sessions Session[],
	origin Vec3,
	along Vec3,
	low f32,
	ahead0 GroundAhead,
	truckLow f32,
	wheelLow f32
):
	last = f32(sessions.len - 1)
	# eased in over the first second, then steady to the end of the rail
	speed = last / (grindSeconds - 0.5)
	s = speed * seconds * seconds * 0.5 if seconds < 1.0 else speed * (seconds - 0.5)
	if s < last:
		here = railPoint(sessions, s, origin, along, low)
		ahead = railPoint(sessions, (s + 0.4).min(last), origin, along, low)
		behind = railPoint(sessions, (s - 0.4).max(0.0), origin, along, low)
		tilt = ((ahead.y - behind.y) / (ahead - behind).length().max(0.01)).asin()
		return Moment(
			at = here + Vec3(0.0, -truckLow, 0.0),
			tilt,
			session = s,
			grinding = true,
			air = -1.0,
			landed = -1.0
		)
	# off the end: a pop, falling until the wheels meet the ground under them, then rolling on
	# over it and slowing down
	t = seconds - (last / speed + 0.5)
	end = railPoint(sessions, last, origin, along, low) + Vec3(0.0, -truckLow, 0.0)
	v = speed * spacing   # meters a second along the rail
	pop f32 = 1.6
	height = (u f32): end.y + pop * u - 0.5 * gravity * u * u
	flight = 0.0
	while flight < 3.0 and
		(flight < 0.05 or height(flight) + wheelLow > ahead0.groundAt(v * flight)):
		flight += 1.0 / 480.0
	if t < flight:
		at = end + along * (v * t)
		return Moment(
			at = Vec3(at.x, height(t), at.z),
			tilt = 0.0,
			session = last,
			grinding = false,
			air = t / flight,
			landed = -1.0
		)
	u = t - flight
	slowing f32 = 0.55
	d = v * flight + v * (1.0 - (-slowing * u).exp()) / slowing
	at = end + along * d
	slope = ((ahead0.groundAt(d + 0.4) - ahead0.groundAt(d - 0.4)) / 0.8).atan()
	Moment(
		at = Vec3(at.x, ahead0.groundAt(d) - wheelLow, at.z),
		tilt = slope,
		session = last,
		grinding = false,
		air = -1.0,
		landed = u
	)

# his stance at the moment: low and balancing on the rail, tucked in the air, taking the
# landing in his knees, then standing taller as he rolls away
fn stanceAt(m Moment, seconds f32, deckTop f32, feet f32):
	# slow, uneven sines: a balance kept, not a rhythm
	wobble = (seconds * 0.9).sin() * 0.6 + (seconds * 1.55 + 1.3).sin() * 0.3 +
		(seconds * 2.7 + 0.4).sin() * 0.1
	crouch = 0.17 + 0.012 * (seconds * 0.7 + 0.5).sin()
	sway = 0.035 * wobble
	armLift = 0.06 * wobble
	if m.air >= 0.0:
		crouch = 0.25 - m.air * 0.6 if m.air < 0.2 else 0.13 + 0.12 * ((m.air - 0.2) / 0.8)
		sway = 0.0
		armLift = 0.35
	elif m.landed >= 0.0:
		hit = (-m.landed * 4.0).exp()
		crouch = 0.1 + 0.2 * hit * (m.landed * 9.0).cos().abs()
		sway = 0.03 * wobble * (1.0 - hit)
		armLift = -0.15 + 0.3 * hit
	board = Quat.about(Vec3(0.0, 0.0, 1.0), m.tilt)
	game.Stance(
		crouch,
		shift = Vec3(-0.03 * wobble, 0.0, 0.0),
		lean = 0.22 + 0.02 * (seconds * 0.6).sin(),
		sway,
		twist = 0.35,
		look = 1.05 - 0.05 * wobble,
		board,
		deck = board.rotate(Vec3(0.0, deckTop, 0.0)),
		feet, arms = [
			Vec3(0.85, -0.42 + armLift, 0.32),
			Vec3(0.88, -0.2 + armLift, 0.42),
			Vec3(-0.72, -0.55 - armLift, 0.25),
			Vec3(-0.52, -0.72 - armLift, 0.45)])

district = skate.defaultDistrict
if not skate.isPrepared(district):
	fail("run zap run projects/skate3/prepare.zap first")
sessions = readSessions("projects/skate3/assets/di1f31.csv")
n = sessions.len
if n < 2: fail("fewer than two sessions in projects/skate3/assets/di1f31.csv")
low = sessions.map(.rate).min() ?? 0.0
world = skate.loadWorld(skate.districtDir(district)) ??
	fail("{error}: run zap run projects/skate3/prepare.zap")
if args.hasFlag("--find"):
	world.collision.findStretch(sessions, low)
	return
along = Vec3(railYaw.cos(), 0.0, -railYaw.sin())
railEnd = Vec3(railX, 0.0, railZ) + along * (f32(n - 1) * spacing)
ground = world.collision.groundBelow(railEnd.x, railEnd.z, 10000.0) ??
	fail("no ground at the rail's end: choose another place (--find)")
side = Vec3(0.0, 1.0, 0.0).cross(along).normalized() * -1.0   # the way he faces
origin = Vec3(railX, ground, railZ)
record = args.option("--record") ?? ""
if record != "":
	_ = fs.createDir(record)
ahead0 = groundAhead(
	world.collision,
	railPoint(sessions, f32(n - 1), origin, along, low),
	along,
	40.0,
	ground
)
mut win = engine.openWindow("Skate 3 - DI1F31", 1920, 1080)   # first: the GPU's things need it
# the game's board alone, under the rider
skater = skate.loadSkater(skate.skaterFile) ??
	fail("{error}: run zap run projects/skate3/prepare.zap")
truckLow, _ = skater.heightsOf("SkateTruck")
wheelLow, _ = skater.heightsOf("SkateWheel")
_, deckTop = skater.heightsOf("SkateBoard")
mut boardOnly = skater
boardOnly.meshes = boardOnly.meshes.filter(.slot.startsWith("Skate"))
board = graphics.newSkaterFigure(boardOnly)
mut rider = graphics.newGltfFigure("projects/skate3/assets/suit.glb")
bones = rider.models[0].rig.riderBones()
# the rail and its posts, in the world
white = image.fromBytes(1, 1, [255, 255, 255, 255]).newTexture(graphics.tiled)
mut steel = []
for k in 0..(n - 1) * 4:
	a = railPoint(sessions, f32(k) / 4.0, origin, along, low)
	b = railPoint(sessions, f32(k + 1) / 4.0, origin, along, low)
	pushTube(steel, a, b, 0.03, 10)
for k in 0..n:
	if k % 3 != 0 and k != n - 1: continue
	p = railPoint(sessions, f32(k), origin, along, low)
	below = world.collision.groundBelow(p.x, p.z, p.y) ?? ground
	pushTube(steel, p - Vec3(0.0, 0.03, 0.0), Vec3(p.x, below, p.z), 0.035, 10)
rail = graphics.SkaterFigure(
	program = board.program,
	parts = [partOf(steel, Vec4(0.66, 0.68, 0.72, 1.0), white.texture(), board.program)]
)
mut scene = graphics.newWorldScene(world)   # last: the scene takes the world
mut r = engine.newRenderer()
title = engine.loadFont("Impact", 64)
huge = engine.loadFont("Impact", 92)
mid = engine.loadFont("Impact", 40)
small = engine.loadFont("Segoe UI", 26, 600)
mut frames = engine.newFrames()
total = i64((grindSeconds + afterSeconds) * f32(fps))
first = sessions[0]
final = sessions[n - 1]
mut eyeNow = Vec3(0.0, 0.0, 0.0)
mut lookNow = Vec3(0.0, 0.0, 0.0)
mut frame = 0
while frame < total and win.nextFrame(frames):
	seconds = f32(frame) / f32(fps)
	m = momentAt(seconds, sessions, origin, along, low, ahead0, truckLow, wheelLow)
	st = m.stanceAt(seconds, deckTop, 0.22)
	rider.models[0].rig.clips = [rider.models[0].rig.stanceClip(bones, st)]
	day = i64(m.session.floor()).clamp(0, n - 1)
	gain = (puAt(sessions, m.session) / first.pu - 1.0) * 100.0
	rate = rateAt(sessions, m.session)
	# the camera beside him on the side he faces, a little ahead and above, eased after him
	eyeWant = m.at + side * 4.6 + along * 1.8 + Vec3(0.0, 1.5, 0.0)
	lookWant = m.at + along * 1.0 + Vec3(0.0, 1.0, 0.0)
	share f32 = 1.0 if frame == 0 else math.easeShare(6.0, 1.0 / f32(fps))
	eyeNow += (eyeWant - eyeNow) * share
	lookNow += (lookWant - lookNow) * share
	view = Mat4.lookAlong(eyeNow, (lookNow - eyeNow).normalized())
	w = f32(win.width)
	h = f32(win.height)
	projection = game.projectionOf(w / h.max(1.0))
	r.beginWorld(scene, win.width, win.height)
	r.drawWorld(scene, projection, view, eyeNow)
	r.drawSkater(rail, scene, Mat4(1.0), projection, view, eyeNow)
	turn = Quat.about(Vec3(0.0, 1.0, 0.0), railYaw) @ Quat.about(Vec3(0.0, 0.0, 1.0), m.tilt)
	graphics.drawSkater(
		r, board,
		scene,
		Mat4.transformOf(m.at, turn, Vec3(1.0, 1.0, 1.0)),
		projection,
		view,
		eyeNow
	)
	graphics.drawGltfFigure(
		r, rider,
		scene,
		engine.Pose(clip = 0, time = 0.0),
		m.at,
		railYaw,
		projection,
		view,
		eyeNow
	)
	# the score beside him
	r.beginOverlay(win.width, win.height, engine.Camera())
	r.outlined(title, "ROLLING DOWN THE CURVE", 36.0, 22.0, Vec4(1.0, 0.84, 0.12, 1.0), 4.0)
	outlined(
		r,
		small,
		"DI1F31  |  DI futuro jan/2031",
		40.0,
		96.0,
		Vec4(0.92, 0.94, 1.0, 1.0),
		2.0
	)
	if m.landed < 0.0 and
		onScreen(
			m.at + Vec3(0.0, 2.15, 0.0) + along * 0.4,
			projection @ view,
			w,
			h
		) is anchor:
		x = (anchor.x + 120.0).min(w - 560.0)
		y = (anchor.y - 210.0).max(70.0)
		r.outlined(mid, "RETORNO", x, y, engine.white, 3.0)
		r.outlined(huge, returnText(gain), x, y + 42.0, Vec4(1.0, 0.84, 0.12, 1.0), 4.0)
		outlined(
			r,
			mid,
			dateText(sessions[day].date),
			x,
			y + 140.0,
			Vec4(0.55, 0.85, 1.0, 1.0),
			3.0
		)
		outlined(
			r,
			mid,
			"TAXA {brazilian(f64(rate), 2)}%",
			x,
			y + 186.0,
			Vec4(1.0, 0.55, 0.15, 1.0),
			3.0
		)
		if m.grinding:
			# the balance meter: the needle swings with his sway
			by = y + 240.0
			r.fillRect(x - 3.0, by - 3.0, 266.0, 18.0, Vec4(0.0, 0.0, 0.0, 0.8))
			r.fillRect(x, by, 260.0, 12.0, Vec4(0.85, 0.2, 0.15, 1.0))
			r.fillRect(x + 70.0, by, 120.0, 12.0, Vec4(1.0, 0.8, 0.1, 1.0))
			r.fillRect(x + 105.0, by, 50.0, 12.0, Vec4(0.3, 0.9, 0.35, 1.0))
			needle = x + 130.0 + st.sway / 0.07 * 55.0
			r.fillRect(needle - 3.0, by - 8.0, 6.0, 28.0, engine.white)
	if m.landed >= 0.0:
		fade = (m.landed * 3.0).min(1.0)
		top = h * 0.05
		outlinedCentered(
			r,
			huge,
			"RETORNO {returnText(gain)}",
			w / 2.0,
			top + 30.0,
			Vec4(1.0, 0.84, 0.12, fade),
			5.0
		)
		outlinedCentered(
			r,
			mid,
			"{dateText(first.date)}  >  {dateText(final.date)}",
			w / 2.0,
			top + 185.0,
			Vec4(0.55, 0.85, 1.0, fade),
			3.0
		)
		outlinedCentered(
			r,
			mid,
			"TAXA {brazilian(f64(first.rate), 2)}%  >  {brazilian(f64(final.rate), 2)}%",
			w / 2.0,
			top + 235.0,
			Vec4(1.0, 0.55, 0.15, fade),
			3.0
		)
		outlinedCentered(
			r,
			mid,
			"PU {brazilian(first.pu, 2)}  >  {brazilian(final.pu, 2)}",
			w / 2.0,
			top + 285.0,
			Vec4(1.0, 1.0, 1.0, fade),
			3.0
		)
	if record != "":
		path = "{record}/{frame:05}.png"
		r.screenshot().savePng(path) ?? fail("cannot write {path}")
	else:
		r.showFrame(win, frames)
	frame += 1

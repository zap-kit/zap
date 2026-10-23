# The camera: Ragnarok Online's when the map opens (roBrowser's reading of the client: a narrow
# perspective of 15 degrees from bottom to top, far from its target, looking down 60
# degrees, facing north), freed into a modern third-person orbit about the hero. Holding the
# right button holds the mouse still (hidden, its own motion read, so a drag never meets the
# screen's edge; let go, the cursor is where the drag began) and turns the camera as the client
# does (720 degrees across the window; a drag to the right turns it to look further east) and
# tilts it (a drag up lowers it toward the horizon, down raises it until it looks straight down);
# a double right click puts it back as it opened; the wheel zooms, smoothly, from close behind
# the hero (the view widening as it nears, a dolly zoom) to far above the map. The mouse sets
# goals at once; the camera eases toward them, and toward the hero, by rates per second whatever
# the frame rate; it never goes under the ground.

import engine
import world
import math
import ragnarok.gat

pub type Camera:
	target Vec3
	yaw f32   # degrees, 0 looking north, 90 looking east
	pitch f32   # degrees below the horizon
	distance f32   # how far the zoom puts it
	reach f32   # how far it is: the distance, or less where something is in the way
	lift f32   # how far the eye is raised to clear the ground under it
	goalYaw f32
	goalPitch f32
	goalDistance f32
	home f32   # the opening distance, where a double right click puts it back
	dragging bool   # the right button held: turning and tilting
	anchorX i64   # where the drag began (window pixels)
	anchorY i64
	lastPress f64   # when the right button last went down (seconds)

roFov f32 = 15.0
closeFov f32 = 50.0
# the view keeps the client's 15 degrees down to wideFrom cells away, widens to 50 at minDistance
wideFrom f32 = 60.0
minDistance f32 = 10.0
maxDistance f32 = 400.0
# a sprite's texels per cell: the opening zoom puts one on a pixel of the screen, as the client
# draws its sprites (about 104 cells away on a 960-line window, near the client's 95)
spriteTexelsPerCell f32 = 35.0
notchZoom f32 = 0.9
startPitch f32 = 60.0
minPitch f32 = 3.0
maxPitch f32 = 89.0
# degrees of turn a pixel of drag across the window (the client's 720 a window's width), and of
# tilt (a little slower)
turnPerWidth f32 = 720.0
tiltShare f32 = 0.6
# how fast the camera closes on its goals and on the hero (the part left after t seconds is
# e^(-rate t)): the turn and the tilt nearly at once, the zoom softly, the hero at the client's pace
turnRate f32 = 25.0
zoomRate f32 = 12.0
followRate f32 = 6.0
# pulled in fast when the ground comes between it and the hero (a hill), let out slowly
pullRate f32 = 20.0
releaseRate f32 = 3.0
# how far above the ground under it the eye stays (cells)
clearance f32 = 1.0
# the nearest the eye comes when the ground is in the way (cells)
nearest f32 = 3.0
# under this pitch (degrees) the camera looks higher than the feet, up to a figure's middle
highFrom f32 = 45.0
figureMiddle f32 = 1.5
toRad f32 = pi / 180.0

# the distance at which a sprite's texel covers one pixel of a screen `screenHeight` pixels high
fn homeDistance(screenHeight i64):
	f32(screenHeight.max(1)) * 0.5 / (roFov * 0.5 * toRad).tan() / spriteTexelsPerCell

pub fn newCamera(target Vec3, screenHeight i64) Camera:
	home = homeDistance(screenHeight)
	Camera(
		target,
		yaw = 0.0,
		pitch = startPitch,
		distance = home,
		reach = home,
		lift = 0.0,
		goalYaw = 0.0,
		goalPitch = startPitch,
		goalDistance = home, home, dragging = false, anchorX = 0, anchorY = 0, lastPress = -1.0)

# the camera turned `yaw` degrees, `distance` cells away, looking down `pitch` degrees, at once
pub fn setCamera(mut c Camera, yaw f32, distance f32, pitch f32):
	c.yaw = yaw
	c.goalYaw = yaw
	c.distance = distance.clamp(minDistance, maxDistance)
	c.goalDistance = c.distance
	c.reach = c.distance
	c.pitch = pitch.clamp(minPitch, maxPitch)
	c.goalPitch = c.pitch

# the wheel and the right drag of this frame's input
pub fn steerCamera(mut c Camera, win engine.Window, i Input):
	if i.wheel != 0.0:
		# each notch a tenth nearer or farther: as fine close up as far away
		c.goalDistance = (c.goalDistance * notchZoom.pow(i.wheel)).clamp(minDistance, maxDistance)
	if i.rightPressed:
		now = clockSeconds()
		if now - c.lastPress < 0.35:
			c.goalYaw = (c.yaw / 360.0).round() * 360.0
			c.goalPitch = startPitch
			c.goalDistance = c.home
		c.lastPress = now
		c.dragging = true
		c.anchorX = i.x
		c.anchorY = i.y
		if not i.scripted:
			win.lockMouse(true)
	if c.dragging and i.right:
		perPixel = turnPerWidth / f32(win.width.max(1))
		c.goalYaw += i.moveX * perPixel
		c.goalPitch = (c.goalPitch + i.moveY * perPixel * tiltShare).clamp(minPitch, maxPitch)
	if c.dragging and not i.right:
		c.dragging = false
		if not i.scripted:
			win.lockMouse(false)

# the camera moved toward its goals and its target over `dt` seconds, its eye kept out of the
# ground (and, looking from low, out of the models)
pub fn follow(mut c Camera, z world.Zone, target Vec3, dt f32):
	c.target += (target - c.target) * math.easeShare(followRate, dt)
	turn = math.easeShare(turnRate, dt)
	c.yaw += (c.goalYaw - c.yaw) * turn
	c.pitch += (c.goalPitch - c.pitch) * turn
	# the zoom eased by its ratio, so it moves as evenly close up as far away
	c.distance *= (c.goalDistance / c.distance).pow(math.easeShare(zoomRate, dt))
	clear = c.clearReach(z)
	c.reach += (clear - c.reach) *
		math.easeShare(pullRate if clear < c.reach else releaseRate, dt)
	# and raised where it would graze the ground
	c.lift = 0.0
	eye = c.eyeOf()
	c.lift = (z.gat.groundAt(eye) + clearance - eye.y).max(0.0)

# the ground's height (world y) under the point p (0 off the map)
fn groundAt(gat gat.Gat, p Vec3):
	cx = i64(p.x.floor())
	cy = i64((-p.z).floor())
	-gat.heightAt(cx, cy, p.x - f32(cx), -p.z - f32(cy)) * 0.2

# how far from the focus the eye can be along its way out before the way passes under the
# ground: found in steps of a quarter cell, then narrowed down, so it changes smoothly as the
# camera turns. The models do not push it (as in the client): a lamp, a fence or a bridge the hero
# passes would make it jump; from inside a house its walls, seen from behind, are not drawn.
fn clearReach(c Camera, z world.Zone):
	yaw = c.yaw * toRad
	pitch = c.pitch * toRad
	way = Vec3(-yaw.sin() * pitch.cos(), pitch.sin(), yaw.cos() * pitch.cos())
	start = c.focusOf()
	blocked = (s f32):
		p = start + way * s
		p.y < z.gat.groundAt(p)
	s = 0.5
	while s < c.distance:
		if blocked(s):
			lo = s - 0.25
			hi = s
			loop 6:
				mid = (lo + hi) * 0.5
				if blocked(mid):
					hi = mid
				else:
					lo = mid
			return (lo - 1.0).clamp(nearest, c.distance)
		s += 0.25
	c.distance

# how wide the view is from bottom to top (degrees): the client's 15, widening close up
pub fn fovOf(c Camera) f32:
	t = ((wideFrom - c.distance) / (wideFrom - minDistance)).clamp(0.0, 1.0)
	roFov + (closeFov - roFov) * t * t

# the point the camera looks at: the hero's feet, as the client looks, from high; from low, up
# to the middle of a figure, so the hero stays in view and the way to the eye clears the ground
pub fn focusOf(c Camera) Vec3:
	t = ((highFrom - c.pitch) / (highFrom - minPitch)).clamp(0.0, 1.0)
	c.target + Vec3(0.0, figureMiddle * t, 0.0)

# where the camera is
pub fn eyeOf(c Camera) Vec3:
	yaw = c.yaw * toRad
	pitch = c.pitch * toRad
	c.focusOf() +
		Vec3(-yaw.sin() * pitch.cos(), pitch.sin(), yaw.cos() * pitch.cos()) * c.reach +
		Vec3(0.0, c.lift, 0.0)

pub fn viewOf(c Camera) Mat4:
	eye = c.eyeOf()
	Mat4.lookAlong(eye, c.focusOf() - eye)

# the perspective, deep enough to see across the whole map from any height
pub fn projection(c Camera, aspect f32) Mat4:
	Mat4.perspective(c.fovOf() * toRad, aspect, 1.0, 2500.0)

# the eighths of a turn to add to a figure's facing for the way the camera sees it, as the
# client counts them (turned 90 degrees to look east, a figure facing south shows its east side)
pub fn facingSteps(c Camera) i64:
	(i64(((-c.yaw + 22.5) / 45.0).floor()) % 8 + 8) % 8

# The cell of the ground under the screen point (sx, sy) of a w x h window, where the ray from
# the eye through it first passes under the ground; none when it leaves the map without meeting it.
pub fn pickCell(gat gat.Gat, c Camera, sx i64, sy i64, w i64, h i64) Cell?:
	eye = c.eyeOf()
	way = engine.rayThrough(
		c.focusOf() - eye,
		c.fovOf() * toRad,
		f32(sx) + 0.5,
		f32(sy) + 0.5,
		f32(w),
		f32(h)
	)
	q = eye.groundHit(way, (x f32, z f32): gat.groundAt(Vec3(x, 0.0, z))) ??
		return none
	cx = i64(q.x.floor())
	cy = i64((-q.z).floor())
	if gat.inside(cx, cy): return Cell(cx, cy)
	none

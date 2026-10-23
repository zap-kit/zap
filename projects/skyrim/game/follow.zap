# The third-person camera: an orbit (the engine's) about a point over the player's shoulder, at
# the height of the skeleton's Camera3rd node, turned by the mouse, kept off the walls: a ball
# about the eye swept from the head to that point, then on toward where the eye would be, stops
# where it meets the scene, so the camera never looks through a wall.

import engine
import math
import engine.physics
import skyrim

eyeHeight f32 = 121.0   # the skeleton's Camera3rd node over the feet
shoulder f32 = 25.0   # the point it circles to the right of the head
distanceDefault f32 = 150.0   # Skyrim's third-person distance
clearance f32 = 10.0   # how near a wall the eye comes: past the near plane's corners
lookSpeed f32 = 0.004   # radians a pixel of mouse motion
headRoom f32 = 30.0   # an eye pulled nearer than this by a wall behind is in the head
lowest f32 = -1.2   # how far it looks up and down (radians below the horizon)
highest f32 = 1.3

pub type Follow:
	orbit engine.Orbit   # y up; its yaw is the heading the camera looks along
	reach f32 = distanceDefault

# a camera behind the player's back, facing `heading`
pub fn newFollow(heading f32) Follow:
	Follow(orbit = engine.Orbit(target = Vec3(0, 0, 0), yaw = heading, pitch = 0.25,
		distance = distanceDefault, minPitch = lowest, maxPitch = highest))

# the way the camera looks: radians from north toward east (the orbit's yaw)
pub fn headingOf(f Follow) f32:
	f.orbit.yaw

# the mouse's motion turns it (right looks right, down looks down)
pub fn turnFollow(mut f Follow, look IVec2):
	f.orbit.yaw += f32(look.x) * lookSpeed
	f.orbit.pitch = (f.orbit.pitch + f32(look.y) * lookSpeed).clamp(lowest, highest)

# The camera placed over the feet (Skyrim's units, Z up), drawn in as far as the scene asks.
pub fn followFeet(mut f Follow, feet Vec3, mut s physics.Scene):
	head = feet + Vec3(0, 0, eyeHeight)
	side = Vec3(f.orbit.yaw.cos(), -f.orbit.yaw.sin(), 0) * shoulder
	pivot = head + side * s.sweepShare(head, head + side, clearance)
	f.orbit.target = yUp.applyPoint(pivot)
	f.orbit.distance = f.reach
	far = yUp.inverseAffine().applyPoint(f.orbit.eye())
	f.orbit.distance = f.reach * s.sweepShare(pivot, far, clearance)

# Where the crosshair's pick starts and the way it goes (the game's units, Z up): from the point
# the camera circles over the player's shoulder along the view, so its reach counts from the player
# as the game's does in the third person view.
pub fn pickRay(f Follow) (Vec3, Vec3):
	from = yUp.inverseAffine()
	pivot = from.applyPoint(f.orbit.target)
	(pivot, (pivot - from.applyPoint(f.orbit.eye())).normalized())

pub fn eyeOf(f Follow) Vec3:
	f.orbit.eye()

pub fn viewOf(f Follow) Mat4:
	f.orbit.view()

# whether a wall behind has brought the eye into the player's head (who is not drawn then, as
# the game hides him)
pub fn isInside(f Follow) bool:
	f.orbit.distance < headRoom

# The third person view in dialogue: the camera turns toward the speaker's head (Z up) when he stands
# further aside of where it looks than fDialogueSoftStopAngle3P, easing over fDialogueRotationSecs
# until he is that near; nearer, it stays. No zoom: the game's capture of Orgnar greeting a player
# who looked at him shows the view the same to the pixel as before he spoke.
pub fn frameSpeaker(mut f Follow, head Vec3, settings skyrim.IniSettings, dt f32):
	eye = yUp.inverseAffine().applyPoint(f.orbit.eye())
	to = head - eye
	off = math.angleBetween(f.orbit.yaw, to.x.atan2(to.y))
	soft = f32(settings.iniNumber("fDialogueSoftStopAngle3P:Controls")).radians()
	if off.abs() <= soft: return
	seconds = f32(settings.iniNumber("fDialogueRotationSecs:Dialogue")).max(0.01)
	f.orbit.yaw += (off - soft * off.sign()) * (dt / seconds).min(1.0)

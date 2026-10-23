# An actor's head tracking the player who comes near, as the game turns heads: the neck and the
# head turned (in the pose, engine.Pose's turn) toward the player's eyes, no further than a head
# turns, at the speed the plugin's settings give (fHeadTrackSpeedMin degrees a second for a turn
# within fHeadTrackSpeedMinAngle, up to fHeadTrackSpeedMax from fHeadTrackSpeedMaxAngle), and
# back to ahead when the player goes away or is behind.

import math
import world

# how near the player comes before a head turns to him: the executable's distance is not read
# yet (the plugin sets none); this stands in for it
lookDistance f32 = 300.0
headHeight f32 = 120.0   # the head over the feet of an actor of the skeleton's height
playerEye f32 = 121.0   # the player's eyes over his feet (follow.zap's Camera3rd)
mostYaw f32 = 70.0   # how far a head turns aside and up or down, degrees
mostPitch f32 = 30.0
behind f32 = 110.0   # a player further aside than this (degrees) is not looked at

fn dot(a Quat, b Quat):
	a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w

# the turn (in the model's space: y up, facing -z) of a head looking from `eye` at `at`, an actor
# facing `heading`; ahead when the player is far or behind
fn lookTurn(eye Vec3, at Vec3, heading f32):
	to = at - eye
	flat = Vec2(to.x, to.y).length()
	ahead = Quat(0.0, 0.0, 0.0, 1.0)
	if to.length() > lookDistance or flat < 1.0: return ahead
	yaw = math.angleBetween(heading, to.x.atan2(to.y)).degrees()
	if yaw.abs() > behind: return ahead
	pitch = to.z.atan2(flat).degrees().clamp(-mostPitch, mostPitch)
	yaw = yaw.clamp(-mostYaw, mostYaw)
	Quat.about(Vec3(0.0, 1.0, 0.0), -yaw.radians()) @
		Quat.about(Vec3(1.0, 0.0, 0.0), pitch.radians())

# where the actor's eyes are (Z up)
pub fn headOf(rs Residents, cast world.CastHead, k i64) Vec3:
	r = rs.all[k]
	r.body.feetOf() + Vec3(0.0, 0.0, headHeight * cast.npcs[r.npc].look.scale)

# The actor's head eased toward the player standing at `player` (feet, Z up) over dt.
fn lookToward(rs Residents, cast world.CastHead, k i64, player Vec3, dt f32):
	r = rs.all[k]
	eye = rs.headOf(cast, k)
	turning = r.doing == .Entering or r.doing == .Leaving
	goal = Quat(0.0, 0.0, 0.0, 1.0) if turning
		else eye.lookTurn(player + Vec3(0.0, 0.0, playerEye), r.body.heading)
	angle = (2.0 * dot(r.look, goal).abs().min(1.0).acos()).degrees()
	if angle < 0.01: return goal
	a = cast.ai
	span = (a.trackSpeedMaxAngle - a.trackSpeedMinAngle).max(0.01)
	share = ((angle - a.trackSpeedMinAngle) / span).clamp(0.0, 1.0)
	speed = a.trackSpeedMin.lerp(a.trackSpeedMax, share)
	r.look.nlerp(goal, (speed * dt / angle).min(1.0))

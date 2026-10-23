# The HUD, interface/hudmenu.swf, run as the game runs it: its ActionScript plays it, the game
# calls _root.InitExtensions() and _root.SetPlatform(platform, false) once it is loaded, then each
# frame sets the meters and the compass through HUDMovieBaseInstance's methods (the names and
# arguments its bytecode defines: SetHealthMeterPercent(percent, force),
# SetCompassAngle(playerAngle, compassAngle, show)...), the compass's angle the yaw from the cell's
# north marker (the inn's turned 235.4 degrees: its captures show N 105 pixels left of the middle
# at yaw 270, E 112 right of it at 288.1, 3 pixels a degree). Shared.GlobalFunc's Lock puts the corner
# locks at Stage.visibleRect inset by Stage.safeRect; the game stretches the HUD to the window
# (interface.zap), so the visible rectangle is the stage's at any size.

import engine.swf.avm1
import skyrim

base = "HUDMovieBaseInstance"
# the key controlmap.txt gives the Activate event on the PC's keyboard (0x12), whose button the
# game gives the HUD for the activate prompt (RefreshActivateButtonArt)
activateKey = "E"

# what the HUD shows of the game
pub type HudState:
	health f64 = 100.0   # percent
	magicka f64 = 100.0
	stamina f64 = 100.0
	heading f64 = 0.0   # the camera's yaw, degrees from north toward east
	enemy f64 = -1.0   # percent of the foe's health the enemy meter shows, below 0 hides it
	north f64 = 0.0   # the cell's north marker's heading: the compass reads the yaw from it
	compass bool = true   # bShowCompass

# what the crosshair is on, as the game gives it to SetCrosshairTarget
pub type HudTarget:
	text str   # what activating does over what it is, a line each
	weight f64 = -1.0   # an item's weight and value, -1 for none
	value f64 = -1.0

# the HUD loaded in a window of width x height pixels, as the game sets it up (PC platform)
pub fn openHud(install skyrim.Install, width i64, height i64) avm1.Player ? str:
	p = try install.openPlayer("interface/hudmenu.swf", width, height)
	p.invokeText("InitExtensions()")
	p.invokeText("SetPlatform(0, false)")
	p.invoke("{base}.RefreshActivateButtonArt", [.Str(activateKey)])
	p

# the game's state given to the HUD, as the game does each frame
pub fn updateHud(mut p avm1.Player, state HudState):
	for (name, v) in [("Health", state.health), ("Magicka", state.magicka),
		("Stamina", state.stamina)]:
		p.invoke("{base}.Set{name}MeterPercent", [.Num(v), .Bool(false)])
	p.invoke("{base}.SetCompassAngle", [.Num(degrees(state.heading)),
		.Num(degrees(state.heading - state.north)), .Bool(state.compass)])
	shown = state.enemy >= 0.0
	p.write("{base}.EnemyHealth_mc._alpha", .Num(100.0 if shown else 0.0))
	if shown:
		for name in ["SetEnemyHealthPercent", "SetEnemyHealthTargetPercent"]:
			p.callBack("call", [.Str(name), .Num(state.enemy)])

# The meters that became full since `before` (all of them on the first frame) faded out, as the
# game hides a full meter (the start capture shows none at full health, magicka and stamina).
pub fn fadeFullMeters(mut p avm1.Player, state HudState, before HudState?):
	for (meter, now, was) in [("Health", state.health, before?.health ?? 0.0),
		("Magica", state.magicka, before?.magicka ?? 0.0)]:
		if now >= 100.0 and was < 100.0:
			p.invoke("{base}.FadeOutMeter", [p.read("{base}.{meter}")])
	if state.stamina >= 100.0 and (before?.stamina ?? 0.0) < 100.0:
		p.invoke("{base}.FadeOutStamina", [.Num(state.stamina)])

# the HUD's opacity (fHUDOpacity, 0..1) set over the whole HUD
# A notice at the HUD's top left, as SendHUDMessage::ShowHUDMessage (0x140991a30) shows the
# game's own and Debug.Notification's: GameDelegate's ShowMessage with the text.
pub fn showNotice(mut p avm1.Player, text str):
	p.delegate("ShowMessage", [.Str(text.copy())])

pub fn setOpacity(mut p avm1.Player, opacity f64):
	p.write("{base}._alpha", .Num(opacity.clamp(0.0, 1.0) * 100.0))

# an angle in degrees in 0..360
fn degrees(a f64):
	d = a.rem(360.0)
	d + 360.0 if d < 0.0 else d

# The crosshair's target given to the HUD (none: the crosshair on nothing), as the game gives it
# when it changes: SetCrosshairTarget(abActivate, aName, abShowButton, abTextOnly, abFavorMode,
# abShowCrosshair, aWeight, aCost, aFieldValue, aFieldText), the activate key's button shown, the
# crosshair when `crosshair` (bShowCrosshair).
pub fn showTarget(mut p avm1.Player, target HudTarget?, crosshair bool):
	t = target ?? HudTarget(text = "")
	shown = target != none
	number = (x f64): avm1.Value.Num(x) if x >= 0.0 else avm1.Value.Undefined
	p.invoke("{base}.SetCrosshairTarget", [.Bool(shown), .Str(t.text.copy()), .Bool(shown),
		.Bool(false), .Bool(false), .Bool(crosshair), number(t.weight), number(t.value), .Undefined,
		.Undefined])

# The stealth meter's eye: the value it shows (0 hidden to 100 detected) eased toward the one the
# game gives, whether it is up, and the value its caption last settled on
pub type StealthEye:
	shown i64 = 0
	target i64 = 0
	visible bool = false
	settled i64 = -1

stealthMeter = "{base}.StealthMeterInstance"

# The stealth meter for a frame, as StealthMeter::ProcessMessage (0x14093a700) and Update
# (0x14093a7e0) run it: the player's sneaking brings the eye up (the meter's FadeIn, at the value
# the game gives) and ends it (FadeOut); the shown value closes 30 percent of the way to the
# game's each frame (to 0 when under 1 away) and sets the eye's frame to its 1.01 times; when it
# arrives at 0 the caption reads $HIDDEN, at 100 $DETECTED, started from its first frame.
pub fn updateStealth(mut p avm1.Player, mut eye StealthEye, value i64, visible bool):
	if visible != eye.visible:
		p.invoke("{stealthMeter}.gotoAndPlay", [.Str("FadeIn" if visible else "FadeOut")])
		p.invoke("{base}.ShowElements", [.Str("StealthMode"), .Bool(visible)])
		eye.visible = visible
		if visible: eye.shown = value
	eye.target = value
	if not eye.visible: return
	if eye.shown != eye.target:
		step = (eye.shown - eye.target) * 0.3
		eye.shown = eye.shown - i64(step) if step.abs() >= 1.0 else eye.target
	if eye.shown == eye.target and eye.settled != eye.target and eye.target in [0, 100]:
		eye.settled = eye.target
		caption = "$HIDDEN" if eye.target == 0 else "$DETECTED"
		p.write(
			"{stealthMeter}.SneakTextHolder.SneakTextClip.SneakTextInstance.text",
			.Str(caption)
		)
		p.invoke("{stealthMeter}.SneakTextHolder.gotoAndPlay", [.Str("Start")])
	elif eye.shown != eye.target:
		eye.settled = -1
	frame = i64(eye.shown * 1.01)
	p.invoke("{stealthMeter}.SneakAnimInstance.gotoAndStop", [.Num(f64(frame))])

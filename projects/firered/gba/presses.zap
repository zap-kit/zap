# Keys pressed by a script instead of a player (a run that needs no one at the screen):
# `--press "2500:start;2700:a;2800:down,a"`, each button of a step held for pressFrames frames
# from that frame on. The buttons, in KEYINPUT's order.

buttonNames = ["a", "b", "select", "start", "right", "left", "up", "down", "r", "l"]
pressFrames = 4

type Press:
	frame i64
	buttons u32

presses = pressesOf(args.option("--press") ?? "")

fn pressesOf(script str):
	out = []
	for step in script.split(";"):
		colon = step.indexOf(":") ?? continue
		frame = i64.parse(step[..colon].trimmed()) ?? fail("--press: no frame in '{step}'")
		buttons = 0
		for name in step[colon + 1..].split(","):
			k = buttonNames.indexOf(name.trimmed()) ?? fail("--press: no button '{name}'")
			buttons |= u32(1) << u32(k)
		out.push(Press(frame, buttons))
	out

# whether a script presses the keys
fn isScripted():
	not presses.isEmpty

# the keys the script holds at the frame, as KEYINPUT reads them
fn scriptedKeys(frame i64):
	up u32 = 0x3FF
	for p in presses:
		if frame >= p.frame and frame < p.frame + pressFrames: up &= ~p.buttons
	up

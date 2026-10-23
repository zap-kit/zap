# The oracle: the DOS game itself, run in BizHawk's DOSBox-X core (winget install
# TASEmulators.BizHawk) on a hidden desktop, so nothing shows or meets the user's mouse and keys;
# oracle.lua drives it from inside: the keys that reach a level, the clicks at the game's own
# iterations, a picture kept per iteration. The game boots from a floppy image of the player's
# install; the emulator's config fixes the machine (a 486 at 20000 cycles) and binds no host input.

import fs
import win

# a click of the DOS game's cursor at its (x, y) (8..328, 8..200), held through `held` iterations
pub type Click:
	iteration i64
	x i64
	y i64
	held i64 = 1
	button bool = true   # false: the cursor only moves there

pub type OracleRun:
	install str
	out str   # an absolute path: the dir of the pictures (dos-NNNNN.png, 640 x 400) and log.txt
	keys str[]   # boot keys, "FRAME NAME": the machine type, the menu, a level code
	levelFrame i64   # the emulator frame the level's preview is left on
	clicks Click[]
	iterations i64
	shots i64[] = []   # emulator frames whose screen is kept (screen-NNNNN.png)
	dumps i64[] = []   # iterations whose memory is kept (mem-N.bin)
	lastFrame i64 = 1_000_000_000   # the run ends there whatever the iterations

fn bizhawkDir():
	"{env.get("LOCALAPPDATA") ?? ""}/Microsoft/WinGet/Packages/TASEmulators.BizHawk_Microsoft.Winget.Source_8wekyb3d8bbwe"

# the frames that take the game to a level: Enter on the machine type, then F1 on the menu for
# the first level, or F2 and the level's access code (the player's, given on the command line),
# then F1 on the menu the code leaves, then Enter on the preview
pub fn levelKeys(code str) str[]:
	if code.isEmpty: return ["300 Key Enter", "700 Key F1", "1100 Key Enter"]
	keys = ["300 Key Enter", "700 Key F2"]
	for i, c in code.upper().chars():
		keys.push("{800 + i * 20} Key {c}")
	keys.push("1100 Key Enter")
	keys.push("1300 Key F1")
	keys.push("{codeLevelFrame} Key Enter")
	keys

# the frame the level's preview is left on
pub fn levelFrame(code str) i64:
	1100 if code.isEmpty else codeLevelFrame

codeLevelFrame = 1700

# long: the emulator's settings, one per line as BizHawk reads them
fn emulatorConfig():
	r"""
		{
		  "LastWrittenFrom": "2.11",
		  "SkipSuperuserPrivsCheck": true,
		  "FirstBoot": false,
		  "UpdateAutoCheckEnabled": false,
		  "SoundEnabled": false,
		  "RunInBackground": true,
		  "AcceptBackgroundInput": false,
		  "DispMethod": 1,
		  "CoreSyncSettings": {
		    "BizHawk.Emulation.Cores.Computers.DOS.DOSBox": {
		      "$type": "BizHawk.Emulation.Cores.Computers.DOS.DOSBox+SyncSettings, BizHawk.Emulation.Cores",
		      "ConfigurationPreset": 6, "EnableJoystick1": false, "EnableJoystick2": false,
		      "EnableMouse": true, "MouseSensitivity": 1.0, "FormattedHardDisk": 0,
		      "forceFPSNumerator": 0, "forceFPSDenominator": 0, "CPUCycles": 20000, "CPUType": 0,
		      "VideoCardType": 0, "RAMSize": -1, "PCSpeaker": -1, "SoundBlasterModel": 0,
		      "SoundBlasterIRQ": -1
		    }
		  },
		  "AllTrollersAnalog": {
		    "DOSBox Controller": {
		      "Mouse Position X": { "Value": "", "Mult": 1.0, "Deadzone": 0.0 },
		      "Mouse Position Y": { "Value": "", "Mult": 1.0, "Deadzone": 0.0 },
		      "Mouse Speed X": { "Value": "", "Mult": 1.0, "Deadzone": 0.0 },
		      "Mouse Speed Y": { "Value": "", "Mult": 1.0, "Deadzone": 0.0 }
		    }
		  },
		  "AllTrollers": { "DOSBox Controller": { "Mouse Left Button": "", "Mouse Right Button": "" } }
		}
		"""

fn routeText(run OracleRun):
	lines = ["out {run.out}", "level {run.levelFrame}", "iterations {run.iterations}"]
	for k in run.keys:
		lines.push("key {k}")
	lines.push("end {run.lastFrame}")
	for f in run.shots:
		lines.push("shot {f}")
	for d in run.dumps:
		lines.push("dump {d}")
	for c in run.clicks:
		lines.push("{"click" if c.button else "hover"} {c.iteration} {c.x} {c.y} {c.held}")
	"{lines.join("\n")}\n"

# the game played as the run says; the dir of its pictures
pub fn playDos(run OracleRun) str:
	dir = fs.dirOf(run.out)
	image = "{dir}/lemmings.img"
	if not fs.exists(image):
		fs.createDir(dir) ?? fail("cannot make {dir}: {error}")
		fs.writeBytes(image, imageOf(run.install)) ?? fail("cannot write {image}: {error}")
	_ = fs.deleteTree(run.out)
	fs.createDir(run.out) ?? fail("cannot make {run.out}: {error}")
	fs.writeFile("{dir}/lemmings.conf", "[autoexec]\na:\nlemvga /v\n") ?? fail("{error}")
	fs.writeFile(
		"{dir}/lemmings.xml",
		"""
			<BizHawk-XMLGame System="DOS" Name="Lemmings">
			  <LoadAssets>
			    <Asset FileName="lemmings.img" />
			    <Asset FileName="lemmings.conf" />
			  </LoadAssets>
			</BizHawk-XMLGame>
			"""
	) ?? fail("{error}")
	# BizHawk writes its settings back when it ends: a fresh copy each run
	fs.writeFile("{dir}/bizhawk.ini", emulatorConfig()) ?? fail("{error}")
	fs.writeFile("{run.out}/route.txt", run.routeText()) ?? fail("{error}")
	env.set("ZAP_ORACLE_ROUTE", "{run.out}/route.txt")
	lua = fs.join(currentDir(), "projects/lemmings/tools/oracle.lua")
	exe = "{bizhawkDir()}/EmuHawk.exe"
	if not fs.exists(exe): fail("no BizHawk at {exe}: winget install TASEmulators.BizHawk")
	cmd = "\"{exe}\" --config={dir}/bizhawk.ini --lua={lua} {dir}/lemmings.xml"
	# an emulated minute takes some ten seconds; a script that fails leaves BizHawk waiting
	code = win.runHidden(cmd, "zap-lemmings-oracle", 600_000) ??
		fail("cannot run BizHawk: {error.code}")
	if not fs.exists("{run.out}/log.txt"):
		fail("the oracle's script did not start (BizHawk ended with {code})")
	run.out.copy()

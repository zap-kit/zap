# The terminals a session can run: Windows Terminal's profiles, read from its settings so a
# profile added there shows up here, each resolved to the command line that starts it.

import fs
import json

pub type Profile:
	name str
	command str
	dir str   # where it starts; "" for the dir the client picks

settingsPath = "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"

# the profiles of Windows Terminal that start here; PowerShell alone when its settings are missing
pub fn loadProfiles() Profile[]:
	path = fs.join(env.get("LOCALAPPDATA") ?? "", settingsPath)
	text = fs.readFile(path) ?? return fallbackProfiles()
	doc = json.parse(text) ?? return fallbackProfiles()
	list = doc.get(doc.root, "profiles") ?? return fallbackProfiles()
	entries = doc.get(list, "list") ?? return fallbackProfiles()
	found = []
	for k in 0..doc.count(entries):
		p = doc.at(entries, k)
		if (doc.number(p, "hidden") ?? 0.0) == 1.0: continue
		command = commandOf(doc.textOf(p, "commandline"), doc.textOf(p, "source"))
		if command == "": continue
		found.push(
			Profile(
				name = doc.textOf(p, "name"),
				command,
				dir = expand(doc.textOf(p, "startingDirectory"))
			)
		)
	found if not found.isEmpty else fallbackProfiles()

fn fallbackProfiles():
	[Profile(name = "Windows PowerShell", command = "powershell.exe", dir = "")]

# the command line of a profile: its own, or the one of the program that generated it; "" for the
# ones that do not start a program here (Azure's shell, the Visual Studio prompts, an absent WSL)
fn commandOf(commandLine str, source str):
	if commandLine != "": return expand(commandLine)
	match source:
		"Windows.Terminal.PowershellCore": installed("C:/Program Files/PowerShell/7/pwsh.exe", "")
		"Git": installed("C:/Program Files/Git/bin/bash.exe", " -i -l")
		_: ""

# the program quoted with its arguments when it is installed, else ""
fn installed(program str, arguments str):
	"\"{program}\"{arguments}" if fs.exists(program) else ""

# %NAME% replaced by the environment variable's value
fn expand(text str):
	parts = text.split("%")
	out = ""
	for i, part in parts:
		out = "{out}{(env.get(part) ?? "%{part}%") if i % 2 == 1 and i < parts.len - 1 else part}"
	out

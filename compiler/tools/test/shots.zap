# zap test's shots (spec 13.1): each entry file's scripted runs, the `zap run ... --shot
# x.png` lines of its header, run from its repository's root on each backend (gpu in ZAP_RUN, both
# when it is not set) by this zap, each picture compared with the run before. The pictures stay
# on the machine, under the repository's build/shots/<entry>/: <shot>.<backend>.png the last
# run's, .kept.png the one the next run is compared with, .diff.png where a failed one differs.

import fs
import image

# a channel that differs by this much or less is the same (filtering, dithering)
shotTolerance = 8
# a picture is the same when at most one pixel in this many differs
shotPixelsPerDifference = 1000

# the scripted runs of a file's header that save a picture, each up to its comment (two spaces
# or a parenthesis)
fn shotCommands(text str):
	out = []
	for line in headerLines(text):
		command = line.copy()
		for stop in ["  ", " ("]:
			if command.indexOf(stop) is at:
				command = command[..at].copy()
		if command.startsWith("zap run ") and " --shot " in command:
			out.push(command)
	out

fn gpuWord():
	RunWord(
		"gpu",
		"vulkan or d3d12: the engine's backend, and the one zap test --only shots runs on (else both)"
	)

# Every scripted run of the entry files under the paths, on each backend: whether each ran and
# drew what it drew before. With --update, a picture that differs is kept as the new one.
fn shotsCheck(request TestRequest):
	gpus = ["vulkan", "d3d12"]
	if gpuWord().value() is gpu:
		gpus = [gpu]
	passed = true
	count = 0
	for file in measuredFiles("shots", request):
		root = repositoryOf(fullPath(file))
		if root == "":
			print("shots: {file} is not in a repository (a dir holding .git)")
			passed = false
			continue
		text = fs.readFile(file) ?? ""
		if skippedForNeeds(file, text): continue
		for command in shotCommands(text):
			for gpu in gpus:
				count += 1
				passed = shot(root, command, gpu, request.update) and passed
	print("shots: {count} pictures")
	passed

# One scripted run (`zap run <entry> ... --shot x.png`) on a backend: whether it ran and every
# picture it saved is the one kept. The run saves into <root>/build/shots/<entry>/run/, a picture
# named after the shot (`x.<backend>.png`, or `x.<backend>-<more>.png` from a run that saves one
# a scene: lab's tour), each kept as a picture of its own.
fn shot(root str, command str, gpu str, update bool):
	words = command.split(" ").filter(it != "").map(.copy())
	at = (words.indexOf("--shot") ?? 0) + 1
	if words.len < 3 or at >= words.len:
		print("  {command}: --shot names no picture")
		return false
	dir = "{root}/build/shots/{words[2].replace("/", "-").replace(".zap", "")}"
	runDir = "{dir}/run"
	_ = fs.createDir(runDir)
	prefix = "{fs.stem(words[at])}.{gpu}"
	for old in savedPictures(runDir, prefix):
		_ = fs.deleteFile("{runDir}/{old}")
	label = "{words[2..].join(" ")} ({gpu})"
	words[at] = "{runDir}/{prefix}.png"
	out = "{dir}/{prefix}.out"
	code = runWithin(
		shellLine(
			inDir(
				root,
				withVariable(
					runVariable().name,
					runWith("gpu={gpu}"),
					"{quoteArg(exePath())} run {words[2..].join(" ")} > {quoteArg(out)} 2>&1"
				)
			)
		),
		testTimeoutMs
	)
	saved = savedPictures(runDir, prefix)
	if code != 0: return failedRun(label, code, out)
	if saved.isEmpty:
		print("  {label}: drew no picture at {words[at]}")
		return false
	same = true
	for name in saved:
		shown = label if name == "{prefix}.png" else "{label} {name}"
		same = keptPicture(dir, runDir, name, shown, update) and same
	same

# the PNG files of a dir whose names start with a prefix
fn savedPictures(dir str, prefix str):
	(fs.list(dir) ?? []).filter(.startsWith(prefix) and .endsWith(".png")).sorted()

# One picture of a run, compared with the one kept from the run before: whether it is the same
fn keptPicture(dir str, runDir str, file str, shown str, update bool):
	name = file[..len - 4]
	latest = "{runDir}/{file}"
	kept = "{dir}/{name}.kept.png"
	match decodedPicture(latest):
		picture:
			match decodedPicture(kept):
				before:
					difference = picture.compare(before, shotTolerance)
					pixels = picture.width.max(before.width) * picture.height.max(before.height)
					if difference.pixels * shotPixelsPerDifference <= pixels:
						_ = fs.writeFile(kept, fs.readFile(latest) ?? "")
						print("  same      {shown}")
						return true
					if update:
						_ = fs.writeFile(kept, fs.readFile(latest) ?? "")
						print("  kept new  {shown}: {difference.pixels} pixels differ")
						return true
					diffPath = "{dir}/{name}.diff.png"
					_ = picture.diff(before, shotTolerance).savePng(diffPath)
					print("  DIFFERS   {shown}: {difference.pixels} of {pixels} pixels, by up to {difference.largest} ({diffPath})")
					return false
				none:
					_ = fs.writeFile(kept, fs.readFile(latest) ?? "")
					print("  first     {shown}: kept")
					return true
		none:
			print("  {shown}: {latest} is no picture")
			return false

fn failedRun(label str, code i64, out str):
	print("  FAILED    {label}: exit code {code}")
	for line in (fs.readFile(out) ?? "").trimmedEnd().lines():
		print("    {line}")
	false

# the picture of a PNG file, none when there is none or it does not decode
fn decodedPicture(path str) image.Image?:
	data = fs.readBytes(path) ?? return none
	image.decodePng(data) ?? none

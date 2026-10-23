# The files the Mac reaches: the prepared disks' forks (projects/excel1/assets/<volume>/<name>.data and
# .rsrc), opened by name into paths of reference numbers as the File Manager numbers them (the
# offset of a file control block: 2, then each FCB's length further).

import disk
import fs

pub type OpenFork:
	name str
	volume str
	isResource bool
	bytes u8[]
	position i64
	isChanged bool

pub assetsDir = "projects/excel1/assets"
fcbLength = 94

pub mut openForks {i64: OpenFork} = {}

pub fn volumes() str[]:
	["Excel Program", "Excel Data"]

# the path of the fork of the file on the volume (or on any volume when it is "")
fn forkPath(volume str, name str, isResource bool) str?:
	stored = disk.fileName(name.bytes())
	suffix = ".rsrc" if isResource else ".data"
	for v in volumes():
		if volume != "" and volume != v: continue
		path = "{assetsDir}/{v}/{stored}{suffix}"
		if fs.exists(path): return path
	none

# whether the file is on a prepared volume, with either fork
pub fn hasFile(volume str, name str) bool:
	forkPath(volume, name, false) != none or forkPath(volume, name, true) != none

fn freeRefNum():
	n = 2
	while n in openForks:
		n += fcbLength
	n

# Opens a fork of a file: its reference number, none when the file is on no volume. A file with
# no fork of that kind opens empty.
pub fn openFork(volume str, name str, isResource bool) i64?:
	if not hasFile(volume, name): return none
	path = forkPath(volume, name, isResource)
	bytes = match path:
		p: fs.readBytes(p) ?? []
		none: []
	n = freeRefNum()
	openForks[n] = OpenFork(
		name = name.copy(),
		volume = volume.copy(),
		isResource,
		bytes,
		position = 0,
		isChanged = false
	)
	n

pub fn closeFork(refNum i64):
	if refNum in openForks: openForks.remove(refNum)

# the files of a volume in its directory's order
pub fn filesOn(volume str) str[]:
	text = fs.readFile("{assetsDir}/{volume}/directory.txt") ?? ""
	text.lines().filter(it != "").map(.copy())

# a file's directory entry: its Finder information (16 bytes), dates and attributes, empty when
# the file is not there
pub fn fileInfo(volume str, name str) u8[]:
	fs.readBytes("{assetsDir}/{volume}/{disk.fileName(name.bytes())}.info") ?? []

pub fn forkSize(volume str, name str, isResource bool) i64:
	path = forkPath(volume, name, isResource) ?? return 0
	file = fs.open(path) ?? return 0
	file.len

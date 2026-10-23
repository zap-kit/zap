# The display list as a player keeps it from frame to frame (SWF specification v19, chapter 3, and
# Ruffle's core/src/display_object/movie_clip.rs): a tree of nodes, the root the main timeline,
# each sprite at its own frame, playing or stopped. A step to the next frame applies that frame's
# commands; a jump to any other frame makes the children what the timeline shows there, keeping
# those placed by the same PlaceObject (so their state lives on), as Flash's goto does. A node made
# by script (attachMovie, duplicateMovieClip) is the timeline's no more, and one whose transform a
# script set keeps it. What changed is noted (`created`, `entered`, `removed`) for the script
# machine (avm1) to make objects for and run the code of.

# an object of the display list
pub type Node:
	placed Placed   # its depth, character, transform, name, clip depth and visibility
	parent i64   # -1: the root
	owner i64   # the character whose timeline placed it (0 the main one), -1 a script
	frame i64 = -1   # a sprite's frame shown, 0 the first; -1 before its first
	playing bool = true
	children i64[] = []   # by depth
	alive bool = true
	scripted bool = false   # its transform set by script, which the timeline then leaves
	dynamic bool = false   # made or moved in depth by script: the timeline never removes it
	text str = ""   # a text field's text, HTML when html
	html bool = false
	textColor Vec4? = none   # a text field's color set by script
	format TextOverride? = none   # what a script's setTextFormat set over a text field's runs
	bounds Rect? = none   # a text field's bounds as autoSize made them
	shrink bool = false   # Scaleform's textAutoSize "shrink": the text made smaller to fit the field
	scroll i64 = 1   # a text field's first line shown (1 is the top)
	field EditText? = none   # the field MovieClip.createTextField made, which no tag defines
	object i64 = -1   # its object in the script machine

# a frame a node showed
pub type Shown:
	node i64
	frame i64

# the display list of a scene's movie
pub type Stage:
	nodes Node[]
	created i64[] = []   # nodes made since the machine last took them, parents first
	entered Shown[] = []   # each frame shown, in order
	removed i64[] = []

# the text field a node is: the one a script made, else its character's
pub fn fieldOf(st Stage, scene Scene, n i64) EditText?:
	if st.nodes[n].field is own: return own.copy()
	(try scene.movie.editTexts.get(st.nodes[n].placed.character)).copy()

# the timeline a character plays: 0 the main one, else a sprite's; none for other characters
pub fn timelineOf(scene Scene, character i64) ref Timeline?:
	if character == 0: return scene.movie.timeline
	sp = try scene.movie.sprites.get(character)
	sp.timeline

# a stage at the movie's first frame
pub fn newStage(scene Scene) Stage:
	root = Placed(depth = 0, character = 0, matrix = Affine(), color = ColorTransform(), ratio = -1,
		name = "", clipDepth = 0, blend = 0, visible = true, placedAt = 0)
	st = Stage(nodes = [Node(placed = root, parent = -1, owner = -1)])
	st.created.push(0)
	st.showFrame(scene, 0, 0)
	st

# the frames of a node's timeline, 1 for what has none
pub fn frameCount(st Stage, scene Scene, n i64) i64:
	t = scene.timelineOf(st.nodes[n].placed.character) ?? return 1
	t.frameCount.max(t.frames.len).max(1)

# the node's next frame shown when it plays: the first after the last
pub fn stepFrame(mut st Stage, scene Scene, n i64):
	count = st.frameCount(scene, n)
	if count <= 1 and st.nodes[n].frame >= 0: return
	st.showFrame(scene, n, (st.nodes[n].frame + 1) % count)

# the node shows frame f (0 the first) of its timeline, its children made what that frame shows
pub fn showFrame(mut st Stage, scene Scene, n i64, f i64):
	t = scene.timelineOf(st.nodes[n].placed.character) ?? return
	if f == st.nodes[n].frame + 1:
		if f < t.frames.len:
			for c in t.frames[f].commands:
				match c:
					Place(p): st.applyPlace(scene, n, p, f)
					Remove(depth):
						if st.timelineChild(n, depth) is gone: st.removeNode(gone)
	elif f != st.nodes[n].frame:
		st.reconcile(scene, n, t.displayList(f))
	st.nodes[n].frame = f
	st.entered.push(Shown(node = n, frame = f))

fn applyPlace(mut st Stage, scene Scene, n i64, p Placement, f i64):
	at = st.timelineChild(n, p.depth)
	if at is c and p.moves:
		if not st.nodes[c].scripted: st.nodes[c].placed.moveTo(p)
		return
	if p.character < 0: return
	if at is c: st.removeNode(c)
	st.addChild(scene, n, p.placedOf(f), st.nodes[n].placed.character)

# The children made what the list says, those placed by the same PlaceObject kept with their name
# and their visibility, which a script may have set and a goto leaves (Ruffle's goto_frame applies
# a PlaceObject's transform to a kept clip, its visibility only when the tag carries one).
fn reconcile(mut st Stage, scene Scene, n i64, list Placed[]):
	for c in st.nodes[n].children.copy():
		if st.nodes[c].dynamic: continue
		was = st.nodes[c].placed
		keep = list.any(.depth == was.depth and .character == was.character and
			.placedAt == was.placedAt)
		if not keep: st.removeNode(c)
	for p in list:
		if st.timelineChild(n, p.depth) is c:
			if not st.nodes[c].scripted:
				name = st.nodes[c].placed.name.copy()
				visible = st.nodes[c].placed.visible
				st.nodes[c].placed = p.copy()
				st.nodes[c].placed.name = name
				st.nodes[c].placed.visible = visible
		else:
			st.addChild(scene, n, p.copy(), st.nodes[n].placed.character)

# how many clips hold the node, 0 for the root
pub fn depthOf(st Stage, n i64) i64:
	k = 0
	at = n
	while st.nodes[at].parent >= 0:
		at = st.nodes[at].parent
		k += 1
	k

# the child of n at this depth that its timeline placed
fn timelineChild(st Stage, n i64, depth i64) i64?:
	for c in st.nodes[n].children:
		if st.nodes[c].placed.depth == depth and not st.nodes[c].dynamic: return c
	none

# the child of n at this depth, whoever placed it
pub fn childAtDepth(st Stage, n i64, depth i64) i64?:
	for c in st.nodes[n].children:
		if st.nodes[c].placed.depth == depth: return c
	none

# the child of n with this instance name
pub fn childNamed(st Stage, n i64, name str) i64?:
	for c in st.nodes[n].children:
		if st.nodes[c].placed.name == name: return c
	none

# A new child of n placed as `placed` says (owner the character whose timeline places it, -1 a
# script), a text field with its own text, a sprite at its first frame.
pub fn addChild(mut st Stage, scene Scene, n i64, move placed Placed, owner i64) i64:
	id = st.nodes.len
	character = placed.character
	node = Node(placed, parent = n, owner, dynamic = owner < 0)
	if scene.movie.editTexts.get(character) is t:
		node.text = t.text.copy()
		node.html = t.html
	st.nodes.push(node)
	st.insertChild(n, id)
	st.created.push(id)
	if scene.timelineOf(character) != none: st.showFrame(scene, id, 0)
	id

fn insertChild(mut st Stage, n i64, id i64):
	depth = st.nodes[id].placed.depth
	kids = ref st.nodes[n].children
	at = kids.len
	for k in 0..kids.len:
		if st.nodes[kids[k]].placed.depth > depth:
			at = k
			break
	st.nodes[n].children.insert(at, id)

# the node and what it holds taken off the stage
pub fn removeNode(mut st Stage, n i64):
	if not st.nodes[n].alive: return
	p = st.nodes[n].parent
	if p >= 0: st.nodes[p].children = st.nodes[p].children.filter(it != n)
	st.markRemoved(n)

fn markRemoved(mut st Stage, n i64):
	st.nodes[n].alive = false
	st.removed.push(n)
	for c in st.nodes[n].children.copy():
		st.markRemoved(c)

# the node put at another depth of its parent, trading places with one there
pub fn swapDepth(mut st Stage, n i64, depth i64):
	p = st.nodes[n].parent
	if p < 0: return
	if st.childAtDepth(p, depth) is other:
		st.nodes[other].placed.depth = st.nodes[n].placed.depth
		st.nodes[other].dynamic = true
	st.nodes[n].placed.depth = depth
	st.nodes[n].dynamic = true
	kids = st.nodes[p].children.copy()
	st.nodes[p].children = kids.sortedBy(st.nodes[it].placed.depth)

# the node at a path of instance names from the root ("HUDMovieBaseInstance.Health")
pub fn nodeAt(st Stage, path str) i64?:
	n = 0
	for name in path.split("."):
		n = try st.childNamed(n, name)
	n

# the node's path of names from the root, "_level0" for the root
pub fn pathOf(st Stage, n i64) str:
	if st.nodes[n].parent < 0: return "_level0"
	"{st.pathOf(st.nodes[n].parent)}.{st.nodes[n].placed.name}"

# the node's matrix on the stage (twips): its parents' composed with its own
pub fn stageMatrix(st Stage, n i64) Affine:
	m = st.nodes[n].placed.matrix
	p = st.nodes[n].parent
	while p >= 0:
		m = st.nodes[p].placed.matrix.times(m)
		p = st.nodes[p].parent
	m

# the nodes that play, parents before their children, in depth order
pub fn playOrder(st Stage) i64[]:
	out = []
	st.collectOrder(0, out)
	out

fn collectOrder(st Stage, n i64, mut out i64[]):
	out.push(n)
	for c in st.nodes[n].children:
		st.collectOrder(c, out)

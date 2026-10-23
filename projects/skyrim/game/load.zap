# What a run of the game reads from the install and its prepared files: a test that checks the
# actors loads no textures, no sound and no graph.

import skyrim
import skyrim.hkx

pub type Load:
	dir str = skyrim.defaultInstall
	graph bool = true   # the character's behavior graph the actors animate with
	textures bool = true   # the cell's body: pixels and vertices
	sound bool = true   # the music and sound of the cell
	physics bool = true   # the prepared physics world
	dialogue bool = true   # the dialogue, its scripts and its voices

# a load of the world's data alone: no graph, textures, sound or dialogue
pub fn onlyWorld() Load:
	Load(graph = false, textures = false, sound = false, dialogue = false)

# the character's behavior graph of the install, an empty one (animating nothing) when not loaded
pub fn characterGraph(l Load) hkx.Graph:
	if l.graph: return openGraph(l.dir)
	hkx.Graph(nodes = [], root = -1, variables = [])

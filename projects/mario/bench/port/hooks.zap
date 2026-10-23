# Puts the benchmark harness (bench.c, beside this file, embedded when compiling) into a clone of
# sm64ex and hooks it in:
#   zap run projects/mario/bench/port/hooks.zap <the sm64ex clone>
# The game is changed only where the harness reads or drives it: it starts in Castle Grounds,
# its frame limiter and vsync go away when BENCH_UNCAPPED is set, the controller can be driven,
# the camera fixed and the frame read. The build is made to work with MinGW-w64 GCC 16 and
# without MSYS2 (see README.md).
#
# A pattern is the text to find, where "\n" also matches "\r\n" and "\s" one or more spaces,
# tabs or line breaks; each must be found exactly once.

import fs

# where a pattern matches the text at `at`: the end of the match, or -1
fn matchAt(text str, at i64, pattern str):
	t = at
	p = 0
	while p < pattern.len:
		c = pattern[p]
		if c == '\\' and p + 1 < pattern.len and pattern[p + 1] == 's':
			start = t
			while t < text.len and
				(text[t] == ' ' or text[t] == '\t' or text[t] == '\r' or text[t] == '\n'):
				t += 1
			if t == start: return -1
			p += 2
		else:
			if c == '\n' and t < text.len and text[t] == '\r':
				t += 1
			if t >= text.len or text[t] != c: return -1
			t += 1
			p += 1
	t

# the one place a pattern matches in the text, as (start, end); stops when it matches
# another number of times
fn findOnce(text str, pattern str, file str):
	found = -1, -1
	count = 0
	at = 0
	while at < text.len:
		end = matchAt(text, at, pattern)
		if end < 0:
			at += 1
		else:
			if count == 0:
				found = at, end
			count += 1
			at = end.max(at + 1)
	if count != 1:
		fail("hooks: {file}: {count} matches of {pattern}")
	found

# replaces each pattern, found exactly once, in a file of the clone
fn substitute(base str, file str, pairs (str, str)[]):
	path = "{base}/{file}"
	text = fs.readFile(path) ?? fail("hooks: cannot read {path}")
	for (pattern, replacement) in pairs:
		start, end = findOnce(text, pattern, file)
		text = text[..start] + replacement + text[end..]
	fs.writeFile(path, text) ?? fail("hooks: cannot write {path}")

# the dir that holds a path, absolute, with forward slashes (C:/dir for dir/sub)
fn parentDir(path str):
	fs.dirOf(fs.normalize(fs.join(currentDir(), path))).copy()

a = args
if a.len < 1:
	exit(2, "usage: zap run projects/mario/bench/port/hooks.zap <the sm64ex clone>")
base = a[0]
fs.writeFile("{base}/src/pc/bench.c", embed("bench.c")) ??
	fail("hooks: cannot write {base}/src/pc/bench.c")

# start in Castle Grounds: the main scripts with the level's number, past the menus
substitute(base, "levels/entry.c", [
	("SET_REG(/*value*/ 0),\n    EXECUTE(/*seg*/ 0x14, /*script*/ _introSegmentRomStart, /*scriptEnd*/ _introSegmentRomEnd, /*entry*/ level_intro_entry_1),",
		"SET_REG(/*value*/ LEVEL_CASTLE_GROUNDS),\n    EXECUTE(/*seg*/ 0x15, _scriptsSegmentRomStart, _scriptsSegmentRomEnd, level_main_scripts_entry),"),
	(
		"#include \"levels/intro/header.h\"",
		"#include \"levels/intro/header.h\"\n#include \"levels/scripts.h\""
)])

substitute(base, "src/pc/pc_main.c", [
	("    game_loop_one_iteration();", "    game_loop_one_iteration();\n    \{ extern void bench_frame_drawn(void); bench_frame_drawn(); }"),
	(
		r"void main_func(void) {",
		"void main_func(void) \{\n    \{ extern void bench_init(void); bench_init(); }"
)])

substitute(base, "src/pc/gfx/gfx_sdl2.c", [
	(r"static inline void sync_framerate_with_timer(void) {", "static inline void sync_framerate_with_timer(void) \{\n    if (bench_uncapped()) return;"),
	(
		"#include <GL/glew.h>\n#include <SDL2/SDL.h>",
		"#include <GL/glew.h>\n#include <SDL2/SDL.h>\nextern int bench_uncapped(void);"
)])
sdl = "{base}/src/pc/gfx/gfx_sdl2.c"
swap = (fs.readFile(sdl) ?? fail("hooks: cannot read {sdl}")).replace(
	"SDL_GL_SetSwapInterval(configWindow.vsync);",
	"SDL_GL_SetSwapInterval(bench_uncapped() ? 0 : configWindow.vsync);"
)
fs.writeFile(sdl, swap) ?? fail("hooks: cannot write {sdl}")

substitute(base, "src/pc/controller/controller_entry_point.c", [
	("        controller_implementations[i]->read(pad);\n    }", "        controller_implementations[i]->read(pad);\n    }\n    \{ extern void bench_controller(OSContPad *pad); bench_controller(pad); }")])

substitute(base, "src/game/rendering_graph_node.c", [
	("    mtxf_lookat(cameraTransform, node->pos, node->focus, node->roll);",
		"    \{ extern int bench_camera(float *pos, float *focus); bench_camera(node->pos, node->focus); }\n    mtxf_lookat(cameraTransform, node->pos, node->focus, node->roll);")])

# the sky drawn for the benchmark's camera as well (it reads Lakitu's, not the camera node's)
substitute(base, "src/game/level_geo.c", [
	("        gfx = create_skybox_facing_camera(0, backgroundNode->background, camFrustum->fov, gLakituState.pos[0],\n\\sgLakituState.pos[1], gLakituState.pos[2], gLakituState.focus[0],\n\\sgLakituState.focus[1], gLakituState.focus[2]);",
		"        f32 benchPos[3] = \{ gLakituState.pos[0], gLakituState.pos[1], gLakituState.pos[2] };\n        f32 benchFocus[3] = \{ gLakituState.focus[0], gLakituState.focus[1], gLakituState.focus[2] };\n        \{ extern int bench_camera(float *pos, float *focus); bench_camera(benchPos, benchFocus); }\n        gfx = create_skybox_facing_camera(0, backgroundNode->background, camFrustum->fov, benchPos[0], benchPos[1], benchPos[2], benchFocus[0], benchFocus[1], benchFocus[2]);")])

# the build on Windows without MSYS2: GLEW static from deps/prefix, old C accepted by GCC 16
deps = "{parentDir(base)}/deps/prefix"
substitute(base, "Makefile", [
	("    BACKEND_LDFLAGS += -lglew32 -lglu32 -lopengl32",
		"    BACKEND_CFLAGS += -I{deps}/include -include stdio.h -fpermissive -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types -Wno-error=int-conversion\n    BACKEND_LDFLAGS += -L{deps}/lib -lglew32 -lglu32 -lopengl32")])
# the asset extractor runs the Python it runs on (python3 is the Store's stub on Windows)
substitute(base, "extract_assets.py", [("\"python3\",", "sys.executable,")])
print("hooked {base}")

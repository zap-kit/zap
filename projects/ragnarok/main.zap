# Ragnarok: Ragnarok Online LATAM rebuilt in Zap on Zap's engine, from the player's own install
# (its data.grf: the map's RSW, GND and GAT, the models and textures, the sprites), nothing of
# the game in the repository. `zap run projects/ragnarok/prepare.zap` reads the install once and writes
# everything ready to use into projects/ragnarok/assets/prepared/; the game reads only that, and opens at
# once with the hero standing by Prontera's fountain (it prepares first, once, when the prepared
# files are missing or of an older format).
#
#   zap run projects/ragnarok/main.zap      a click on the ground walks there (8 directions, a cell in
#                                       150 ms; held, it keeps walking toward the cursor), the
#                                       wheel zooms, a right drag turns and tilts the camera, a
#                                       double right click puts it back, Esc leaves
#   needs: projects/ragnarok/assets/prepared (made by prepare.zap from the install)
#   zap run projects/ragnarok/main.zap --frames 120 --step 16 --shot ragnarok.png
#   zap run projects/ragnarok/main.zap --install D:/RO      (prepare from another install)
#   zap run projects/ragnarok/main.zap --at 156,180 --camera 30,140,50 --walkto 150,170
#       (stand on another cell, turn the camera 30 degrees, 140 cells away, looking down 50;
#       walk somewhere at once)
#   zap run projects/ragnarok/main.zap --step 16    (16 ms a frame whatever the clock says: screenshots
#                                       that repeat)
#   zap run projects/ragnarok/main.zap --replay "5:move 760 560;6:ldown;7:lup;20:rdown;21:drag 40 0"
#       (the mouse replayed from a script instead of read, game/input.zap)
#   zap run projects/ragnarok/main.zap --frames 600 --frametimes   (the frames' pacing summed up at the end)
#   zap run projects/ragnarok/main.zap --d3d12      (Direct3D 12 instead of Vulkan, as ZAP_RUN=gpu=d3d12)
#   zap test --only size

import engine
import game
import ragnarok
import world

# where the hero stands when the game opens (a cell of its GAT)
spawnX = 156
spawnY = 191

# the prepared map, prepared first when it is missing or of an older format
fn openZone(dir str):
	match world.openZone(game.startMap):
		z: z
		none:
			print("Ragnarok prepares itself from {dir} (once; zap run projects/ragnarok/prepare.zap does it ahead)...")
			game.prepareGame(dir, game.startMap)
			world.openZone(game.startMap) ?? fail("the prepared map cannot be read back")

started = clockSeconds()
dir = args.option("--install") ?? ragnarok.defaultInstall
zone = openZone(dir)
at = args.optionNumbers("--at").map(i64(it))
mut hero = game.newHero(
	zone.gat,
	at[0] if at.len == 2 else spawnX,
	at[1] if at.len == 2 else spawnY
)
mut frames = engine.newFrames()
mut win = engine.openWindow("Ragnarok", 1280, 960)
mut scene = zone.newScene()
if game.openFigures() == none or game.openCursors() == none:
	game.prepareFiguresAndCursors(dir)
mut figures = game.openFigures() ?? fail("the prepared hero cannot be read back")
mut cursors = game.openCursors() ?? fail("the prepared cursors cannot be read back")
print("Ragnarok: {zone.head.map}, {zone.head.placedModels} models placed, {zone.head.modelKinds} kinds, {zone.head.textures.len} textures, ready in {(clockSeconds() - started):.2} s")
mut camera = hero.place(zone.gat).newCamera(win.height)
# a camera asked for: its turn (degrees), how far it is (cells), how far it looks down
look = args.optionNumbers("--camera")
if look.len == 3:
	camera.setCamera(f32(look[0]), f32(look[1]), f32(look[2]))
walkTo = args.optionNumbers("--walkto").map(i64(it))
if walkTo.len == 2:
	hero.walkTo(zone.gat, walkTo[0], walkTo[1])
# a walk through the town for a test: cells x,y,x,y... walked to one after the other
tour = args.optionNumbers("--tour").map(i64(it))
mut stop = 0
# each frame's camera written out for a test (frame, yaw, pitch, distance, reach, lift)
cameraLog = args.hasFlag("--cameralog")
mut r = engine.newRenderer()
font = engine.loadFont("Segoe UI", 16)
mut input = game.newInputSource()
mut pointer = game.Pointer()
# the game draws its own cursor
engine.hideCursor(true)
mut ms = 0
mut fpsShown = 0
while win.nextFrame(frames):
	dt = frames.dt
	dtMs = i64((dt * 1000.0).round())
	ms += dtMs
	aspect = f32(win.width) / f32(win.height.max(1))
	# the input: the wheel zooms, a right drag turns and tilts, the left button walks
	i = input.readInput(frames.count)
	camera.steerCamera(win, i)
	pointer.leadHero(hero, zone.gat, camera, i, win.width, win.height, dtMs)
	if not hero.walking and stop * 2 + 1 < tour.len:
		hero.walkTo(zone.gat, tour[stop * 2], tour[stop * 2 + 1])
		stop += 1
	hero.stepHero(zone.gat, dtMs)
	camera.follow(zone, hero.place(zone.gat), dt)
	projection = camera.projection(aspect)
	view = camera.viewOf()
	if cameraLog:
		eye = camera.eyeOf()
		print("camera {frames.count} {hero.x} {hero.y} {camera.yaw:.2} {camera.pitch:.2} {camera.distance:.2} {camera.reach:.2} {camera.lift:.2} {eye.x:.2} {eye.y:.2} {eye.z:.2}")
	# the haze far past the hero, to soften the map's edge against the sky near the horizon
	scene.setFog(camera.distance + 80.0, camera.distance + 320.0)
	r.beginScene(scene, win.width, win.height)
	r.drawOpaque(scene, zone, projection, view, ms)
	r.drawTranslucent(scene, zone, projection, view, ms)
	if pointer.markedCell(zone.gat) is (cellX, cellY):
		r.drawCellMarker(cursors, zone.gat, cellX, cellY, projection, view)
	r.drawHero(figures, hero, zone, projection, view, camera)
	r.beginOverlay(win.width, win.height, engine.Camera())
	if frames.count % 30 == 0:
		fpsShown = frames.clock.fps
	label = "Ragnarok  {hero.x}, {hero.y}  {fpsShown} fps"
	r.drawLabel(font, label)
	# the cursor last, where the mouse is now (where the drag began while the camera turns)
	cx, cy = (camera.anchorX, camera.anchorY) if camera.dragging else (i.x, i.y)
	r.drawCursor(cursors, pointer.cursorOf(zone.gat, camera), ms, cx, cy)
	r.showFrame(win, frames)
print("the hero at {hero.x}, {hero.y}; {frames.fpsText()}")
frames.printFrames()

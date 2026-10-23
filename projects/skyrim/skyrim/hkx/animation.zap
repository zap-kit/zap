# An animation of a packfile's animation container, spline compressed (hkaSplineCompressedAnimation):
# its blocks decoded into curves when read, sampled at any time. Its binding names the skeleton it
# was made for and the bone each track moves.

pub type Animation:
	duration f32   # seconds
	frames i64
	frameDuration f32
	blockDuration f32
	skeletonName str
	trackToBone i64[]   # the bone each transform track moves
	blocks SplineBlock[]

# the class of the first animation of an HKX file, none when it has none
pub fn animationClass(bytes u8[]) str?:
	p = openPackfile(bytes) ?? return none
	container = p.animationContainer() ?? return none
	at = p.firstAnimation(container) ?? return none
	p.classAt(at)

fn firstAnimation(p Packfile, container i64) i64 ? str:
	animations = try p.containerList(container, containerAnimations)
	if animations.isEmpty or animations[0] < 0: return "no animation in the file"
	animations[0]

# the first animation of an HKX file, or why it cannot be read
pub fn readAnimation(bytes u8[]) Animation ? str:
	p = try openPackfile(bytes)
	container = try p.animationContainer()
	at = try p.firstAnimation(container)
	className = p.classAt(at)
	if className != "hkaSplineCompressedAnimation":
		return "{className} is not supported (hkaSplineCompressedAnimation is)"
	d = p.d
	tracks = i64(d.u32le(at + animationTransformTracks))
	floats = i64(d.u32le(at + animationFloatTracks))
	offsets = p.arrayAt(at + splineBlockOffsets)
	data = p.arrayAt(at + splineData)
	if not p.fits(offsets, 4) or not p.fits(data, 1):
		return "the animation's arrays run past the end"
	if offsets.count != d.u32le(at + splineBlocks) or offsets.count == 0:
		return "{offsets.count} block offsets for {d.u32le(at + splineBlocks)} blocks"
	bytesOf = d[data.first..data.first + data.count]
	blocks = []
	for b in 0..offsets.count:
		start = i64(d.u32le(offsets.element(b, 4)))
		if start + tracks * 4 > data.count: return "block {b} starts past the data"
		blocks.push(try readSplineBlock(bytesOf, start, tracks, floats))
	skeletonName, trackToBone = try p.bindingOf(container, at, tracks)
	Animation(
		duration = d.f32le(at + animationDuration),
		frames = d.u32le(at + splineFrames),
		frameDuration = d.f32le(at + splineFrameDuration),
		blockDuration = d.f32le(at + splineBlockDuration),
		skeletonName,
		trackToBone,
		blocks
	)

# the skeleton's name and the bone of each track as the binding of the animation at `at` gives
# them; track i moves bone i when no binding or an empty map says otherwise
fn bindingOf(p Packfile, container i64, at i64, tracks i64) (str, i64[]) ? str:
	identity = (0..tracks).map(it)
	for b in try p.containerList(container, containerBindings):
		if b < 0 or p.target(b + bindingAnimation) != at: continue
		bones = p.arrayAt(b + bindingTrackToBone)
		if not p.fits(bones, 2): return "a binding's bones run past the end"
		name = p.textAt(b + bindingSkeletonName)
		if bones.count == 0: return (name, identity)
		if bones.count != tracks: return "a binding of {bones.count} bones for {tracks} tracks"
		return (name, (0..tracks).map(i64(p.d.i16le(bones.element(it, 2)))))
	("", identity)

# how many transform tracks the animation has
pub fn trackCount(a Animation) i64:
	a.trackToBone.len

# every track's transform `time` seconds in (held at the ends)
pub fn sampleAnimation(a Animation, time f32) Transform[]:
	t = time.clamp(0.0, a.duration)
	block = i64(t / a.blockDuration).clamp(0, a.blocks.len - 1) if a.blockDuration > 0.0 else 0
	local = (t - f32(block) * a.blockDuration).max(0.0) / a.frameDuration
	a.blocks[block].tracks.map(.transformAt(local))

# every track's transform at frame i
pub fn frame(a Animation, i i64) Transform[]:
	a.sampleAnimation(f32(i) * a.frameDuration)

fn transformAt(c TrackCurves, t f32):
	p = c.translation.curveAt(t)
	q = c.rotation.curveAt(t)
	s = c.scale.curveAt(t)
	Transform(
		translation = Vec3(p.x, p.y, p.z),
		rotation = Quat(x = q.x, y = q.y, z = q.z, w = q.w).normalized(),
		scale = Vec3(s.x, s.y, s.z)
	)

# a text key of an animation: the event its clip sends at this time ("HitFrame", "weaponSwing",
# "SoundPlay.WPNSwingUnarmed"), as the annotation tracks hold them
pub type ClipEvent:
	time f32
	text str

# an animation's length and its text keys in time order
pub type ClipTimes:
	duration f32
	events ClipEvent[]

# The duration and the text keys of the first animation of an HKX file, whatever its
# compression; or why it cannot be read.
pub fn readClipTimes(bytes u8[]) ClipTimes ? str:
	p = try openPackfile(bytes)
	container = try p.animationContainer()
	at = try p.firstAnimation(container)
	tracks = p.arrayAt(at + animationAnnotationTracks)
	if not p.fits(tracks, annotationTrackSize): return "the annotation tracks run past the end"
	events = []
	for t in 0..tracks.count:
		notes = p.arrayAt(tracks.element(t, annotationTrackSize) + annotationTrackAnnotations)
		if not p.fits(notes, annotationSize): return "track {t}'s annotations run past the end"
		for n in 0..notes.count:
			a = notes.element(n, annotationSize)
			time = p.d.f32le(a)
			events.push(ClipEvent(time, text = p.textAt(a + annotationText)))
	duration = p.d.f32le(at + animationDuration)
	ClipTimes(duration, events)

# whether a decoded number is a real one of a sane size, not NaN or a runaway
pub fn isFinite(x f32) bool:
	x == x and x.abs() < 1.0e6

# What the tools print of a worn body: each model's parts, the posed body's extent, and the
# body posed as their command line asks, written as OBJ or drawn as a PNG.

import fs
import image
import math
import skyrim
import skyrim.esm
import skyrim.hkx
import skyrim.nif

# a line per worn model: slot, model, parts, triangles, bones and the bone names the skeleton lacks;
# under it a line per part: its textures and material
pub fn bodyLines(body BodyPart[], s hkx.Skeleton) str[]:
	out = []
	for b in body:
		triangles = b.parts.map(.indices.len / 3).sum()
		bones = b.parts.map(.boneNames.len).sum()
		unmatched = b.parts.flatMap(.unmatchedBones(s))
		out.push("{b.slot}: {b.model}, {b.parts.len} parts, {triangles} triangles, {bones} bones, unmatched [{unmatched.join(", ")}]")
		for p in b.parts:
			out.push("  {p.name}: {p.diffuse} {p.normal} colors {p.colors.len} normals {p.normals.len}/{p.positions.len} gloss {p.glossiness} spec {p.specularStrength} alpha {p.alpha.test} {p.alpha.threshold} {p.alpha.blend} two {p.twoSided}")
	out

# the posed body's bounds and the farthest a vertex lies from a bone it weighs on
pub fn poseLine(body BodyPart[], s hkx.Skeleton, worlds Mat4[], posed nif.Part[]) str:
	lo, hi = nif.partPositions(posed).boundsOf()
	size = hi - lo
	reach f32 = 0.0
	k = 0
	for b in body:
		for p in b.parts:
			reach = reach.max(p.largestReach(posed[k].positions, p.partBoneWorlds(s, worlds)))
			k += 1
	"posed: from ({lo.x:.1} {lo.y:.1} {lo.z:.1}) to ({hi.x:.1} {hi.y:.1} {hi.z:.1}), height {size.z:.1}, width {size.x:.1}, depth {size.y:.1}, farthest from a bone {reach:.1}"

# what a tool's command line asks to see of a body: a frame of a male animation (--anim, --frame)
# or the reference pose, written as OBJ (--obj) or drawn (--png), whole or its head (--head)
pub type FigureRequest:
	animation str?
	frame i64
	obj str?
	png str?
	framing Framing

pub fn figureRequest(words str[]) FigureRequest ? str:
	FigureRequest(
		animation = words.option("--anim"),
		frame = i64.parse(words.option("--frame") ?? "0") ?? return "--frame takes a number",
		obj = words.option("--obj"),
		png = words.option("--png"),
		framing = headAndNeck if "--head" in words else wholeFigure
	)

# Prints the worn models and the body posed as asked, and writes what is asked; hair and skinTone
# color the picture (none: the textures' own). Or why it cannot.
pub fn showFigure(
	i skyrim.Install,
	body BodyPart[],
	s hkx.Skeleton,
	request FigureRequest,
	hair esm.Color?,
	skinTone Vec3?
) ? str:
	for line in bodyLines(body, s):
		print(line)
	worlds = s.bindPose()
	if request.animation is name:
		a = try i.readMaleAnimation(name)
		print("{name}: frame {request.frame} of {a.frames}")
		worlds = s.framePose(a, request.frame)
	posed = posedParts(body, s, worlds)
	print(poseLine(body, s, worlds, posed))
	if request.obj is path:
		fs.writeFile(path, nif.objText(posed, [])) ?? return "cannot write {path}"
		print("wrote {path}")
	if request.png is path:
		picture = drawFigure(posed, i.figureTints(posed, hair, skinTone), request.framing)
		picture.savePng(path) ?? return "cannot write {path}"
		print("wrote {path}")

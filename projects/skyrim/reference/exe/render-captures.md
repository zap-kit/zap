# Render captures: what SkyrimSE.exe draws in the inn, read from RenderDoc

The game's own frames of compare.zap's six poses, captured with RenderDoc 1.46 (portable, in
`C:/tools/renderdoc`) and replayed without the game. The captures (`C:/tools/skyrim-rdc/*.rdc`) and
the scripts (`C:/tools/skyrim-rdc/harness`, `analysis`) stay outside the repository: they hold the
game's data.

## How they are taken (headless)

- `harness/hidden.py` starts a program on a hidden desktop of the session (`CreateDesktopW`): no
  window on the user's screen, no input.
- `qrenderdoc.exe --py harness/trigger.py` (on that desktop) launches SkyrimSE.exe injected
  (`ExecuteAndInject`), waits for the main menu, sends console commands, triggers one capture
  (`TargetControl.TriggerCapture`) and writes its path. qrenderdoc's first run asks about analytics:
  `Analytics_TotalOptOut: true` in `%APPDATA%/qrenderdoc/UI.config` keeps that dialog away.
- The console commands go in without keys (`harness/console.py`): the command string is written
  into the game and the console's execute (0x140909f90 in 1.7.104) is called on a thread of the game.
  `sStartingConsoleCommand` does not serve: this build reads it only at shutdown (0x140654610).
  Windows Defender flags that script (Exploit:Python/Leivion.C, a process injection pattern); the
  user excluded `C:/tools/skyrim-rdc`.
- The pose: `coc RiverwoodSleepingGiantInn`, then `bat zappose` (`harness/pose.py` writes it into the
  game's folder: fov, the three actors disabled, `tai`, setpos, setangle, `tm`).
- `analysis/*.py` (run the same way): `list.py` the actions, `history.py` a pixel's history,
  `cbuf.py` an event's constant buffers and targets, `shader.py` its bytecode, `texdata.py`
  textures, `fogfade.py` the SAO composite of every capture.

## What they show (start pose unless said)

- The floor's lighting draw (event 6095, BSLightingShader, the same instructions as ours): the sun's
  DirLightColor is 65 70 80 / 255 x 1.5 (the image space's sunlight scale); the point lights' colors
  are their color x fade x 0.781 (the fire) and x 0.868: the executable's flicker (0.76..0.91), not
  the measured 0.6 rest flicker.zap had; the directional ambient rows are ours (mean 0.175 0.187
  0.187, the -z/+z half difference on z).
- The SAO composite (ISSAOCompositeSAOFog, every pose): FogParam (0.025641, 0.00025641, 1, 1) = fog
  from 100 to 4000 units, power 1, max 1; FogNearColor = FogFarColor = 31 52 46 / 255 with w 0.8333,
  the fog fade the composed picture is multiplied by. Ported (occlusion.zap's fogFade). The source: BSShaderManager::State's
  invFrameBufferRange (CommonLibSSE, offset 0x9C), a static 1 / 1.2 at 0x1420d694c that only the
  SetFramebufferRange console command (handler 0x14037ac30) changes; Nukem9's SkyrimSETest writes
  it into FogNearColor.w.
- The HDR blend (ISHDR): Param (0.85, 1 / 1.1^2 = 0.826446, 0), Cinematic (1.05, 0, 1.2, 1.15), Tint
  (0.627 0.392 0.039, 0.05): ours; the 2 x 2 adapted luminances 0.162 0.150 / 0.191 0.197, both
  channels equal at rest; the bloom texture is all but black (mean 0.03 / 255). The blend's formula
  applied in Python to the game's input gives its output on 99.9% of the pixels within 8, and on
  ours gives our grade's output on 100%: the grade is exact, what differs is the scene before it.
- TAA's BlendParams (0.5, 0.8, 0.21, 0.21): ours (rest 0.8, speed 0.5, sharpen and overlay 0.21).

With the sun, the flicker and the fog fade as the game has them, our scene before the grade matches
the game's within 1 to 5% by band with the colors in balance (the saturation gap gone), 76.7% of
its pixels within 8; compare.zap's total moved 523.5 to 517.5 (table 96.4, backroom 96.9, start
82.1, bar 88.3): what is left is in the scene, pixel by pixel.

## The shadow mask (event 5197, RENDER_SHADOWMASKDPB)

The fire light's mask: the place from the depth (no normal offset), carried by the light's
view-projection (the paraboloid's axis the light's x, its projection `z' = (z - 0.1) / 0.9` on that
axis, the same in the map pass 117), its hemisphere's half of the atlas, the distance over the radius
(521.677) less a bias of 0.0125, compared 16 times at a Poisson disk (the shader's table) of radius
1/512 of the atlas, a tap that would leave its hemisphere keeping its v; a camera-distance fade
`1 - (d^2 / 9e6)^8` on the sum. Ported in `world/shaders/shadow.gpu.zap`: our shadowed share of the
start pose 21.7% against the game's 21.3% (the old 3 x 3 read with a 0.0005 bias: 23.7%), the two
masks agreeing on 97.8% of the pixels (97.0% before); compare.zap's total 517.5 to 513.9.

## The lit effects' light

Every lit effect draw (the bar's dust beams, event 8034; the start pose's 11420) takes its light from
the pixel constant buffer's row 8, the vanilla Effect.hlsl's PropertyColor: 105 114 118 / 255 on
every pose (alpha 0.9 for the beams), the unlit effects 1 1 1. Ours summed the cell's ambient and
each light by its fall-off at the pixel, which lit the bar's beam far brighter than the game's
(alpha 0.17 at a color of 0.13 there). Ported as a constant (`lighting.gpu.zap`'s effectLighting):
bar 88.3 to 96.2, total 513.9 to 522.8.

Where it comes from (found with the community's names, `C:/tools/skyrim-decomp/names.tsv`): the
effect's SetupGeometry (BSEffectShader 0x141557090) writes PropertyColor from
`BSEffectShaderProperty+0x88`, the external emittance color pointer (white when null), and alpha
from `+0x30`. The NIF's External Emittance flag (SLSF1 0x2000_0000) has the pointer aim at the
reference's emittance source (XEMI, ExtraEmittanceSource, extra 0x63): a LIGH's color, or a REGN's
`+0x40`, which TESObjectCELL 0x1402ba000 fills each frame with the region's weather's effect
lighting color (NAM0 color 9) at the hour: Sky::FillColorBlend 0x140416760 weighs two times of day
by the climate's TNAM (sunrise begin minus and sunset end plus fDaytimeColorExtension 0.5, half
widths, the middle one's own color), Sky::SetColor 0x140414cf0 sums the bytes times 1/255. The
inn's beams and the windows of its walls (FarmWindowInterior01, BSLightingShader: EmitColor =
`*emissiveColor x emissiveMult`, SetupGeometry 0x141549550) name REGN WeatherPineForest, whose
weathers include SkyrimClear; Update.esm sets SkyrimClear's day effect lighting to 105 114 118,
the captures' value exactly. Ported: `skyrim/esm/weather.zap`, `world/emittance.zap`, Skyrim.esm
opened with Update.esm and the DLC masters as overlays (`esm/file.zap`). With a lit effect
(Effect_Lighting) the shader instead takes DLightColor = sunlightScale x sun fade x the sun's
effectColor (NiDirectionalLight+0x14C, Sun::Update 0x14041bd90 copies Sky.skyColor[9]; in an
interior Sky::UpdateColors 0x140412df0 sets it to the cell's directional color).

## The captures' flicker state (exact11)

The fire and the lamps flicker at random (the executable's draws, 0x140274be0), so a capture holds
one state of them, and ours at another made the lit floor 5 to 7% off the game's: the start pose
drew the fire at 0.846 of its fade, the game's capture at 0.781. `analysis/lightrows.py` reads the
pixel constant buffer slot 3 (the shader's cb2: light positions in rows 15..21 with the radius in
w, colors in rows 22..28) of every draw; a light is told by its radius (the positions are relative
to each draw's own origin), its dimmer is the row's red over the light's prepared color (LIGH color
times its fade). A light the game has not updated reads 1.0 (start: the lamps of radius 184 and
380; firepit: also the shadow light). compare's poses.json lists them as `dimmers`, one a cell
light in the scene's order (fire, shadow light, then the lamps of radius 251, 447, 400, 184, 380,
251), 0 for a light the capture does not show (the two of radius 251 cannot be told apart by
radius), and compare.zap passes them as main.zap `--dimmers`. Share within 8 by pose, total 522.9
to 534.2: start 82.9 to 89.0, bar 96.2 to 95.6, firepit 62.5 to 64.8, table 93.7 to 94.1,
backroom 97.0, pelt 90.6 to 93.7. This is the capture's own state, not a fitted factor; what is
left is real.

## The shadow map's far plane (table pose)

The shadow pass (table capture, events 117..: VS 12370/12376, PS 12605..12608; raster state: back faces
culled, no hardware bias) writes SV_POSITION.z = |paraboloid vector| x 1/radius (cb0[1].x), with no
clamp: a fragment past the radius has z > 1 and the hardware clips it, so the map holds 1.0 (the
clear) there. Ours clamped the depth at 1 in the vertex stage, so a large triangle with a vertex past
the radius (the wall behind the table's pelt) interpolated too-near depths and shadowed a pelt at the
radius's edge (the stretched distance, the axis scaled by 1 / 0.9, puts the pelt at 1.0016 of the
radius): the fire's shadow ended at the pelt's left third in the game and covered all of it in ours;
a bias of 0.05 instead of 0.0125 hid it, which showed the occluder was within 26 units. Slice 1
of the atlas (texture 209, array 8, 2048 x 2048) is the fire's, slice 0 the other shadow light's.
`paraboloid` no longer clamps: table 94.1 to 96.4, pelt 93.7 to 94.6, start 89.0 to 89.2, firepit
64.8 to 65.0, total 534.2 to 537.8.

## The start pose's remaining difference, measured stage by stage

`analysis2/savexr.py` (job file: capture, event, texture, out.exr) saves any texture of a capture as
EXR; `analysis2/evdump.py` lists an event's textures, targets and constant buffers and saves its pixel
shader. With them the start pose's chain was compared stage by stage (our stage read by a temporary
shader hack, none kept):

- The mask (event 5197, texture 92) and our fire share disagree on 1.3% of the pixels, edges only.
- The lit color before the composite (event 11258, texture 55) matches ours within 1 to 4% (the
  bottom rows) with no fog and no occlusion; the occlusion (texture 134, red) is 0.996 on the floor
  in both. The fire's share regresses to 1.00 and the lamps' to 0.98.
- The lit shader does not fog its output: the DXBC ends in `min(c, c - FogNearColor.w x fogged(c) +
  clamp)` and `o = c - over x cb12[42].z` with cb12[42].z = 0, so the vertex stage's fog (radial
  distance, FogParam) only feeds the clamps. The fog is the SAO composite's alone: `lerp(ao x lit,
  fog color, share) x 0.8333` with share = (z - 100) / 3900 on the planar view depth z (the dp2 in
  its depth formula is the standard 2 n f / (...)); the game's HDR is reproduced from its own lit
  color, occlusion and depth to 0.003 mean error. Ours fogs in the lit stage (radial, from the
  cell's 0) and not in the composite; porting the game's form (lit stage unfogged, composite fogging
  at 100..4000) leaves the HDR error as it is (0.0157) and moves the total 537.8 to 537.4, so it was
  not kept.
- The ISHDR blend's output (event 13098, texture 116) equals our grade on the game's HDR and the
  game's 2 x 2 luminances (every pixel within 8, mean error 0.001): the grade is exact.
- The TAA pass (event 13129) is not a bias: binned by the graded luma it looked 3 to 5% darker on
  the bright floor, which is regression to the mean (the bin picks the pixels whose current value
  is above their history's); over the picture the output is 1.008 of the input, and the final pass
  (event 13202: its depth-of-field factor is 0 on every pixel, the 320 x 240 blur is unused) writes
  the TAA output unchanged. The remaining floor difference is between the capture's frame and the
  reference PNG: `assets/reference/*.png` are other frames than the `.rdc` files (the PNG's floor
  luma is 0.2548, the capture's 0.2695, ours 0.2681; PNG against capture: 93.5% within 8), so the
  flicker state of the PNG is not the one `dimmers` reads from the capture.
- TAA is ported exactly (`world/shaders/taa.gpu.zap`, see below).
- The door at the pit's right: see "The open door".
- The captures' samplers are anisotropic 16; the RHI's are 8 (16 changes 2% of the pixels, the share
  not at all).

## The TAA pass, ported from the DXBC (event 13129)

The pixel shader (`analysis2/ev13129.ps.dxbc`, disassembled with `analysis/dis.py`) is
Community Shaders' ISTemporalAA.hlsl, SDR path, instruction for instruction. Its inputs: t0 the
graded picture (RGBA8), t1 the history (RGBA8: luma, confidence, motion), t2 the motion vectors
(zero here: the camera stands still), t3 the depth, t4 a mask (its y is 0 here: no reject), t5 the
alpha coverage (a black 16 x 16: none); outputs 0 the color and 1 the new history. The constant
buffer (cb2): TexelSizeParams (1/W, 1/H), NeighborWeights (the bilinear weights that un-jitter the
frame: 0.34 center, 0.22 up, 0.27 left, 0.17 up-left for a jitter of 0.4375, 0.389 px),
TexelOffset (1/W, -1/H), BlendParams (0.5, 0.8, 0.21, 0.21), ThresholdParams.w 0.1.

- The history is luma, not color: the pixel and its eight neighbours give a bracket (the nearest
  luma under the history's and the nearest at or over it; -0.001 and 1.001 stand for none, and the
  other end for a missing one), kept as red, blue and luma (green is what the luma 0.5 g + 0.25 r
  + 0.25 b leaves); the color is the bracket's, interpolated where the history's luma lies.
- The weight on that resolve: lerp(0.8, 0.5, motion), capped by 1 - 20 |motion change|, then raised
  toward 0.99 by the confidence = saturate(0.25 saturate(neighbours 0.2 or more away in luma - 4)
  + 0.95 history confidence) times 1 - 100 |motion change|. A confidence under 0.9025 clamps the
  history luma into the bracket and lets a missing end stand for the other; above it the bracket
  keeps its sentinels (the game's wide bracket).
- The frame's own color is un-jittered (a bilinear read at the pixel shifted by the jitter), the
  resolve sharpened away from it by BlendParams z and laid back over it by w.
- The new history: luma + weight (history luma - luma) (the luma itself when that is under 0.01),
  the confidence, the motion (|velocity| over 128 pixels, saturated); 8 bits each.
- Checked in numpy on the capture's own inputs (`C:/tools/skyrim-rdc/analysis3/taa_np.py`): 99.8%
  of the color's pixels and 99.3% of the luma's within 1/255 of the game's output, the confidence
  99.99%. Ported in Zap: `taaFeedbackPixel` writes the history and `taaPixel` the color (the RHI
  has one target a pass); the history targets are RGBA8 as the game's. The jitter is ours (a
  centered Halton, the picture un-jittered by the shift beginFrame applied); the game's NeighborWeights
  are its own jitter's bilinear weights. Not ported: the mask and alpha coverage branches (dead
  here) and dynamic resolution.
- Measured: compare.zap's total 537.8 to 537.7 (start 89.2 to 89.3, bar 95.6 to 95.4, firepit 65.0
  to 65.2, table 96.4, backroom 97.0 to 96.9, pelt 94.6 to 94.5): none, as the picture is static
  and its history has converged; the port is kept for being the game's.

## The open door

The door at the pit's right is FarmhouseAnimDoor02 `000E3A79` (RiverwoodInnDelphineRoomDoor, at
-1023.9 415.5, persistent, owner Delphine's faction; the other FarmhouseAnimDoor02, `000E3A7B` at
-767.7 -417.6, is left of the start pose's view). Neither has ONAM or an XLOC; Update.esm and the
DLC masters do not touch them; the only records that name `000E3A79` are MQ106's property
(InnRoomDoor) and MQ106IntroScene's condition, none running at a new game. The game's open state
of a door is set at its 3D load by TESObjectREFR::InitNonNPCAnimation 0x1402ef180 (SetOpenState
0x1401d9eb0 with the reference's ExtraAction bit 8, which ONAM sets, flipped by two form-id sets
of the Game singleton: none at a new game).

What opens it is the AI: the pathing system cuts every loaded door into the navmesh, a path through
a closed door carries it as a point, and the actor reaching the point sends itself
MovementMessageActivateDoor, whose handler (0x1406a81d0) activates the door; nothing plays Close, so
an actor that opens a door leaves it open (NOTES.md, Doors). The harness (`harness/trigger.py`)
loads the cell with `coc`, lets the game run 30 seconds, then `bat zappose` disables Delphine
(`13485`), Orgnar (`13486`) and Embry (`3550C`) and waits 15 seconds more before the capture.
Delphine's reference is placed in the hall (-494.8 155.0) while her package at every hour is
DelphineStartInRoom (the room at about -1004 640, whose only entrance is this door): she walks there
through the door in those 30 seconds. The port does the same: the residents start at their
references, walk over the navmesh and open the door at the crossing (walktests.zap), and the door is
drawn in its pose: its NIF's Open sequence turns the node Door02 about z from 0 to about 90 degrees
in one second (`world/movables.zap`, doortests.zap), the leaf a movable part of the prepared cell
rather than baked into its buffer. A headless run of 3000 frames (`main.zap --free --at -900,100,0
--eye 120 --look 335,-5 --bare`) shows it open with Delphine in her room.

## The references are the captures' final frames

The PNGs in `assets/reference` were taken at another moment than the `.rdc` captures that pinned
the dimmers (the start PNG's floor luma 0.2548, its capture 0.2695), so compare.zap now measures
against each capture's own presented frame: `analysis/finals.py` saves the last action's output as
`<pose>-final.png` (1280 by 960, beside the PNGs, never committed) and poses.json names it in the
pose's `capture` field; a pose without the file falls back to its PNG, masks apply to both. The
firepit capture stood on the pit's step, not at the pose: the camera is read from the draws
(`analysis3/objpos.py`: each draw's model matrix translation is the object minus the eye; the mode
of the translation differences over models both captures draw, against the start capture, gives the
eye; bar, table, backroom and pelt come out exactly at their poses), here (-500, -335, 184), so
poses.json's `captureAt` holds the feet (-500, -335, 63.35) and compare.zap draws ours there.
Share within 8, PNG baseline to capture final: start 89.3 to 88.4, bar 95.4 to 94.6, firepit 65.2
to 68.0, table 96.4 to 95.7, backroom 96.9 to 98.9, pelt 94.5 to 93.6; total 537.7 to 539.2.
There is one capture of each pose, so no game-against-game ceiling is measured; the ceiling is the
share that the capture's own TAA jitter and the flicker state (already pinned) leave, not
measurable without a second capture of the same pose.

## The captures' TAA jitter and dimmers, pinned per pose (poses.json)

The TAA event's cb1[1] holds the frame's jitter in uv; in pixels it is the centered Halton (2, 3)
point of index 1..8, exactly ours (picture.zap's beginFrame): start 8, bar 1, firepit 3, table 7,
backroom 7, pelt 2 (the index is (capture number + 2) mod 8, 8 for 0). poses.json's `jitter` gives
it and compare.zap passes `--jitter-phase` so the last of its 30 frames lands on that index
(`analysis4/taacb.py`). Total 539.2 to 540.2 (start 88.4 to 88.2, firepit 68.0 to 68.9, table 95.7
to 95.8, backroom 98.9 to 99.1, the rest unchanged): the history converges, the jitter only moves
edges.

poses.json had lost its `dimmers` (the file is git-ignored), so the 539.2 above was unpinned.
`analysis4/perdraw.py` lists every draw's lights; a light's dimmer is the red of its exact-radius
rows (a draw divides the radius by the object's scale, so scaled rows are skipped) over our
prepared color (fire 2.0353, the lamps 1.1647), the most common value across draws (the bar's
draws before event 4371 hold an earlier flicker state, 0.8985 / 0.7979, than the later ones).
The two radius-251 lamps are told by their offset inside one draw (+240 in x for lamp 2). Order
fire, shadow light, 251, 447, 400, 184, 380, 251:
start 0.7809 0 0 0.8872 0.8684 1 1 0; bar 0.8958 0 0 0.7861 0 0 0 0; firepit 0.8138 1 0 0 0.8821 1 1 0;
table 0.7781 0.8777 0 0 0.8437 0 0.8107 0; backroom 0 0 0.8571 0 0 0 0 0.8312;
pelt 0.8231 0.7743 0 0 0.7652 0 0.8037 0. Total 540.2 to 544.0: start 89.6, bar 93.0 (from 94.6),
firepit 70.0, table 96.2, backroom 99.2, pelt 96.0.

What remains: the bar's capture has Orgnar standing at the counter (ours has none there), and the
flicker's position offsets (at most 8 units for a lamp, 2 for the fire) and the SAO's per-frame
angle are not pinned.

# The game's own pictures

`compare.zap` measures our picture of the Sleeping Giant Inn against pictures SkyrimSE.exe took
of the same cell from the same camera. The pictures and `poses.json` live in
`projects/skyrim/assets/reference/` (gitignored: they are the game's). This file says how they
were taken, so they can be taken again.

## The game's settings

`Documents/My Games/Skyrim Special Edition/` in the user's profile, made before the first run:

- `Skyrim.ini`: the install's `Skyrim_Default.ini` plus
  - `[General] sIntroSequence=` (no intro video), `bAlwaysActive=1` (renders unfocused);
  - `[Display] fDefaultWorldFOV=65`, `fDefault1stPersonFOV=80` (the defaults, written out);
  - `[Controls] bGamepadEnable=0`.
- `SkyrimPrefs.ini`: the install's `Skyrim/SkyrimPrefs.ini` with `bFull Screen=0`,
  `bBorderless=1`, `iSize W=1280`, `iSize H=960` (our window's size) and `bGamepadEnable=0`.

## Driving it

SkyrimSE.exe started directly (its dir the working dir). Keys go in through user32 `SendInput`
with scan codes (`KEYEVENTF_SCANCODE`); the menus also take mouse clicks. The first run shows
the Anniversary Edition's download offer, then "cannot connect to Bethesda.net" and "all
creations loaded": each closed by clicking its one button. In the main menu the console opens
with the grave key (scan code 0x29); the first key after it opening can be lost, so a Backspace
goes first.

Console commands, in order:

- `coc RiverwoodSleepingGiantInn`
- `fov 65 65`
- `prid 3550C`, `disable`, `prid 13485`, `disable`, `prid 13486`, `disable` (the cell's three
  actors), `tai` (the others stand still)
- per pose: `player.setpos x|y|z <v>`, `player.setangle z <yaw>`, `player.setangle x <pitch>`,
  read back with `player.getpos` and `player.getangle`, then `tm` (no menus), PrintScreen (the
  game writes `ScreenShot<n>.png`, 1280x960, beside SkyrimSE.exe), `tm` again
- `qqq` to quit

The game's own screenshot is exact; a capture of the window is not (Windows scales the
DPI-unaware window by the display's 125%).

## The camera

- Angles: `setangle z` is the heading in degrees (0 north, 90 east), as our `--look`'s first
  number; `setangle x` is the pitch, positive looking down, our `--look`'s second number negated.
- The first person camera stands 120.5 units over the player's settled feet (`getpos z` reads
  0.35 on the inn's floor, so the eye is at 120.85).
- `fov 65` is the width of a 16:9 frame's view: at 1280x960 the view is 39.4 degrees high
  (`game.fovY`), not 65 high nor 65 wide.

Both were measured on the start pose by drawing ours over a range of heights and fovs and
correlating the edges with the game's picture: it peaks sharply at height 121 with the 16:9
convention (0.68; 0.49 half a unit lower, at most 0.44 with the view 1% wider or narrower), where
the 65-degree-high view main.zap drew before showed everything at 56% of its size. Once the
lighting matched, the high-passed pictures' correlation by thirds of the frame showed ours a pixel
low on every pose; 120.5 over the feet puts the peak at no shift on table, start, pelt and
backroom alike (120.65 a pixel low, 120.3 a pixel high).

## The poses

The player's feet (x, y, z), yaw and pitch in the game's convention; fov 65, eye 120.5 for all.

| name     | x     | y    | z    | yaw   | pitch | masked (x, y, w, h)  |
|----------|-------|------|------|-------|-------|----------------------|
| start    | 8     | -170 | 0.35 | 288.1 | 14.4  | 500, 180, 300, 220   |
| bar      | -780  | -60  | 0.35 | 270   | 5     |                      |
| firepit  | -488.5 | -331.5 | 0.35 | 0    | 20    | 120, 180, 860, 180   |
| table    | -258  | 170  | 0.35 | 0     | 15    |                      |
| backroom | -1024 | -520 | 0.35 | 180   | 0     |                      |
| pelt     | -266  | -50  | 0.35 | 0     | -5    |                      |

`firepit` was set at -512, -330, inside a table and its bench: the game moved the player out of
them before the picture. Where it was is measured from the picture itself: the shift between
ours and the game's, band by band down the frame, grows with nearness, so the camera stood about
24 units east; at -488.5, -331.5 no band is shifted by more than a few pixels.

`start` is main.zap's opening view, the eye 120.85 over the floor instead of 140. The masks cover
the fire's flames. A pose must stand on clear floor: one on the fire pit's rim is lifted by the
game's physics. Two captures of `start` minutes apart differ by 3.6, 2.5, 1.5 (red, green, blue)
on average and agree within 8 on 92% of the pixels outside the mask: the game's own flicker,
the floor under which compare.zap's numbers mean nothing.

## The menus

`assets/reference/menus/` holds the game's menus at 1280x960, `menus.json` naming each capture,
the keys that opened it, the state it shows, the command that draws ours (`compare.zap --menus`)
and the rectangles compared (the menu's own pixels; the 3D scene behind is left out). They were
taken in one run as above, with these differences:

- `sLanguage=ENGLISH` in `Skyrim.ini` for the run (the install's default is RUSSIAN; the user's
  file is put back afterwards): our menus read `translate_english.txt` and the English strings.
- The game takes keys only while its window is in front: before each key it is brought there
  (`AttachThreadInput` to the foreground thread, `BringWindowToTop`, `SetForegroundWindow`), a key
  held 150 ms. Console lines longer than a few words lose keys: they go in a text file beside
  SkyrimSE.exe run with `bat <name>` (one command a line). Windows' own grab of the screen is not
  reliable (a "not responding" ghost window covers the game while it loads); the game's
  PrintScreen is.
- Each PrintScreen puts "ScreenShot: File ... created" in the HUD's corner for about 5 s, over
  menus too: the next capture waits 6 s. The mouse is moved far right and down first, so the
  cursor is off the menus.
- `coc` from the main menu gives the player an iron armor kit and the war axe drawn; for a new
  game's inventory the console takes them off (`player.removeitem` 12e49, 12e4b, 12e46, 12e4d;
  `player.additem` and `player.equipitem` 3c9fe and 3ca00; `player.unequipitem` 13790). The food
  barrel 36c37 rolls its leveled list: `prid 36c37`, `removeallitems`, `additem 64b3f 5` gives the
  cabbages a new game's sim has.
- Esc opens the journal on its quests page the first time; its system tab was clicked. A message
  box came from the system page's Creations offline ("Couldn't connect to the Bethesda.net
  servers."); activating an owned bed in the inn showed no prompt at the poses tried, so no
  owned-bed message was taken. Leaving through the front door and coming back shows no location
  name for the inn (it was visited by coc); the HUD's notice ("Autosaving...") was taken instead.
- What the captures taught: the game stretches every menu to the window (exactFit) but the tween
  menu (showAll); it darkens the scene under a menu (the journal to 0.40 of its light, a message
  box 0.45, the item menus 0.87, the tween menu 0.90) and blurs it; the compass reads the yaw from
  the cell's north marker (235.4 degrees in the inn); arrows weigh nothing in the carry weight.

## The dialogue

`assets/reference/menus/dialogue-*.png` were taken in one run as the menus were (sLanguage=ENGLISH),
with `bDialogueSubtitles=1` in `SkyrimPrefs.ini` and no actor disabled, the coc kit changed the same
way, at 9:15 of the coc'd day: the player at -1080, 79, 0 facing 270 (pitch 5) across the counter
from Orgnar (at -1213, 79), F for the third person view. `dialogue-before` is that view, E pressed
6 s later; `dialogue-greeting` 2.2 s after it (his greeting's subtitle, his four topics, the first
selected); Down, Down, Enter on "Heard any rumors lately?" and `dialogue-response` 1.9 s after
(the Dark Brotherhood's rumor, the list put away); `dialogue-topics` 8 s after the answer began,
the topics offered again with MS13's rumors in place of the first.

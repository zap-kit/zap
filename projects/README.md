# Projects

Programs on the engine, one dir each under `projects/`.

| Project | What it is |
|---|---|
| `projects/mario/` | Super Mario 64 rewritten in Zap, frame for frame against the PC port |
| `projects/ragnarok/` | Ragnarok Online LATAM rebuilt in Zap, from your own install |
| `projects/skate3/` | Skate 3 (Xbox 360) rewritten in Zap, opening in University |
| `projects/minecraft/` | Minecraft, a world of blocks |
| `projects/lab/` | The engine's graphics lab, a scene per key |

## Your own copies of the games

Nothing from Super Mario 64, Ragnarok Online, Skate 3 or Pokemon FireRed is in this repository, and nothing from
them must ever be committed. These projects read the original game's data from a copy you own:

- **`projects/mario/`** needs your own **Super Mario 64 (USA)** cartridge dump, at `projects/mario/rom/sm64.us.z64`.
- **`projects/ragnarok/`** needs **Ragnarok Online LATAM** installed (by default `C:\Gravity\Ragnarok`, or
  pass `--install <folder>`).
- **`projects/skate3/`** needs your own **Skate 3 (Xbox 360)** disc image, an `.iso` in `projects/skate3/disc/` (or
  pass `--iso <file>`). The first run decodes University and the skater from it into
  `projects/skate3/assets/` (`zap run projects/skate3/prepare.zap` does it by hand); `projects/skate3/NOTES.md` describes
  the disc and its formats.
- **`projects/firered/`** (planned) needs your own **Pokemon FireRed (USA)** cartridge dump, at
  `projects/firered/rom/firered.gba`, read once by `zap run projects/firered/prepare.zap`, which writes the game's
  code and data into `projects/firered/recomp/` and `projects/firered/assets/` (out of git); the game then plays
  without the ROM.

`.gitignore` keeps the dump and anything extracted from the games out of git.

From the clone's root, with `build` on your `PATH`:

```
zap run projects/mario/main.zap
zap run projects/ragnarok/prepare.zap
zap run projects/ragnarok/main.zap
zap run projects/skate3/main.zap
zap run projects/minecraft/main.zap
zap run projects/lab/main.zap
```

`projects/ragnarok/prepare.zap` reads your Ragnarok Online install once (`--install <folder>` when
it is not in `C:\Gravity\Ragnarok`) and writes the map and the hero, ready to use, into
`projects/ragnarok/assets/prepared/`; the game then reads only those files and opens at once. When
they are missing or were written by an older version, the game prepares them itself the first
time.

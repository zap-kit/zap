# What the executable says

Text derived from the player's own `SkyrimSE.exe` with REA (github.com/morluto/rea) over Ghidra
12.1.4, one file a theme, each fact with the address it was read at. Nothing of the game is
copied here: only names, numbers and shapes we need to write Zap. Addresses are the image's
(base 0x140000000) and hold only for this build.

| | |
|---|---|
| file | `C:/games/Skyrim Anniversary Edition/SkyrimSE.exe`, 37,910,440 bytes |
| sha256 | 2c9cb9d61f3721ffb43a234764fe112864a89f4d63579c31fd028a3720047679 |
| version | 1.7.104.0 (the PE version resource; NOTES.md's "1.6.1170" was the SE build this AE install was assumed to carry) |
| format | PE32+ x86_64, no PDB (Ghidra's symbol lookup finds none: GUID ae3f5f99-472e-44ce-9d81-6030f9c7b5c3, age 1) |
| no Address Library | the ids of SKSE's Address Library do not apply; functions here are found by their strings, their settings and their RTTI |

How to read it: the whole analysis was exported once to text outside the repository, so no
disassembler needs to run again (`C:/tools/ghidra-scripts/ExportAll.java`, run headless by
`run-skyrim-export.cmd` there, which also keeps the Ghidra project `C:/tools/ghidra-projects/skyrim.gpr`):

| `C:/tools/skyrim-decomp/` | what |
|---|---|
| `functions/<1 MB block>.c` | the pseudocode of every function (175,999), each under `// ==== 0x<entry> <name> ====`, by address |
| `index.tsv` | entry, name, size, block of each function |
| `calls.tsv` | caller, callee, call site |
| `strings.tsv` | each defined string's address, the functions that read it, its text |
| `datarefs.tsv` | every reference from code to data: the address, the instruction, its function |

So a setting's readers are `awk -F'	' '$1=="<value address>"' datarefs.tsv` (the value is the
`SettingT`'s address plus 8, `settings.md`'s tables give it), a string's are in `strings.tsv`, a
function's body is the block's `// ==== 0x<entry>` section. REA (the MCP server, `REA_ANALYSIS_PROVIDER=ghidra`)
is for what the text cannot answer (bytes, decoded instructions).

Files:

- `gmst-*.md`, `ini-*.md`, `ini-prefs.md`: every setting compiled into the executable with its
  default (the layout of a `SettingT` and how the tables were read is at the top of each).
- `skills.md`: skill experience by use, the character's levels and the stats menu. `perks.md`: the
  perk records, who holds a perk, the entry points and choosing a perk in the stats menu.
- `classes-*.md`: the RTTI classes of each system with their vtables.
- `menus.md`: the menus' callbacks, messages, `UserEvents` and `InterfaceStrings` tables, the item
  list and card. `dialogue.md`: `MenuTopicManager`. `combat.md`: the stagger and confidence
  formulas and how to find a setting's readers. `stealth.md`: sneaking, detection, the stealth
  meter and pickpocketing. `havok.md`: the collision filter's matrices.
  `animation.md`: the behavior graph's names.

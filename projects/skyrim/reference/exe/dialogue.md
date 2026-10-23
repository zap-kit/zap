# The dialogue: MenuTopicManager and the dialogue menu

Read from `SkyrimSE.exe` 1.7.104 with REA (`procedure_pseudo_code` of the functions named here).
The menu side (callbacks, messages, the topic list's filling) is in `menus.md`; here the manager
that owns the conversation. `game/dialogue/` and `game/talk.zap` are the port's reading of the
plugin's records; this is how the executable walks them.

## MenuTopicManager (singleton `DAT_1431df408`, vtable 0x1418fea40)

| offset | what |
|---|---|
| +0x18 | the current topic node (a linked list node: `[0]` the topic entry, `[1]` next) |
| +0x20 | the topic list's head |
| +0x30 | the current response (`DialogueResponse`-like, or 0) |
| +0x38 | the current `DialogueItem` (0x58 bytes, made by 0x1405ed830 from the topic's quest `+0x28`, topic `+0x50`, info `+0x30` and the speaker) |
| +0x40 | the critical section every menu call takes |
| +0x68 | the speaker's handle (0x14017ebe0 resolves it; a form of type 0x3e ACHR is an actor speaker, else the speaker is a talking activator) |
| +0x70 | the last response's info |
| +0xb0 | the speaker already faced the player |
| +0xb2 | the last said info was a "say once" (`info flags & 1`) |
| +0xb3 | the list is empty / the conversation must close |
| +0xb5, +0xb6 | one-shot flags: a line ended, the speaker is not talking |
| +0xb7 | skip the first topic (a greeting is at the head) |
| +0xb8 | a response is playing |
| +0xb9 | the voice is ready |
| +0xba | the menu is open and may skip |
| +0xc0, +0xc8, +0xd0 | the infos said this conversation: `BSTArray<TESTopicInfo*>` (data, capacity, count) |

A topic entry (`node[0]`): `+0x00` the topic's text, `+0x08` its length (0xffff: null terminated),
`+0x28` the quest, `+0x30` the info, `+0x49` a bool shown to the movie, `+0x4a` hidden, `+0x50` the
`TESTopic`. The topic's `+0x32` is its subtype (0x14209ce58's table, stride 10, tells which subtypes
are skipped when walking to the first topic: value 1 = skip).

## The functions

| address | what |
|---|---|
| 0x1405ee620(manager, skipAuto) | first topic: `+0x18 = +0x20` (its next when `+0xb7`); with skipAuto, skips the topics whose subtype's table entry is 1; true if a topic remains |
| 0x1405ee6a0(manager) | next topic (advances `+0x18`), true while one remains |
| 0x1405ee800(manager) | the current topic entry (`*+0x18`) |
| 0x1405ee6d0(manager, index) | select the topic at `index` (counting from the first, past the greeting when `+0xb7`): sets `+0x18`, and for an actor speaker runs the topic's `TESTopic` through 0x1403ef230(topic, speaker, player) with 0x140300c60 / 0x140300c30 around it (the topic's info chosen for this speaker, conditions evaluated); true when the entry holds a topic |
| 0x1405efb90(manager, fromMenu, ...) | say the selected topic: resolves the speaker; if the current item's info has flag `+0x20 & 4` on the topic's `+0x38` (the "random" / "no cross" flag family), tells the speaker (slot 0x270) to face the player, else only when 0x1405ee620-style `+0xb0` is clear; takes the entry's info (`+0x30`), marks it said (`+0x3c |= 0x8000` when the info's `+0x30 & 1`), runs 0x1403f2bb0 (the info's result scripts, with the speaker's handle), records `+0xb2 = info flags & 1` (say once); 0x1405f0fa0; appends the info to the said array; then, unless `fromMenu`, starts the response: `DAT_143211afa = 1`, and if the speaker is an actor that cannot speak (0x1406754b0) or a talking activator without a voice (0x140cc9730 / 0x140cc96e0) the speaker's slot 0x278 ends it, else 0x1405efe90 |
| 0x1405efe90(manager) | the response loop: under the lock, when a new item is pending (`DAT_143211afa`), drops the topic node already used (0x1405f2390 / 0x1405f2420) and builds the `DialogueItem` for the current topic (0x1405ed830); with no item, the end (0x1405f0820); with an item not yet playing: if the item has a response (`+0x40`), the speaker's slot 0x260 (play the response's voice/line) and `+0x70 = info`; else if the info is not "say once" and the topic is not hidden, finish; else re-selects the first topic, picks its info for the speaker (0x1403ef230) and says it (0x1405efb90) again; the end path runs 0x1405f04b0, 0x14098e4e0(a response exists) and 0x14098e5a0 (the menu's text hide and list show); afterwards `+0xb8 = 0`, `+0xb5 = +0xb6 = 0`, `+0xba = 1` |
| 0x1405f0820(manager) | skip / end of a line: only when `+0xba`; if the current item's response has no voice pending (`+0x30`'s `+0x3c & 0x40` clear) and no next response (`+0x40`): when nothing plays, starts the first response (0x1405efdf0(manager, 0)) or, after a "say once", marks the list to close (`+0xb3`); when a response plays and the voice is not ready yet, marks it ready and runs the end path; else (a voice playing) the speaker's slot 0x278 stops it |
| 0x1405f0ec0(manager) | the index of the topic whose `TESTopic` matches the last said info's topic (walks the said array from the end), for the list's selected row |
| 0x1405f2520 / 0x1405ee850 | the manager's two virtual functions (vtable 0x1418fea40) |

The dialogue menu's `TopicClicked` (0x14092ab70) only acts while a response is not playing
(`menu+0x30 == 1`) and the argument is a number: 0x1405ee6d0(index) then 0x1405efb90(manager, 0, 0).
`SkipText` (0x14092ab30) is 0x1405f0820 under the lock.

## What this settles for the port

- The topic list the movie shows is the manager's list minus the hidden entries, each with its
  text, the `+0x49` bool and its index; the selected row is the topic of the last said info.
- A "say once" info closes the list after its line; the said infos are kept per conversation in
  the array at `+0xc0`.
- The speaker turns to face the player only for infos whose topic carries the `+0x38 +0x20 & 4`
  flag or when it has not faced the player yet in this conversation (`+0xb0`).
- The greeting is the list's head and is skipped (`+0xb7`) when the topics are shown.

Not read: 0x1403ef230 (how an info is chosen among a topic's, with the conditions and the
"random" and "say once" flags; the port's `choose.zap` does this from the records), 0x1405ed830
(the `DialogueItem`'s responses from the info's `TESTopicInfo::ResponseData`), the voice file
naming (the port's `voice.zap` has it), and the speaker's slots 0x260 / 0x270 / 0x278 (the actor's
speak, face-player and stop-speaking virtuals).

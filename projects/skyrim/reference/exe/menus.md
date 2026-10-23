# The menus: how the executable drives the Scaleform movies

Each menu is an `IMenu` (vtable layout in `classes-menus.md`): the game creates it by name, calls
`Accept` once with a `CallbackProcessor` that registers the GameDelegate callbacks the movie may
call (`FUN_140cfc860` builds the BSFixedString name, the processor's slot 1 binds name to handler),
and then feeds it `UIMessage`s through `ProcessMessage`. Everything below was read from the
pseudocode of those two functions of each menu (REA `procedure_pseudo_code`); the menu's vtable
slot 1 is `Accept`, slot 4 `ProcessMessage`.

## The shared pieces

| | address | what |
|---|---|---|
| `UI` singleton | `DAT_1421a05c0` | the menu map and message queue |
| `InterfaceStrings` singleton | `DAT_1421a05c8` | the menu names and the message-data type names as BSFixedStrings; the menus compare a message's menu name and data type against its fields (offsets below) |
| `UserEvents` singleton | `DAT_1432048d0` | the control names (table below), built by `FUN_140d04050` |
| `MenuTopicManager` singleton | `DAT_1431df408` | the dialogue state (see `dialogue.md`) |
| `Inventory3DManager` singleton | `DAT_1432309f8` | the rotating item model; `+0x150` is its zoom (0 at rest), `+0x154` 1.0 |
| `PlayerCharacter` singleton | `DAT_143230778` | |
| `MemoryManager` singleton | `DAT_143275ae0` | slot 0x60 frees |
| `FUN_14117a9d0(movie, name, FxResponseArgs)` | | `Invoke` on the menu's movie (`menu+0x10` is the `GFxMovieView`) with typed args; `FxResponseArgs<N>::vftable` holds N values |
| `FUN_140cf6160(value, ..., name, args, n)` | | `GFxValue::Invoke` on a value (the menu's root at `menu+0x30`) |
| `FUN_140cf8350(value, ..., member, GFxValue)` | | `GFxValue::SetMember` |
| `FUN_140cf5a40(value, ..., member, out)` | | `GFxValue::GetMember` |
| `FUN_1401b47f0(UI, &menuName, type[, data])` | | `UIMessageQueue::AddMessage`: 1 show, 3 hide, 0xb ... |
| `FUN_1409350a0(layer)` / `FUN_140936340(layer)` | | `ControlMap` push and pop of an input context by name: "DialogueMode", "TweenMode", "InventoryMode", "Favor", "Swimming", "HorseMode", "MovementDisabled" |
| `FUN_1409920a0("UIFavorite")` | | play a UI sound by editor id ("UIJournalOpen", "UIFavorite", the menu's own at `InterfaceStrings+0x1f8`/`+0x200`) |
| `FUN_140987240(id)` | | a HUD or tutorial notification by id (0xf8 at the barter menu's show, 0xfc at the journal's, 0x103 at a favorite toggled); not read further |
| `FUN_14098dd00(...)` / `FUN_14098da10` | | message box and HUD notification requests |
| `FUN_14116ede0` | | `IMenu::ProcessMessage` (the base: a menu returns it for messages it does not take) |
| `FUN_140905790(list, GFxValue)` | | push a value on an `FxResponseArgsList` |
| `FUN_1401d6e40(min, max)` | | a random float between two settings' values (used by the combat code too) |

`UIMessage` (`param_2`): `+0x00` the menu name, `+0x08` the type, `+0x10` the data (`IUIMessageData`,
whose `+0x18` is a BSFixedString name of the user event for type 7 and a payload at `+0x20`).
The types are CommonLibSSE's `UI_MESSAGE_TYPE`: 0 kUpdate, 1 kShow, 2 kReshow, 3 kHide, 4 kOpen,
5 kClose, 6 kScaleformEvent, 7 kUserEvent, 8 kInventoryUpdate (data `+0x10` is the actor's form id,
`+0x18` the item changed, 0 for all), 9 kUserProfileChange, 10 kMUStatusChange, 11 kResumeCaching,
12 kUpdateController (data `+0x10` the control's name, `+0x18` an out flag set by `FUN_14098e7b0`),
13 kChatterEvent.

A `ProcessMessage` returns 0 (kHandled), 1 (kIgnore), 2 (kPassOn). The item menus return 2 for
unknown types only while the 3D item is not zoomed.

A form's type is the byte at `form+0x1a`, CommonLibSSE's `FormType`; the values the menus test:
0x1a ARMO, 0x29 WEAP, 0x2e ALCH, 0x34 SLGM, 0x3e ACHR, 0x77 SHOU.

## UserEvents (`DAT_1432048d0`), the control names by offset

Built by `FUN_140d04050` (one BSFixedString per 8 bytes). The menus compare a user event's name
against these; a port keys its controls by the same names (controlmap.txt uses them).

| offset | name | offset | name | offset | name |
|---|---|---|---|---|---|
| 0x08 | Forward | 0x10 | (Back) | 0x18 | Strafe Left |
| 0x20 | Strafe Right | 0x28 | (Move) | 0x30 | (Look) |
| 0x38 | Activate | 0x40 | Left Attack/Block | 0x48 | Right Attack/Block |
| 0x50 | Dual Attack | 0x58 | ForceRelease | 0x60 | Pause |
| 0x68 | Ready Weapon | 0x70 | Toggle POV | 0x78 | (Jump) |
| 0x80 | Journal | 0x88 | Sprint | 0x90 | (Sneak) |
| 0x98 | Shout | 0xa0 | KinectShout | 0xa8 | (Grab) |
| 0xb0 | (Run) | 0xb8 | Toggle Always Run | 0xc0 | Auto-Move |
| 0xc8 | Quicksave | 0xd0 | Quickload | 0xd8 | NewSave |
| 0xe0 | Inventory | 0xe8 | Stats | 0xf0 | (Map) |
| 0xf8 | Screenshot | 0x100 | Multi-Screenshot | 0x108 | Console |
| 0x110 | CameraPath | 0x118 | Tween Menu | 0x120 | Take All |
| 0x128 | Accept | 0x130 | Cancel | 0x138 | (Up) |
| 0x140 | (Down) | 0x148 | (Left) | 0x150 | Right |
| 0x158 | PageUp | 0x160 | PageDown | 0x168 | (Pick) |
| 0x170 | PickNext | 0x178 | PickPrevious | 0x180 | Cursor |
| 0x188 | Kinect | 0x190 | SprintStart | 0x198 | SprintStop |
| 0x1a0 | sneakStart | 0x1a8 | sneakStop | 0x1b0 | blockStart |
| 0x1b8 | blockStop | 0x1c0 | blockBash | 0x1c8 | attackStart |
| 0x1d0 | attackPowerStart | 0x1d8 | reverseDirection | 0x1e0 | Unequip |
| 0x1e8 | Zoom In | 0x1f0 | Zoom Out | 0x1f8 | RotateItem |
| 0x200 | Left Stick | 0x208 | PrevPage | 0x210 | NextPage |
| 0x218 | PrevSubPage | 0x220 | NextSubPage | 0x228 | LeftEquip |
| 0x230 | RightEquip | 0x238 | ToggleFavorite | 0x240 | Favorites |
| 0x248 | Hotkey1 | 0x250 | Hotkey2 | 0x258 | Hotkey3 |
| 0x260 | Hotkey4 | 0x268 | Hotkey5 | 0x270 | Hotkey6 |
| 0x278 | Hotkey7 | 0x280 | Hotkey8 | 0x288 | Quick Inventory |
| 0x290 | Quick Magic | 0x298 | Quick Stats | 0x2a0 | Quick Map |
| 0x2a8 | ToggleCursor | 0x2b0 | (Wait) | 0x2b8 | Click |
| 0x2c0 | MapLookMode | 0x2c8 | Equip | 0x2d0 | DropItem |
| 0x2d8 | Rotate | 0x2e0 | NextFocus | 0x2e8 | PreviousFocus |
| 0x2f0 | SetActiveQuest | 0x2f8 | PlacePlayerMarker | 0x300 | XButton |
| 0x308 | YButton | 0x310 | ChargeItem | 0x318 | (null) |
| 0x320 | PlayerPosition | 0x328 | LocalMap | 0x330 | LocalMapMoveMode |
| 0x338 | Item Zoom | | | | |

The names in parentheses are strings Ghidra did not inline (`DAT_141b544a0` and the like); their
place in CommonLibSSE's `UserEvents` gives the name.

## InterfaceStrings (`DAT_1421a05c8`), the names by offset

Built by `FUN_141177a90` (one BSFixedString per 8 bytes). A menu compares a `UIMessage`'s menu
name (`+0x00`) and its data's type name against these fields.

| offset | name | offset | name | offset | name |
|---|---|---|---|---|---|
| 0x08 | FaderData | 0x10 | HUDData | 0x18 | HUDCamData |
| 0x20 | FloatingQuestMarkers | 0x28 | ConsoleData | 0x30 | QuantityData |
| 0x38 | MessageBoxData | 0x40 | BSUIScaleformData | 0x48 | BSUIMessageData |
| 0x50 | BSUIAnalogData | 0x58 | InventoryUpdateData | 0x60 | RefHandleUIData |
| 0x68 | TESFormUIData | 0x70 | LoadingMenuData | 0x78 | KinectStateChangeData |
| 0x80 | KinectUserEventData | 0x88 | InventoryMenu | 0x90 | Console |
| 0x98 | Dialogue Menu | 0xa0 | HUD Menu | 0xa8 | Main Menu |
| 0xb0 | MessageBoxMenu | 0xb8 | Cursor Menu | 0xc0 | Fader Menu |
| 0xc8 | MagicMenu | 0xd0 | Top Menu | 0xd8 | Overlay Menu |
| 0xe0 | Overlay Interaction Menu | 0xe8 | Loading Menu | 0xf0 | TweenMenu |
| 0xf8 | BarterMenu | 0x100 | GiftMenu | 0x108 | Debug Text Menu |
| 0x110 | MapMenu | 0x118 | Lockpicking Menu | 0x120 | Quantity Menu |
| 0x128 | StatsMenu | 0x130 | ContainerMenu | 0x138 | Sleep/Wait Menu |
| 0x140 | LevelUp Menu | 0x148 | Journal Menu | 0x150 | Book Menu |
| 0x158 | FavoritesMenu | 0x160 | RaceSex Menu | 0x168 | Crafting Menu |
| 0x170 | Training Menu | 0x178 | Mist Menu | 0x180 | Tutorial Menu |
| 0x188 | Credits Menu | 0x190 | Mod Manager Menu | 0x198 | Creation Club Menu |
| 0x1a0 | Login Menu | 0x1a8 | Marketplace Menu | 0x1b0 | TitleSequence Menu |
| 0x1b8 | Console Native UI Menu | 0x1c0 | Kinect Menu | 0x1c8 | LoadWaitSpinner |
| 0x1d0 | StreamingInstallMenu | 0x1d8 | TextWidget | 0x1e0 | ButtonBarWidget |
| 0x1e8 | GraphWidget | 0x1f0 | TextureWidget | 0x1f8 | UIMenuOK |
| 0x200 | UIMenuCancel | 0x208 | Show Text | 0x210 | Hide Text |
| 0x218 | Show List | 0x220 | Voice Ready | 0x228 | DMFOStr |
| 0x230 | Show Journal | 0x238 | Journal Setttings Saved | 0x240 | CloseMenu |
| 0x248 | Closing All Menus | 0x250 | RefreshMenu | 0x258 | CancelLoading |
| 0x260 | UserSettingsLoaded | 0x268 | ActivityStarted | 0x270 | Menu Texture Degrade Event |
| 0x278 | the quest marker img tag | | | | |

So the dialogue menu's kUpdate data types are "Show Text", "Hide Text", "Show List", "Voice Ready"
and "DMFOStr" (the dialogue-mode fade), the journal's "Show Journal", "Journal Setttings Saved"
and "RefreshMenu"; "CloseMenu" (0x240) is the user event every menu closes on; the message box's
sounds are UIMenuOK and UIMenuCancel. The .data copies of the menu names (0x1420ba790 BarterMenu
and the rest) are the static strings the menus' own classes register under.

## The menus

Per menu: the vtable, `Accept` and `ProcessMessage`, the callbacks the movie may call with the
handler each is bound to, and what `ProcessMessage` does per message type (the Invoke names are the
ActionScript functions of the menu's SWF the game calls).

### DialogueMenu (vtable 0x141974998)

- Accept 0x14092a980: SkipText -> 0x14092ab30 (`MenuTopicManager::SkipText` 0x1405f0820 under the
  manager's lock), TopicClicked -> 0x14092ab70 (the argument is the topic's index: selects it with
  0x1405ee6d0 and says it with 0x1405efb90), FadeDone -> 0x14092ac00, CloseMenu -> 0x14092ac70,
  PlaySound -> 0x140991e00 (shared by every menu).
- ProcessMessage 0x14092a5a0: kUpdate with the data type at `InterfaceStrings+0x208`:
  Invoke "ShowDialogueText"(text); `+0x210`: "HideDialogueText"; `+0x218`: rebuild the topic list
  (0x14092b0d0, below); `+0x220`: "NotifyVoiceReady"; `+0x228`: the movie's slot 0x40 (set the
  menu's visibility by the payload), pushes "DialogueMode" when the payload is set, pops it when not.
  kShow with data: 0x14092b7f0 (Invoke "SetSpeakerName"(name) and a HUD request). kHide with a set
  payload: "StartHideMenu" and return 1 (keep the menu until FadeDone); kHide otherwise: pop
  "DialogueMode" and send two messages (0x14092bd10 with ids 0x89 and 0x8a) to the fader. Type 6
  returns 2 while the dialogue flag `DAT_1432563f9` is set.
- The topic list 0x14092b0d0: under the manager's lock, if the manager has topics (0x1405ee620),
  for each topic (0x1405ee800 current, 0x1405ee6a0 next) that is not hidden (`+0x4a`): the text
  (or "$Empty" when blank), a bool at `+0x49` and the index as a double are pushed onto one
  FxResponseArgsList; with fewer than 2 values the list is marked empty (`manager+0xb3`); else it
  compares the new names with the names shown last time (case insensitive) to tell the movie
  whether the list changed, keeps the names, and invokes "PopulateDialogueList"(list...,
  changed, param) and "ShowDialogueList"(changed, param, selected index or -1); the selected
  index comes from 0x1405f0ec0 (the last said info's topic).

### InventoryMenu (vtable 0x141978208)

- Accept 0x140943850: PlaySound, UpdateItem3D -> 0x140943d00, RequestItemCardInfo -> 0x140943d80,
  CloseMenu -> 0x140943e70, ShowTweenMenu -> 0x140943ea0, CloseTweenMenu -> 0x140943ed0,
  ItemSelect -> 0x140943f20, ItemDrop -> 0x140943fb0, ShowSoulGemList -> 0x1409440d0,
  ItemCardListCallback -> 0x140944590, QuantitySliderOpen -> 0x140944910, SaveIndices ->
  0x1409449e0, StartMouseRotation -> 0x140905d10, StopMouseRotation -> 0x140905d20, ZoomItemModel
  -> 0x140944b60, CheckForMouseEquip -> 0x140944d50.
- ProcessMessage 0x140942b80: kUpdate (data type `+0x88`): "ItemRotating". kShow: starts the 3D
  item (0x14093d990 with mode 1), gets `_root.GetInventoryItemList` and makes the ItemList
  (`menu+0x48`, 0x58 bytes, its `entryList` member read by GetMember), the ItemCard (`menu+0x50`,
  0x140947110) and the bottom bar (`menu+0x58`, 0x140966cc0), then fills them: 0x140945050,
  0x1409452b0 (the item list), 0x1409451e0, 0x140945e20. kHide: tears them down. kUserEvent:
  "Item Zoom" or Accept while the 3D item is at rest -> "ToggleMenuFade"; LeftEquip ->
  "AttemptEquip"(1.0); RightEquip -> "AttemptEquip"(0.0); XButton -> "DropItem"; YButton ->
  toggles the favorite of the selected entry (0x140905370 selected entry, 0x140940f50 can be a
  favorite, else the message "You cannot favorite that item" with sound UIMenuCancel; 0x1402374c0 /
  0x140237a20 add and remove the favorite, "UIFavorite" sound, 0x140905930 refreshes the list);
  ChargeItem -> "AttemptChargeItem"; Quick Inventory (0x288) -> the movie's slot 0x168 (close).
  kInventoryUpdate for the player: with no item, refresh the list (0x1409452b0, 0x1409451e0) and
  update the player's 3D (0x140724680 / 0x1406f6720); with an item, record it in a sorted array
  at `menu+0x60` of items to refresh; an item of form type 0x1a (ARMO) marks `DAT_143257eec` when
  the player wears it (0x1401d2170). kUpdateController: the control's name mapped through
  0x140942450 (the hotkeys 1..8 give 1..8, else -1); Favorites (`+0x240`): close; the three column
  controls (`DAT_143257e70/78/80`) switch the sort column (`menu+0x7c` 1..6) and refresh.
- Shared by ContainerMenu, BarterMenu, GiftMenu, MagicMenu (same shape, own addresses below).

### ContainerMenu (vtable 0x141971a90)

- Accept 0x140910e90: PlaySound, UpdateItem3D -> 0x1409112b0, RequestItemCardInfo -> 0x140911310,
  CloseMenu -> 0x140911680, ItemTransfer -> 0x1409116b0, EquipItem -> 0x140911810,
  QuantitySliderOpen -> 0x1409119d0, TakeAllItems -> 0x140911a70, ToggleFavorite -> 0x140911a90,
  DisabledItemSelect -> 0x140911aa0, StartMouseRotation, StopMouseRotation, ZoomItemModel ->
  0x140911ac0, CheckForMouseEquip -> 0x140911cb0.
- ProcessMessage 0x14090ff70: kShow as the inventory's, plus SetMember `bNPCMode` = (the container
  mode `DAT_1432560b8` is 2 or 3: a follower or a pickpocket) and, when `menu+0xb9`, Invoke
  "ShowItemsList"; the fillers are 0x1409126e0, 0x140912a80, 0x1409129b0. kHide in mode 2
  (follower, `DAT_143256180` the container's handle): every item still marked (`menu+0x78` array)
  is given back to the actor with 0x1405cab50 and the actor's inventory updated through its
  slot 0x2b0. kUserEvent: zoom/accept -> "ToggleMenuFade"; LeftEquip/RightEquip ->
  "AttemptEquip"(1.0/0.0); XButton -> "XButtonPress"; YButton -> if `isViewingContainer` is false
  (GFxValue call on the root), 0x1409139b0 (favorite). kInventoryUpdate as the inventory's for the
  player or the container (`DAT_143256180`), with 0x140914640 testing the item against the kept
  list. kUpdateController: the hotkeys select rows (1..9 as given, 11..20 minus 9 for the second
  column unless mode 3), Favorites closes, three column controls (`DAT_143256168/70/78`), Take All
  (`+0x120`) or `DAT_1432561c0` -> 0x140913d20 (take all, unless mode 2); the dev controls
  `DAT_143256190..b8` set the global `DAT_1420ba9b0` (a float: max, 5, 10, 25, 50, 100).

### BarterMenu (vtable 0x14196f408)

- Accept 0x140901060: PlaySound, UpdateItem3D -> 0x140901360, RequestItemCardInfo -> 0x1409013c0,
  CloseMenu -> 0x1409014b0, ItemSelect -> 0x1409014e0, GetRawDealWarningString -> 0x140901840,
  StartMouseRotation, StopMouseRotation, ZoomItemModel -> 0x140901a30, QuantitySliderOpen ->
  0x140901c20.
- ProcessMessage 0x140900580: kShow builds the lists (`menu+0x30/38/40`) and computes the two
  barter multipliers: starting from 1.0 both, the player's perk entry point 0x11
  (kModBuyPrices, 0x140447180 / 0x140420be0) changes them, then the merchant (handle
  `DAT_143255bc4`) applies 0x14038cff0 twice with the actor values 8 and 0x3c (the barter
  factors of the Speech skill and the buy/sell multiplier), the buy multiplier is clamped to at
  least `DAT_1420aeae0` and at least 1.0, the sell multiplier to at most `DAT_1420aeaf8` and at
  most 1.0 (`settings.md` names those two by address); Invoke "SetBarterMultipliers"(buy, sell);
  fillers 0x140901d20, 0x140902270, 0x140901f10; notification 0xf8. kHide pops "InventoryMode".
  kUserEvent: zoom/accept -> "ToggleMenuFade" only. kInventoryUpdate for the player or the
  merchant. kUpdateController: hotkeys, Favorites closes, column controls `DAT_143255ba8/b0/b8`.

### MagicMenu (vtable 0x14197a7f8)

- Accept 0x140952d10: PlaySound, UpdateItem3D -> 0x140953010, RequestItemCardInfo -> 0x140953070,
  CloseMenu -> 0x1409533b0, ShowTweenMenu -> 0x1409533e0, CloseTweenMenu -> 0x140953410,
  ItemSelect -> 0x140953450, SaveIndices -> 0x1409534e0, DisabledItemSelect -> 0x140953660,
  ShowShoutFail -> 0x1409536f0.
- ProcessMessage 0x140952080: kShow: 3D item in mode 2, the item's placement from one of two
  constant sets by the aspect ratio (above 4:3 the second), lists at `menu+0x30/38/40`, fillers
  0x1409539a0, 0x1409542f0, 0x140954220, 0x1409547b0. kUserEvent: YButton toggles the favorite of
  the selected spell (0x140951230 is favorite, 0x140951050 add, 0x140951150 remove, "UIFavorite",
  0x140956ef0 refresh, notification 0x103); XButton on a shout (form type 0x77 SHOU) with a
  word known but not unlocked: with no dragon souls (actor value 0x85 <= 0) the message "Use Dragon
  Souls to unlock shout", else a message box "Spend Soul?" with two buttons (`PTR_DAT_1420abc78`,
  "Cancel") and a `SpendSoulCallback`; Quick Magic -> close; LeftEquip/RightEquip ->
  "AttemptEquip"(1.0/0.0). kInventoryUpdate: refresh. kUpdateController: the hotkeys
  (`DAT_1432581a8..f0`, 0..9) -> 0x140954950(menu, hotkey, flag); Favorites closes.

### FavoritesMenu (vtable 0x141975188)

- Accept 0x14092cb20: FadeDone -> 0x14092cc30, PlaySound, ItemSelect -> 0x14092ccd0.
- ProcessMessage 0x14092c8f0: kShow: 0x1409513d0 (the favorites manager `DAT_143223e50` refresh);
  if there are none (0x14092d920), hide at once (message 3 to `InterfaceStrings+0xb8`) and return
  1, else 0x14092dc10 when `DAT_143256400`. kUserEvent while not fading (`menu+0x71`): Left or
  Right Attack/Block (0x40, 0x48) equip the selection to that hand (0x14092df60 with 0x14038fa30 /
  0x14038fa40 giving the hand; both hands 0 when `menu+0x73`). kInventoryUpdate for the player with
  no item: if no favorites remain, "StartFadeOut".

### MessageBoxMenu (vtable 0x14197c788)

- Accept 0x140962e80: buttonPress -> 0x140962f50, PlaySound.
- buttonPress 0x140962f50: the top of the message box stack (`DAT_143258408` array, `DAT_143258418`
  count) gives the box; its button index base `+0x4c` plus the argument is the result given to the
  box's callback (`+0x40`, slot 1); the box's sound at `InterfaceStrings+0x1f8` is played; the
  box is removed (0x140963410) and the next shown (0x140963530).
- ProcessMessage 0x140963050: kShow with boxes pending and the menu not open yet: show the next;
  kHide with boxes pending: show the next and return 1 (the menu stays).

### TweenMenu (vtable 0x1419818b8)

- Accept 0x140988290: OpenHighlightedMenu -> 0x140988440, HighlightMenu -> 0x140988460,
  StartCloseMenu -> 0x140988480, CloseMenu -> 0x1409884a0, OpenAnimFinished -> 0x1409884d0.
- ProcessMessage 0x140987c00: kUpdate for its own name (`InterfaceStrings+0xf0`): 0x140988710,
  0x140988b40, and the player's 3D update. kShow when no other menu is pending
  (`DAT_1431a5720+0x20` == 0): the camera 0x1408f9910, "TweenMode", 0x140935550, a budget change
  (0x140669250 4, 0xa00000), the three skydome models of `PTR_s_Interface_INTPerkSkydome_nif`
  queued into `menu+0x30`, 0x140988710, the saved camera FOVs (0x14095f6f0 saves into
  `menu+0x48/4c`, 0x14095f710 sets `DAT_1420bba70/88`), 0x14117a120; else return 1. kHide:
  camera back (0x1408f9a00) and the FOVs restored. kUserEvent: `InterfaceStrings+0x270` (the
  loaded-models data) attaches the three models (0x140fc8e80); Tween Menu (0x118) -> the movie's
  slot 0x168 (close). kUpdateController: Quick Stats (0x298) -> 0x140988ba0(menu, 1); Quick Magic
  (0x290) -> message 1 to `+0xc8` (MagicMenu), "HideMenu", FOVs restored, camera state 6, the
  player's 3D off; Quick Inventory (0x288) -> message 1 to `+0x88` (InventoryMenu), camera state 7;
  Quick Map (0x2a0) -> 0x14098df90(`+0x110`, 1, player form id) and message 3 to `+0xf0` (itself),
  camera state 8; Favorites (0x240) -> close.

### JournalMenu (vtable 0x141989d98)

- Accept 0x1409ac4d0: RequestPlayerInfo -> 0x1409ac8b0, RememberCurrentTabIndex -> 0x1409acc00,
  PlaySound, CloseMenu -> 0x1409ac6d0, ShouldShowMod -> 0x1409acc20 (only when the Creations
  service 0x141598ef0 / 0x141599440 says no), myLog -> 0x1409acd40.
- ProcessMessage 0x1409abe30: kUpdate with data types `+0x230` "ShowMenu", `+0x238`
  "SettingsSaved", `+0x250` "RefreshSystemButtons" (and 0x1409a6450 on the quest journal at
  `menu+0x98`), `DAT_143258b30` a `FadeThenLoadCallback` with the save slot in the payload
  (0x14098ddd0 fades then loads); other kUpdate data goes to the map/quest part 0x14098f170
  (`DAT_1431e0140`), returning 2 when it declines. kShow: 0x14098f470 (the map menu part with
  `+0x148`), the quest list hooked (0x1405b9680), Invoke "RestoreSavedSettings"(savedTab as double
  when the payload asks, else 0; bool: a setting pending `DAT_143258ec4` or the UI's `+0x170`),
  sound "UIJournalOpen", 0x1409ad230 (when Creations are off) or notification 0xfc, the FOVs saved
  and set (`DAT_1420bc980/98`). kHide: unless `menu+0xe0`, Invoke "StartCloseMenu"(true) and
  return 1. kUserEvent: swallowed (returns 0). kChatterEvent clears `DAT_1432303b2`.

### SleepWaitMenu (vtable 0x14197f4e8)

- Accept 0x140975190: `DAT_141b5a298` (the accept callback) -> 0x1409752a0, Cancel -> 0x140975370,
  PlaySound.
- The accept 0x1409752a0: unless a hide is already queued for it (`InterfaceStrings+0x138`), the
  menu's sound, then the player sleeps (0x140741370, after a message box request 0x14098dd00 with
  `DAT_1420bb900`) or waits (0x1407414c0) for the slider's hours (the argument), marks itself
  running (`menu+0x51`) and zeroes its timer (`menu+0x30`).
- ProcessMessage 0x140974e00: kUpdate while running (`menu+0x51`) and the root is a display object:
  the timer accumulates the frame time `DAT_143275608`; each second it reads `getSliderValue` and
  the player's remaining hours (`player+0x8f4`, in game minutes: (m + 3599) / 3600); at 0 hours it
  stops, hides itself (message 3 to `+0x138`) and tells 0x140975900 whether it slept; while hours
  remain and are fewer than the slider's, `modifySliderValue(-1.0)` and 0x140975470. kShow: the
  payload's bool is sleeping (`menu+0x50`), Invoke "SetSleeping"(bool), 0x140665f80. kHide: if it
  ran, 0x140741580 (end sleep/wait) and the sound at `+0x200`; if it slept and the HUD is open
  (`+0xc0`) and no `+0x128` menu (the LevelUp menu) is open, a message box 0x14098dd00 with
  `DAT_1420bb900`; 0x1409354b0.

### HUDMenu (vtable 0x141976708)

- Accept 0x140934cc0: PlaySound, RegisterHUDComponents -> 0x140934e20, GetButtonFromUserEvent ->
  0x140991e30, myLog -> 0x140934f80.
- ProcessMessage 0x140933180 (the pseudocode is 28k characters; only the Invoke names and the
  message types were read): kHide 0x14075adf0 / 0x140687cd0; kScaleformEvent handles "Swimming"
  and the crosshair; the HUD's own data types (the `HUDData` kinds, a switch on the data's kind):
  1 "ShowMessage", 3 "SetCrosshairTarget" (with the activate text built by 0x1402289c0 /
  0x140228290 / 0x140227ef0 and the owner check 0x140739610 / 0x140739980), 4 "SetLoadDoorInfo",
  5 "ShowSubtitle", 6 "HideSubtitle", 7 "ShowArrowCount", 9 "SetSubtitlesEnabled", 0x17
  "ShowElements", 0x1b push/pop the "Favor" control layer, 0x1c "ValidateCrosshair" with "Alert"
  or "Normal", 0x1d "SetLocationName", 0x1e "ShowTutorialHintText", 0x1f "SetCrosshairEnabled",
  0x20 the compass markers (0x140d02350, 0x140cf5500, 0x140cf7330), 0x21
  "RefreshActivateButtonArt" (the Activate control's art, 0x140992020), 0x22 the tutorial
  messages (`MessagesInstance`, `MessageArray`, `ShownMessageArray` members; the control layers
  "HUDModes", "HorseMode", "WarHorseMode", "MovementDisabled"), 0x23 the survival meters
  (`aTemperatureLevel`, `aColdPenaltyPercent`, `aHungerPenaltyPercent`,
  `aExhaustionPenaltyPercent`, "ShowSurvivalElements").

### GiftMenu (vtable 0x141975538)

- Accept 0x14092f6b0: PlaySound, UpdateItem3D -> 0x14092f9b0, RequestItemCardInfo -> 0x14092fa10,
  CloseMenu -> 0x14092fb00, ItemSelect -> 0x14092fb30, DisabledItemSelect -> 0x14092fd70,
  StartMouseRotation, StopMouseRotation, ZoomItemModel -> 0x14092fd90, QuantitySliderOpen ->
  0x14092ff80. ProcessMessage 0x14092ed20 not read.

### The others

Console (vtable 0x141970a80, Accept 0x140909ad0, ProcessMessage 0x1409092d0), MainMenu
(0x14197b570, 0x140958690, 0x140959f90), LoadingMenu (0x141978d40, 0x14094b5b0, 0x14094b680),
FaderMenu (0x141974c00, 0x14092bfb0, 0x14092be70), CursorMenu (0x141974588, no Accept,
0x14092a070), StatsMenu (0x141980128, 0x140978020, 0x140976a50), LevelUpMenu (0x1419788b0,
0x14094aa80, base ProcessMessage), TrainingMenu (0x141981158, 0x140985670, 0x140985740),
LockpickingMenu (0x141979a10, no Accept, 0x14094d350), TutorialMenu (0x141981508, 0x140987140,
0x140986d40), BookMenu (0x14196fd90, no Accept, 0x1409063d0): not read.

## The item lists (`ItemList`, `StandardItemData`, `ItemCard`)

An item menu's `ItemList` (0x58 bytes at `menu+0x48` in the inventory, `+0x30` in the barter and
magic menus) holds the movie, the `_root.GetInventoryItemList` value and its `entryList` array.
Each entry is a `StandardItemData` (vtable 0x14196f3c8) made by 0x140903e60: it asks the entry's
source for its GFxValue (slot 0x68 of the data source), then sets the members `text` (slot 1 of the
item data), `count` (slot 2), `equipState` (slot 3), `filterFlag` (slot 4), `favorite` (slot 5)
and `enabled` (slot 6). The magic menu's `MagicItemData` adds `soulLVL` (0x140940e50, for a soul
gem of form type 0x34 SLGM with a soul: the level name through 0x14028ef00). The `ItemCard`
(0x40 bytes, ctor 0x140947110: the movie's value through slot 0x68 and a 0x801-byte text buffer)
is filled by 0x1409472c0 (5167 bytes, not read in full), which sets `spellCost`, `potionType`,
`effects`, `weight`, `value`, `damage`, `armor` and `bestInClass` on the card's data; its field
names are the strings at 0x141978580..0x141978680.

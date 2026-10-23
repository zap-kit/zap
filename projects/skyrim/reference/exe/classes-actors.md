# Actors and the player (55 classes, 1 template classes left out)

From the MSVC RTTI of `SkyrimSE.exe`: 7,831 type descriptors (`.?AV...@@` in `.data`), 8,457 complete object locators and 7,159 classes with a vtable in `.rdata`. Here the classes of the inn's systems with their primary vtable (the one at offset 0 of the object) and how many virtual functions follow it before the next vtable (the count includes the slots of the base classes; a class's own slots come last). A secondary vtable (a base at another offset) is listed with that offset. Template classes (`BSTEventSink<...>`, `ConcreteFormFactory<...>`, the behavior tree's `CombatBehaviorTreeNodeObject<...>`) are left out; their count is in the system's heading. The vtable's slot k holds the address of the virtual function, so a function is found as the vtable's address plus 8 k, and `procedure_pseudo_code` on that address gives its code.

The layouts to read a slot by name: CommonLibSSE-NG's headers declare each class's virtual functions in vtable order (`IMenu`: 0 destructor, 1 Accept(CallbackProcessor), 2 PostCreate, 3 Unk_03, 4 ProcessMessage(UIMessage), 5 AdvanceMovie(interval, currentTime), 6 PostDisplay, 7 PreDisplay, 8 RefreshPlatform).

| class | vtable | slots | other vtables (offset: address, slots) |
|---|---|---|---|
| ActivateHandler | 0x141935388 | 9 |  |
| ActiveEffect | 0x1418f5b98 | 25 |  |
| ActiveEffect::ForEachHitEffectVisitor | 0x1418f5b80 | 2 |  |
| ActiveEffectReferenceEffectController | 0x1418f5a60 | 35 |  |
| Actor | 0x14191b548 | 296 | 32: 0x14191be90, 2, 48: 0x14191bea8, 2, 56: 0x14191bec0, 19, 160: 0x14191bf60, 12, 184: 0x14191bfc8, 9, 192: 0x14191c018, 22, 208: 0x14191c0d0, 2, 216: 0x14191c0e8, 2, 224: 0x14191c100, 2 |
| ActorMagicCaster | 0x1418f6150 | 30 | 72: 0x1418f6248, 20, 96: 0x1418f62f0, 2 |
| ActorMover | 0x14192e3d8 | 4 |  |
| ActorValueInfo | 0x1418c2708 | 59 | 32: 0x1418c28e8, 6, 48: 0x1418c2920, 4, 64: 0x1418c2948, 7 |
| ActorValueOwner | 0x14185e6d0 | 9 |  |
| AttackBlockHandler | 0x141935258 | 9 |  |
| AutoMoveHandler | 0x1419353d8 | 7 |  |
| BGSHeadPart | 0x1418554a8 | 59 | 32: 0x141855688, 6, 48: 0x1418556c0, 7 |
| Character | 0x141923258 | 298 | 32: 0x141923bb0, 2, 48: 0x141923bc8, 2, 56: 0x141923be0, 19, 160: 0x141923c80, 12, 184: 0x141923ce8, 9, 192: 0x141923d38, 22, 208: 0x141923df0, 2, 216: 0x141923e08, 2, 224: 0x141923e20, 2 |
| EffectSetting | 0x1417e1468 | 59 | 32: 0x1417e1648, 6, 48: 0x1417e1680, 5, 64: 0x1417e16b0, 6 |
| EffectSettingCollection | 0x1417e1850 | 1 |  |
| EnchantmentItem | 0x1417e1aa0 | 113 | 48: 0x1417e1e30, 6, 64: 0x1417e1e68, 6 |
| FirstPersonState | 0x14196d8f0 | 9 | 32: 0x14196d940, 7 |
| JumpHandler | 0x1419354a8 | 7 |  |
| LookHandler | 0x141935150 | 7 |  |
| MagicCaster | 0x1418f8780 | 29 |  |
| MagicCaster::PostCreationCallback | 0x1418f8768 | 2 |  |
| MagicItem | 0x1417e2ea0 | 113 | 48: 0x1417e3230, 6, 64: 0x1417e3268, 6 |
| MagicItem::PreloadableVisitor | 0x1417e2e88 | 2 |  |
| MagicItemFindFunctor | 0x1417e32b8 | 3 |  |
| MagicItemFindKeywordFunctor | 0x1417e32d8 | 3 |  |
| MagicItemTraversalFunctor | 0x1417e32a0 | 2 |  |
| MagicTarget | 0x1417e9940 | 12 |  |
| MagicTarget::DispelFromBoundObject | 0x1418f8d30 | 2 |  |
| MagicTarget::ForEachActiveEffectVisitor | 0x141840138 | 2 |  |
| MagicTarget::IPostCreationModification | 0x1418f6660 | 2 |  |
| MovementHandler | 0x1419351c8 | 7 |  |
| PlayerCamera | 0x14196d980 | 3 |  |
| PlayerCameraTransitionState | 0x14196db20 | 9 |  |
| PlayerCharacter | 0x1419296c0 | 303 | 32: 0x14192a040, 2, 48: 0x14192a058, 2, 56: 0x14192a070, 19, 160: 0x14192a110, 12, 184: 0x14192a178, 9, 192: 0x14192a1c8, 22, 208: 0x14192a280, 2, 216: 0x14192a298, 2, 224: 0x14192a2b0, 2, 696: 0x14192a2c8, 2, 704: 0x14192a2e0, 2, 712: 0x14192a2f8, 2, 720: 0x14192a310, 2, 728: 0x14192a328, 2 |
| PlayerControls | 0x141935070 | 2 | 8: 0x141935088, 2, 16: 0x1419350a0, 2, 24: 0x1419350b8, 2 |
| PlayerInputHandler | 0x1418ecbc8 | 7 |  |
| ReadyWeaponHandler | 0x141935348 | 7 |  |
| RunHandler | 0x141935458 | 9 |  |
| ShoutHandler | 0x141935528 | 7 |  |
| SneakHandler | 0x1419354e8 | 7 |  |
| SpellItem | 0x1417e5a08 | 113 | 48: 0x1417e5d98, 6, 64: 0x1417e5dd0, 6, 144: 0x1417e5e08, 6, 160: 0x1417e5e40, 5, 176: 0x1417e5e70, 4 |
| SprintHandler | 0x141935208 | 9 |  |
| TESActorBase | 0x14185e720 | 87 | 48: 0x14185e9e0, 9, 136: 0x14185ea30, 4, 160: 0x14185ea58, 4, 176: 0x14185ea80, 4, 216: 0x14185eaa8, 6, 232: 0x14185eae0, 9, 240: 0x14185eb30, 4, 256: 0x14185eb58, 4, 272: 0x14185eb80, 6, 296: 0x14185ebb8, 4, 312: 0x14185ebe0, 4 |
| TESActorBaseData | 0x1417f8b98 | 9 |  |
| TESCamera | 0x1418ebbe0 | 3 |  |
| TESCameraState | 0x141806460 | 9 |  |
| TESForm | 0x1417f9f80 | 59 |  |
| TESNPC | 0x14185ec20 | 87 | 48: 0x14185eee0, 9, 136: 0x14185ef30, 4, 160: 0x14185ef58, 4, 176: 0x14185ef80, 4, 216: 0x14185efa8, 6, 232: 0x14185efe0, 9, 240: 0x14185f030, 4, 256: 0x14185f058, 4, 272: 0x14185f080, 6, 296: 0x14185f0b8, 4, 312: 0x14185f0e0, 4, 336: 0x14185f108, 4, 352: 0x14185f130, 4, 392: 0x14185f158, 2 |
| TESObjectREFR | 0x1418277c0 | 162 | 32: 0x141827cd8, 2, 48: 0x141827cf0, 2, 56: 0x141827d08, 19 |
| TESRace | 0x141861d68 | 59 | 32: 0x141861f48, 6, 48: 0x141861f80, 4, 64: 0x141861fa8, 4, 80: 0x141861fd0, 4, 96: 0x141861ff8, 4, 112: 0x141862020, 6, 136: 0x141862058, 4 |
| TESShout | 0x141851e50 | 59 | 32: 0x141852030, 6, 48: 0x141852068, 5, 64: 0x141852098, 6, 80: 0x1418520d0, 4 |
| TESWordOfPower | 0x141852700 | 59 | 32: 0x1418528e0, 6 |
| ThirdPersonState | 0x1418ecc08 | 16 | 32: 0x1418ecc90, 7 |
| TogglePOVHandler | 0x141935568 | 9 |  |
| ToggleRunHandler | 0x141935418 | 7 |  |

# Items and inventory (39 classes, 5 template classes left out)

From the MSVC RTTI of `SkyrimSE.exe`: 7,831 type descriptors (`.?AV...@@` in `.data`), 8,457 complete object locators and 7,159 classes with a vtable in `.rdata`. Here the classes of the inn's systems with their primary vtable (the one at offset 0 of the object) and how many virtual functions follow it before the next vtable (the count includes the slots of the base classes; a class's own slots come last). A secondary vtable (a base at another offset) is listed with that offset. Template classes (`BSTEventSink<...>`, `ConcreteFormFactory<...>`, the behavior tree's `CombatBehaviorTreeNodeObject<...>`) are left out; their count is in the system's heading. The vtable's slot k holds the address of the virtual function, so a function is found as the vtable's address plus 8 k, and `procedure_pseudo_code` on that address gives its code.

The layouts to read a slot by name: CommonLibSSE-NG's headers declare each class's virtual functions in vtable order (`IMenu`: 0 destructor, 1 Accept(CallbackProcessor), 2 PostCreate, 3 Unk_03, 4 ProcessMessage(UIMessage), 5 AdvanceMovie(interval, currentTime), 6 PostDisplay, 7 PreDisplay, 8 RefreshPlatform).

| class | vtable | slots | other vtables (offset: address, slots) |
|---|---|---|---|
| AlchemyItem | 0x1417df570 | 113 | 48: 0x1417df900, 6, 64: 0x1417df938, 6, 144: 0x1417df970, 7, 200: 0x1417df9b0, 7, 216: 0x1417df9f0, 4, 240: 0x1417dfa18, 4, 256: 0x1417dfa40, 6, 272: 0x1417dfa78, 4, 288: 0x1417dfaa0, 4 |
| BGSEquipSlot | 0x141854f98 | 59 |  |
| BGSEquipType | 0x1417f7d20 | 6 |  |
| BGSOutfit | 0x14180e338 | 59 |  |
| ExtraCharge | 0x1417e9c18 | 3 |  |
| ExtraContainerChanges | 0x1417ed310 | 3 |  |
| ExtraCount | 0x1417e9b38 | 3 |  |
| ExtraEnchantment | 0x1417e9fd8 | 3 |  |
| ExtraHealth | 0x1417e9bb8 | 3 |  |
| ExtraHealthPerc | 0x1417e9bd8 | 3 |  |
| ExtraHotkey | 0x1417e9c78 | 3 |  |
| ExtraLeveledItem | 0x1417e9d18 | 3 |  |
| ExtraLeveledItemBase | 0x1417e9e78 | 3 |  |
| ExtraOwnership | 0x1417e9ad8 | 3 |  |
| ExtraPoison | 0x1417e9fb8 | 3 |  |
| ExtraReferenceHandle | 0x1417e9cb8 | 3 |  |
| ExtraTextDisplayData | 0x1417ea638 | 3 |  |
| ExtraWorn | 0x1417e9b58 | 3 |  |
| ExtraWornLeft | 0x1417e9b78 | 3 |  |
| IngredientItem | 0x1417e22d0 | 113 | 48: 0x1417e2660, 6, 64: 0x1417e2698, 6, 144: 0x1417e26d0, 7, 200: 0x1417e2710, 7, 216: 0x1417e2750, 4, 232: 0x1417e2778, 6, 248: 0x1417e27b0, 4, 264: 0x1417e27d8, 4, 288: 0x1417e2800, 4 |
| Inventory3DManager | 0x1419778d8 | 8 |  |
| Inventory::StatInventoryVisitor | 0x141805930 | 4 |  |
| InventoryChanges::FindBestSoulGemVisitor | 0x14191dec0 | 4 |  |
| InventoryChanges::IItemChangeVisitor | 0x141805898 | 4 |  |
| InventoryUpdateData | 0x141984978 | 1 |  |
| InventoryUtils::ItemFilter | 0x141805880 | 2 |  |
| InventoryUtils::QuestItemFilter | 0x14180bfd0 | 2 |  |
| ScrollItem | 0x1417e52b0 | 113 | 48: 0x1417e5640, 6, 64: 0x1417e5678, 6, 144: 0x1417e56b0, 6, 160: 0x1417e56e8, 5, 176: 0x1417e5718, 4, 232: 0x1417e5740, 7, 288: 0x1417e5780, 4, 304: 0x1417e57a8, 4, 328: 0x1417e57d0, 4, 344: 0x1417e57f8, 4 |
| TESAmmo | 0x14180fc30 | 83 | 48: 0x14180fed0, 6, 64: 0x14180ff08, 7, 120: 0x14180ff48, 7, 136: 0x14180ff88, 4, 160: 0x14180ffb0, 4, 176: 0x14180ffd8, 4, 192: 0x141810000, 4, 208: 0x141810028, 4, 232: 0x141810050, 4, 248: 0x141810078, 6 |
| TESContainer | 0x1417f92a8 | 4 |  |
| TESKey | 0x1418123f0 | 86 | 48: 0x1418126a8, 6, 64: 0x1418126e0, 7, 120: 0x141812720, 7, 136: 0x141812760, 4, 152: 0x141812788, 4, 168: 0x1418127b0, 4, 184: 0x1418127d8, 4, 208: 0x141812800, 4, 232: 0x141812828, 6 |
| TESLevItem | 0x141813018 | 83 | 48: 0x1418132b8, 8 |
| TESLeveledList | 0x1417faaa8 | 8 |  |
| TESObjectARMO | 0x141816580 | 83 | 48: 0x141816820, 6, 64: 0x141816858, 4, 80: 0x141816880, 5, 104: 0x1418168b0, 4, 120: 0x1418168d8, 4, 136: 0x141816900, 4, 152: 0x141816928, 4, 176: 0x141816950, 4, 416: 0x141816978, 6, 432: 0x1418169b0, 4, 448: 0x1418169d8, 4, 472: 0x141816a00, 6, 496: 0x141816a38, 4 |
| TESObjectBOOK | 0x141816de0 | 83 | 48: 0x141817080, 6, 64: 0x1418170b8, 7, 120: 0x1418170f8, 7, 136: 0x141817138, 4, 152: 0x141817160, 4, 168: 0x141817188, 4, 184: 0x1418171b0, 4, 200: 0x1418171d8, 4, 224: 0x141817200, 4, 248: 0x141817228, 6 |
| TESObjectLIGH | 0x1418140f0 | 83 | 48: 0x141814390, 6, 64: 0x1418143c8, 7, 120: 0x141814408, 7, 136: 0x141814448, 4, 160: 0x141814470, 4, 176: 0x141814498, 4, 192: 0x1418144c0, 4, 208: 0x1418144e8, 6 |
| TESObjectMISC | 0x141818860 | 86 | 48: 0x141818b18, 6, 64: 0x141818b50, 7, 120: 0x141818b90, 7, 136: 0x141818bd0, 4, 152: 0x141818bf8, 4, 168: 0x141818c20, 4, 184: 0x141818c48, 4, 208: 0x141818c70, 4, 232: 0x141818c98, 6 |
| TESObjectWEAP | 0x14181a620 | 83 | 48: 0x14181a8c0, 6, 64: 0x14181a8f8, 7, 120: 0x14181a938, 7, 136: 0x14181a978, 5, 160: 0x14181a9a8, 4, 176: 0x14181a9d0, 4, 192: 0x14181a9f8, 5, 208: 0x14181aa28, 4, 224: 0x14181aa50, 6, 240: 0x14181aa88, 5, 248: 0x14181aab8, 4, 272: 0x14181aae0, 4, 296: 0x14181ab08, 4, 320: 0x14181ab30, 6, 344: 0x14181ab68, 4 |
| TESSoulGem | 0x14181b240 | 86 | 48: 0x14181b4f8, 6, 64: 0x14181b530, 7, 120: 0x14181b570, 7, 136: 0x14181b5b0, 4, 152: 0x14181b5d8, 4, 168: 0x14181b600, 4, 184: 0x14181b628, 4, 208: 0x14181b650, 4, 232: 0x14181b678, 6 |

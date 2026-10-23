# Menus and the UI (100 classes, 0 template classes left out)

From the MSVC RTTI of `SkyrimSE.exe`: 7,831 type descriptors (`.?AV...@@` in `.data`), 8,457 complete object locators and 7,159 classes with a vtable in `.rdata`. Here the classes of the inn's systems with their primary vtable (the one at offset 0 of the object) and how many virtual functions follow it before the next vtable (the count includes the slots of the base classes; a class's own slots come last). A secondary vtable (a base at another offset) is listed with that offset. Template classes (`BSTEventSink<...>`, `ConcreteFormFactory<...>`, the behavior tree's `CombatBehaviorTreeNodeObject<...>`) are left out; their count is in the system's heading. The vtable's slot k holds the address of the virtual function, so a function is found as the vtable's address plus 8 k, and `procedure_pseudo_code` on that address gives its code.

The layouts to read a slot by name: CommonLibSSE-NG's headers declare each class's virtual functions in vtable order (`IMenu`: 0 destructor, 1 Accept(CallbackProcessor), 2 PostCreate, 3 Unk_03, 4 ProcessMessage(UIMessage), 5 AdvanceMovie(interval, currentTime), 6 PostDisplay, 7 PreDisplay, 8 RefreshPlatform).

| class | vtable | slots | other vtables (offset: address, slots) |
|---|---|---|---|
| BSImagespaceShaderISLightingCompositeMenu | 0x141b3aa48 | 15 | 16: 0x141b3aac8, 2, 24: 0x141b3aae0, 1, 144: 0x141b3aaf0, 10 |
| BSScaleformFileOpener | 0x141a9b450 | 4 |  |
| BSScaleformImageLoader | 0x141a9af88 | 2 |  |
| BSScaleformMovieLoadTask | 0x141a9c860 | 107 |  |
| BSScaleformTranslator | 0x141a9aa10 | 4 |  |
| BSUIMessageData | 0x141915648 | 1 |  |
| BSUIScaleformData | 0x141a998a0 | 1 |  |
| BarterMenu | 0x14196f408 | 9 |  |
| BookMenu | 0x14196fd90 | 9 | 48: 0x14196fde0, 20, 72: 0x14196fe88, 2 |
| ConsoleNativeUIMenu | 0x1419711d8 | 9 |  |
| ContainerMenu | 0x141971a90 | 9 |  |
| ContentMenu | 0x1418eec08 | 1 |  |
| CraftingMenu | 0x141973868 | 9 |  |
| CraftingSubMenus::AlchemyMenu | 0x141973ff8 | 8 | 16: 0x141974040, 2 |
| CraftingSubMenus::ConstructibleObjectMenu | 0x141973a60 | 8 | 16: 0x141973aa8, 2 |
| CraftingSubMenus::CraftingSubMenu | 0x1419738b8 | 8 | 16: 0x141973900, 2 |
| CraftingSubMenus::EnchantConstructMenu | 0x141973df0 | 8 | 16: 0x141973e38, 2 |
| CraftingSubMenus::SmithingMenu | 0x141973c40 | 8 | 16: 0x141973c88, 2 |
| CreditsMenu | 0x141974498 | 9 | 48: 0x1419744e8, 2 |
| CursorMenu | 0x141974588 | 9 | 48: 0x1419745d8, 8 |
| DialogueMenu | 0x141974998 | 9 | 48: 0x1419749e8, 2 |
| FaderMenu | 0x141974c00 | 9 |  |
| FavoritesMenu | 0x141975188 | 9 | 48: 0x1419751d8, 8 |
| GFxExternalInterface | 0x141a9c2a8 | 2 |  |
| GFxFileOpenerBase | 0x141a9b428 | 4 |  |
| GFxFunctionHandler | 0x1418ef260 | 2 |  |
| GFxImageLoader | 0x141a9af70 | 2 |  |
| GFxLog | 0x141a9aa50 | 2 | 24: 0x141a9aa68, 2 |
| GFxState | 0x141a9a998 | 1 |  |
| GFxTranslator | 0x141a9a9a8 | 4 |  |
| GFxZlibSupport | 0x141a9a9f0 | 3 |  |
| GFxZlibSupportBase | 0x141a9a9d0 | 3 |  |
| GiftMenu | 0x141975538 | 9 |  |
| HUDChargeMeter | 0x141976890 | 5 |  |
| HUDData | 0x1419847e8 | 1 |  |
| HUDMenu | 0x141976708 | 9 | 48: 0x141976758, 2, 56: 0x141976770, 2 |
| HUDMeter | 0x1419767e8 | 6 |  |
| HUDNotifications | 0x1419767b8 | 5 |  |
| HUDObject | 0x141976788 | 5 |  |
| IMenu | 0x141a9a1f0 | 9 |  |
| InventoryMenu | 0x141978208 | 9 |  |
| JournalMenu | 0x141989d98 | 9 | 48: 0x141989de8, 8, 64: 0x141989e30, 2 |
| KinectMenu | 0x1418f4df0 | 9 | 48: 0x1418f4e40, 2 |
| LevelUpMenu | 0x1419788b0 | 9 |  |
| LoadingMenu | 0x141978d40 | 9 |  |
| LockpickingMenu | 0x141979a10 | 9 | 48: 0x141979a60, 8, 64: 0x141979aa8, 2 |
| LoginMenu::loginMenu | 0x1418ef3c0 | 9 | 48: 0x1418ef410, 2 |
| MagicItemData | 0x14197a7b8 | 7 |  |
| MagicItemDataCollector | 0x1418f6308 | 2 |  |
| MagicMenu | 0x14197a7f8 | 9 |  |
| MainMenu | 0x14197b570 | 9 | 48: 0x14197b5c0, 2, 56: 0x14197b5d8, 2, 64: 0x14197b5f0, 2 |
| MapMenu | 0x141987248 | 9 | 48: 0x141987298, 2, 56: 0x1419872b0, 3 |
| MarketplaceMenu | 0x1418f0370 | 9 | 48: 0x1418f03c0, 2 |
| MenuControls | 0x14197c1e8 | 2 | 8: 0x14197c200, 2 |
| MenuEventHandler | 0x1418f02e0 | 8 |  |
| MenuOpenHandler | 0x14197c350 | 8 |  |
| MenuTopicManager | 0x1418fea40 | 2 | 8: 0x1418fea58, 2 |
| MessageBoxMenu | 0x14197c788 | 9 |  |
| MistMenu | 0x14197dda0 | 9 | 48: 0x14197ddf0, 20, 72: 0x14197de98, 8 |
| ModManagerMenu | 0x1418f4630 | 9 | 48: 0x1418f4680, 8, 64: 0x1418f46c8, 2 |
| RaceSexMenu | 0x14197edb0 | 9 | 48: 0x14197ee00, 8 |
| SafeZoneMenu | 0x14197f198 | 9 |  |
| ScaleformFile::MemoryFile | 0x141a9b4b0 | 19 |  |
| SleepWaitMenu | 0x14197f4e8 | 9 |  |
| StandardItemData | 0x14196f3c8 | 7 |  |
| StatsMenu | 0x141980128 | 9 | 48: 0x141980178, 8 |
| StreamingInstallMenu | 0x141980998 | 1 |  |
| TitleSequenceMenu | 0x141980e48 | 9 |  |
| TrainingMenu | 0x141981158 | 9 | 48: 0x1419811a8, 2 |
| TutorialMenu | 0x141981508 | 9 |  |
| TweenMenu | 0x1419818b8 | 9 |  |
| UIBlurManager | 0x1419844a0 | 2 |  |
| UISaveLoadManager | 0x141985120 | 2 | 8: 0x141985138, 2 |
| UI_Button3 | 0x141b59cc8 | 14 |  |
| UI_Dialog | 0x141b5ab68 | 15 |  |
| UI_DialogDownloadCC | 0x141b5aec8 | 15 |  |
| UI_DialogMessage | 0x141b5a1e8 | 15 |  |
| UI_DialogYesNo | 0x141b59938 | 15 |  |
| UI_MarkdownText | 0x141b5adc8 | 14 |  |
| UI_ScrollingList | 0x141b5b570 | 29 |  |
| UI_Text | 0x141b59f80 | 15 |  |
| UI_Text2 | 0x141b5abe8 | 14 |  |
| UI_Text3 | 0x141b599b8 | 15 |  |
| UI_bannerEntry | 0x141b5bcc8 | 18 |  |
| UI_bar | 0x141b5aaf0 | 14 |  |
| UI_bottomBar | 0x141b59790 | 14 |  |
| UI_button2 | 0x141b5ac60 | 14 |  |
| UI_detailsPage | 0x141b58240 | 21 |  |
| UI_detailsPage::OnSale | 0x141b583a0 | 14 |  |
| UI_element | 0x141b59808 | 14 |  |
| UI_element2 | 0x141b5ad50 | 14 |  |
| UI_homePage | 0x141b5a5a8 | 21 |  |
| UI_image | 0x141b5a000 | 14 |  |
| UI_image2 | 0x141b5acd8 | 14 |  |
| UI_image3 | 0x141b59880 | 14 |  |
| UI_listEntry | 0x141b5bb88 | 18 |  |
| UI_listEntry::OnSale | 0x141b5bb10 | 14 |  |
| UI_page | 0x141b59d88 | 21 |  |
| UI_tag | 0x141b5b998 | 14 |  |
| UI_topBar | 0x141b5b818 | 14 |  |

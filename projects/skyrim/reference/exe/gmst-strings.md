# Game settings: the strings (s*)

The value compiled into `SkyrimSE.exe` for each game setting (GMST) it knows: what the game uses when `Skyrim.esm` has no record of that name (the plugin's record wins). `game/sim/settings.zap` keeps the few the port reads; this is the whole table.

Read from the static `SettingT<GameSettingCollection>` objects in `.data` (24 bytes: the vtable, the value, the pointer to the name; the vtable's RTTI names the class), found by scanning `.data` for pointers to names and checked against REA's `read_bytes` at 0x1420d9078 (fShadowBiasScale:Display). The address is the object's; the value is decoded by the name's type letter (f float, i int, u unsigned, b bool, s string, r and a 32-bit colors).

| address | setting | value |
|---|---|---|
| 0x1420b61d0 | sAbortText | "Abort" |
| 0x1420abcd0 | sAccept | "Accept" |
| 0x1420ae4c0 | sActionMapping | "Action Mapping" |
| 0x1420b0bc0 | sActionPointsAttack | "Attack" |
| 0x1420b0bf0 | sActionPointsCrouch | "Crouch" |
| 0x1420b0c50 | sActionPointsHeal | "Heal" |
| 0x1420b0ba8 | sActionPointsPunch | "Punch" |
| 0x1420b0bd8 | sActionPointsReload | "Reload" |
| 0x1420b0c08 | sActionPointsStand | "Stand" |
| 0x1420b0c20 | sActionPointsSwitchWeapon | "Switch Weapon" |
| 0x1420b0c38 | sActionPointsToggleWeaponDrawn | "Toggle Weapon Drawn" |
| 0x1420aed60 | sActivate | "Activate" |
| 0x1420a6a80 | sActivateCreatureCalmed | "The creature is calmed and cannot respond." |
| 0x1420a6a68 | sActivateNPCCalmed | "is calmed and cannot respond." |
| 0x1420af7e0 | sActivationChoiceMessage | "What would you like to do?" |
| 0x1420ad800 | sActiveEffects | "ACTIVE EFFECTS" |
| 0x1420ad608 | sActiveMineDescription | "Live" |
| 0x1420ac810 | sActorFade | "Actor Fade" |
| 0x1420b0158 | sAdd | "Add" |
| 0x1420af9c0 | sAddCrimeGold | "crimegold added to" |
| 0x1420ac8d0 | sAddedEffects | "Added Effects" |
| 0x1420ada58 | sAddedNote | "Note Added: %s" |
| 0x1420abe80 | sAddItemtoInventory | "Added" |
| 0x1420ac150 | sAddItemtoSpellList | "added" |
| 0x1420ad320 | sAllegiance | "Allegiance" |
| 0x1420ad680 | sAllItems | "ALL" |
| 0x1420af4f8 | sAlreadyKnown | "You already know" |
| 0x1420ad620 | sAlreadyPlacedMine | "An active mine has already been placed on this enemy." |
| 0x1420ad770 | sAlteration | "ALTERATION" |
| 0x1420ae568 | sAmber | "AMBER" |
| 0x1420aca08 | sAnimationCanNotEquipArmor | "You cannot change armor while attacking." |
| 0x1420ac9f0 | sAnimationCanNotEquipWeapon | "You cannot change weapons while attacking." |
| 0x1420ac060 | sAnimationCanNotUnequip | "You cannot change weapons while attacking." |
| 0x1420ad6b0 | sApparel | "APPAREL" |
| 0x1420790e8 | sApprenticeDisplayName | "Apprentice" |
| 0x1420ac918 | sAreaText | "Area" |
| 0x1420afea0 | sArmor | "ARMOR" |
| 0x1420afe70 | sArmorEnchantments | "ARMOR ENCHANTMENTS" |
| 0x1420afd68 | sArmorRating | "Armor Rating" |
| 0x1420afd98 | sArmorSmithing | "Armor Smithing" |
| 0x14207af88 | sArmorWeightHeavy | "Heavy" |
| 0x14207af70 | sArmorWeightLight | "Light" |
| 0x14207afa0 | sArmorWeightNone | "None" |
| 0x1420aee08 | sAttack | "Attack" |
| 0x1420af888 | sAttributeDamaged | "has been damaged" |
| 0x1420af8a0 | sAttributeDrained | "is being drained" |
| 0x1420abfb8 | sAttributesCount | "Distribute %d Point" |
| 0x1420abf70 | sAttributesTitle | "ATTRIBUTES: %d/%d Points Assigned" |
| 0x1420ac510 | sAutoLoading | "Autoloading..." |
| 0x1420ae520 | sAutosaveAbbrev | "AUTO" |
| 0x1420ac210 | sAutoSaveDisabledDueToLackOfSpace | "Save location full. Disabling Autosave." |
| 0x1420ac4f8 | sAutoSaving | "Autosaving..." |
| 0x1420af5d0 | sAutoSavingLong | "Saving content. Please don't turn off your console." |
| 0x1420abd00 | sBack | "Back" |
| 0x1420aecd0 | sBleedingOutMessage | "You are bleeding out!" |
| 0x1420a66a8 | sBloodParticleDefault | "Effects\\BloodSpray.nif" |
| 0x1420a6708 | sBloodParticleMeleeDefault | "Effects\\ImpactMeleeBloodSpray01.nif" |
| 0x1420a6de0 | sBloodSplatterAlpha01OPTFilename | "Textures\\Gore\\ScreenBloodAlpha01OPT.dds" |
| 0x1420a6df8 | sBloodSplatterColor01OPTFilename | "Textures\\Gore\\ScreenBloodColor01OPT.dds" |
| 0x1420a6e10 | sBloodSplatterFlare01Filename | "Textures\\Effects\\FXBloodFlare.dds" |
| 0x1420a66f0 | sBloodTextureDefault | "Effects\\blooddecal.dds" |
| 0x1420ad728 | sBooks | "BOOKS" |
| 0x1420ad380 | sBounty | "Bounty" |
| 0x1420af4c8 | sBountyStatString | "%s Bounty" |
| 0x1420ae310 | sBrightness | "Brightness" |
| 0x1420add70 | sBroken | "[Locked - Broken]" |
| 0x1420ace40 | sButton | "Button" |
| 0x1420ace70 | sButtonLocked | "That button cannot be remapped" |
| 0x1420ae370 | sCameraPitch | "Invert Y" |
| 0x1420b3c40 | sCameraShakeFilename_G | "%s\\Actors\\Character\\CameraShake.nif" |
| 0x1420abcb8 | sCancel | "Cancel" |
| 0x1420bb230 | sCannotCastShout | "You can't shout right now." |
| 0x1420aca38 | sCanNotEquipWornEnchantment | "You cannot equip this item right now." |
| 0x1420aca20 | sCanNotReadBook | "You cannot read a book while in combat." |
| 0x1420ae760 | sCanNotTrainAnymore | "You have reached your training limit for your current level." |
| 0x1420ae778 | sCanNotTrainHigher | "This NPC cannot help you train any higher." |
| 0x1420ace10 | sCantChangeResolution | "You must close your current game to change resolutions." |
| 0x1420ac0c0 | sCantEquipBrokenItem | "Broken items cannot be equipped until they have been repaired." |
| 0x1420ac030 | sCantEquipGeneric | "You cannot equip this item." |
| 0x1420ac048 | sCantEquipPowerArmor | "Power armor training is required to equip this item." |
| 0x1420aecb8 | sCantHotkeyItem | "You cannot favorite that item." |
| 0x1420ae8f8 | sCantInstallModDependency | "This mod cannot be installed since it depends on files that aren't present." |
| 0x1420ae910 | sCantInstallModInvalid | "This mod cannot be activated and should be deleted." |
| 0x1420ae688 | sCantLoadControls | "Unable to load controls. Defaults will be used." |
| 0x1420ae670 | sCantLoadSettings | "Unable to load settings. Defaults will be used." |
| 0x1420ac4c8 | sCantQuickLoad | "You can't Quickload while the game is paused." |
| 0x1420ac4b0 | sCantQuickSave | "You can't Quicksave while the game is paused." |
| 0x1420ac0f0 | sCantRemoveWornItem | "Unable to remove the worn item." |
| 0x1420af288 | sCantRepairPastMax | "CANNOT REPAIR PAST %.0f%s" |
| 0x1420ac468 | sCantSaveNow | "You cannot save right now." |
| 0x1420ac078 | sCantUnequipGeneric | "You cannot unequip this item." |
| 0x1420ae808 | sChangedModsResetConfirm | "The mod selection / load order has changed.  The game will now reload your data files." |
| 0x1420ac858 | sChangeItemSelection | "Change Item Selection" |
| 0x1420af480 | sCharGenControlsDisabled | "Your hands are bound." |
| 0x1420ac9a8 | sChemsAddicted | "You have become addicted to %s." |
| 0x1420ac9c0 | sChemsWithdrawal | "You are suffering from %s withdrawal." |
| 0x1420ac990 | sChemsWornOff | "%s has worn off." |
| 0x1420abdc0 | sChoose | "Choose" |
| 0x1420ad530 | sChooseSoulGem | "Choose Soul Gem to Use" |
| 0x1420ad398 | sCleared | "Cleared" |
| 0x1420b00f8 | sClearSelections | "Clear Selections" |
| 0x1420aed30 | sClose | "Close" |
| 0x1420ae868 | sCloseMarketplaceMenu_Confirm | "Downloads still in progress. Are you sure you want to exit?" |
| 0x1420ae850 | sCloseModManager_Confirm | "Downloads still in progress. Are you sure you want to exit?" |
| 0x1420af0a8 | sConfirmAttribute | "Increase %s?" |
| 0x1420ae3e8 | sConfirmContinue | "Continue from your last saved game?" |
| 0x1420ae430 | sConfirmDelete | "Delete this game?" |
| 0x1420b0008 | sConfirmDisenchant | "Are you sure you want to destroy this item and learn its enchantment?" |
| 0x1420ae400 | sConfirmLoad | "Load this game?" |
| 0x1420ae3d0 | sConfirmNew | "Start a new game?" |
| 0x1420ae898 | sConfirmNewMods | "Start a new game? Mods are currently loaded. Note: Achievements are disabled." |
| 0x1420ae8b0 | sConfirmNewMods_Orbis | "Start a new game? Mods are currently loaded. Note: Trophies are disabled." |
| 0x1420ae418 | sConfirmSave | "Overwrite this game?" |
| 0x1420aefe8 | sConfirmSpendSoul | "Spend Soul?" |
| 0x1420ae448 | sConfirmWarning | "WARNING:  Any unsaved progress will be lost." |
| 0x1420ad7b8 | sConjuration | "CONJURATION" |
| 0x1420afac8 | sConstructibleMenuConfirm | "Do you want to create this item?" |
| 0x1420afa80 | sConstructibleMenuDescription | "Choose an item to create" |
| 0x1420ad560 | sContainerItemsTitle | "Inventory" |
| 0x1420aec40 | sContainerPlaceChance | "TO PLACE" |
| 0x1420aec28 | sContainerStealChance | "TO STEAL" |
| 0x1420abf40 | sContinue | "Continue" |
| 0x1420b6230 | sContinueText | "Continue Running Executable?" |
| 0x1420af8b8 | sContractedDisease | "You have contracted" |
| 0x1420ac6c0 | sControllerOption | "Turn off 360 Controller in the Controls section of the Settings menu to switch back to Keyboard/Mouse." |
| 0x1420ac600 | sCorruptContentMessage | "Some of your downloaded content is corrupt and could not be loaded." |
| 0x1420afa50 | sCraft | "Craft" |
| 0x1420afa98 | sCreate | "Create" |
| 0x1420b0098 | sCreated | "Created" |
| 0x1420ac8a0 | sCreatedPoisonNamePrefix | "Poison of " |
| 0x1420ac888 | sCreatedPotionNamePrefix | "Potion of " |
| 0x1420af6c0 | sCriticalStrike | "Critical Strike on" |
| 0x1420ac738 | sCrosshair | "Crosshair" |
| 0x1420ad2f0 | sCurrentLocation | "Current Location" |
| 0x1420addb8 | sCurrentObjective | "CURRENT OBJECTIVE" |
| 0x1420abc40 | sCursorFilename | "Interface\\Icons\\Misc\\cursor.dds" |
| 0x1420afae0 | sDaedric | "DAEDRIC" |
| 0x1420afd50 | sDamage | "Damage" |
| 0x14207a3c0 | sDayFriday | "Fredas" |
| 0x14207a360 | sDayMonday | "Morndas" |
| 0x14207a3d8 | sDaySaturday | "Loredas" |
| 0x14207a348 | sDaySunday | "Sundas" |
| 0x14207a3a8 | sDayThursday | "Turdas" |
| 0x14207a378 | sDayTuesday | "Tirdas" |
| 0x14207a390 | sDayWednesday | "Middas" |
| 0x14207b9c0 | sDefaultCellName | "Wilderness" |
| 0x14207ba50 | sDefaultCubeMap | "Cubemaps\\CaveGreenCube_e.dds" |
| 0x1420acdf8 | sDefaultMessage | "DEFAULT MESSAGE TEXT" |
| 0x14207a1e0 | sDefaultOrdSuffix | "th" |
| 0x1420ae4a8 | sDefaultPlayerName | "Player Name" |
| 0x1420ae7f0 | sDeleteAllModsConfirm | "Do you really want to delete all downloaded mods?" |
| 0x1420ae838 | sDeleteLibraryModConfirm | "Are you sure you want to delete this mod?  If this mod is not registered with Bethesda.net, it will no longer be recoverable." |
| 0x1420ae820 | sDeleteModConfirm | "Do you want to delete this mod?" |
| 0x1420ac420 | sDeleteSaveGame | "Are you sure you want to delete this save game?" |
| 0x1420ac570 | sDeleteSuccessful | "Save game deleted." |
| 0x1420ad7a0 | sDestruction | "DESTRUCTION" |
| 0x1420ae4d8 | sDevice | "Device" |
| 0x1420ac588 | sDeviceRemoved | "The save device you selected is no longer available.  You will need to select a new device the next time you save.  Until then, Autosave is disabled." |
| 0x1420ae2b0 | sDialogSubtitles | "Dialog Subtitles" |
| 0x1420ac720 | sDifficulty | "Difficulty" |
| 0x1420ae5c8 | sDisableHelp | "Disable Help" |
| 0x1420ac6d8 | sDisableXBoxController | "360 Controller" |
| 0x1420b00c8 | sDiscoveredEffects | "Discovered effects" |
| 0x1420ad548 | sDiscoveredIngredientEffectEating | "%s discovered from %s" |
| 0x1420acc78 | sDiscoveredText | "discovered" |
| 0x1420b0020 | sDisenchant | "Disenchant" |
| 0x1420a66c0 | sDismemberParticleDefault | "Gore\\BloodSprayLimb01.nif" |
| 0x1420a66d8 | sDismemberRobotParticleDefault | "Gore\\RobotLimbSpray01.nif" |
| 0x1420abdd8 | sDone | "Done" |
| 0x1420aea00 | sDownload | "Download" |
| 0x1420ad1b8 | sDownloadsAvailable | "New Content Available" |
| 0x1420ad1e8 | sDownloadsNotAvail | "No New Content Available" |
| 0x1420afaf8 | sDragon | "DRAGON" |
| 0x1420b8b20 | sDragonCrashEffectModel | "effects/dragoncrash/fxdragoncrashfurrow01.nif" |
| 0x1420aeeb0 | sDragonSoulAcquired | "Dragon Soul Acquired" |
| 0x1420afc00 | sDraugr | "DRAUGR" |
| 0x1420ac120 | sDropEquippedItemWarning | "You cannot drop an equipped item until you complete your current action." |
| 0x1420ac108 | sDropQuestItemWarning | "You cannot remove Quest Items from your Inventory." |
| 0x1420af948 | sDungeonCleared | "Dungeon Cleared!" |
| 0x1420ac900 | sDurationText | "Duration" |
| 0x1420afb10 | sDwarven | "DWARVEN" |
| 0x1420afb28 | sEbony | "EBONY" |
| 0x1420ac9d8 | sEffectAlreadyAdded | "Effect has already been added.  Edit the effect instead." |
| 0x1420aefb8 | sEffectsListDisplayHour | "hour" |
| 0x1420aef70 | sEffectsListDisplayHours | "hours" |
| 0x1420aefa0 | sEffectsListDisplayMin | "min" |
| 0x1420aef58 | sEffectsListDisplayMins | "mins" |
| 0x1420aef88 | sEffectsListDisplaySec | "sec" |
| 0x1420ad4d0 | sEffectsListDisplaySecs | "secs" |
| 0x1420acbb8 | sEffectsVolume | "Effects" |
| 0x1420afb58 | sElven | "ELVEN" |
| 0x1420ada40 | sEmpty | "Empty" |
| 0x1420ae5e0 | sEnableHelp | "Enable Help" |
| 0x1420afeb8 | sEnchanting | "Enchanting" |
| 0x1420aff00 | sEnchantment | "Enchantment" |
| 0x1420b0038 | sEnchantmentKnown | "The enchantment on this item is already known" |
| 0x1420affd8 | sEnchantmentsLearned | "You learned the %s enchantment from destroying this item." |
| 0x1420aff90 | sEnterItemName | "Enter Item Name" |
| 0x1420ad188 | sEnterName | "Enter character name." |
| 0x1420abeb0 | sEquipItemOnPlayer | "was equipped" |
| 0x1420af618 | sEssentialCharacterDown | "is unconscious." |
| 0x1420abe08 | sExit | "Exit" |
| 0x1420ae3b8 | sExitGameAffirm | "Exit Game" |
| 0x1420ae7c0 | sExpert | "Expert" |
| 0x142079118 | sExpertDisplayName | "Expert" |
| 0x1420a9cd8 | sExplosionSplashParticles | "Effects\\ExplosionSplash.NIF" |
| 0x1420aea48 | sFailedActivation | "This object cannot be activated right now." |
| 0x1420af018 | sFailShouting | "You cannot change shouts while shouting." |
| 0x1420af000 | sFailSpendSoul | "Use Dragon Souls to unlock shouts." |
| 0x1420afb70 | sFalmer | "FALMER" |
| 0x1420ad3c8 | sFastTravelConfirm | "Fast travel to %s?" |
| 0x1420af810 | sFastTravelNoTravelHealthDamage | "You can't fast travel while taking health damage" |
| 0x1420ad758 | sFavorites | "FAVORITES" |
| 0x1420ac4e0 | sFileNotFound | "File does not exist" |
| 0x1420ac678 | sFindingContentMessage | "Looking for content.  Please wait." |
| 0x14207a198 | sFirstOrdSuffix | "st" |
| 0x1420a0380 | sFirstPersonSkeleton | "Actors\\Character\\_1stPerson\\Skeleton.NIF" |
| 0x1420aec88 | sFood | "FOOD" |
| 0x1420acb88 | sFootstepsVolume | "Footstep" |
| 0x1420abd18 | sFor | "for" |
| 0x1420ace28 | sFullHealth | "You are already at full health." |
| 0x1420aeda8 | sFurnitureSleep | "Sleep" |
| 0x1420ac708 | sGamepadDisconnectedMessage | "Please connect a controller to continue." |
| 0x1420ac6f0 | sGamepadDisconnectedTitle | "Controller disconnected." |
| 0x14209cc00 | sGenderFemale | "female" |
| 0x14209cbe8 | sGenderMale | "male" |
| 0x1420ae2c8 | sGeneralSubtitles | "General Subtitles" |
| 0x1420afc60 | sGenericCraftKeywordName01 | "GADGETS" |
| 0x1420afc78 | sGenericCraftKeywordName02 | "GIZMOS" |
| 0x1420afc90 | sGenericCraftKeywordName03 | "WHOSE-ITS" |
| 0x1420afca8 | sGenericCraftKeywordName04 | "WHAT-ITS" |
| 0x1420afcc0 | sGenericCraftKeywordName05 | "THINGAMABOBS" |
| 0x1420afcd8 | sGenericCraftKeywordName06 | "KNICKS" |
| 0x1420afcf0 | sGenericCraftKeywordName07 | "KNACKS" |
| 0x1420afd08 | sGenericCraftKeywordName08 | "BITS" |
| 0x1420afd20 | sGenericCraftKeywordName09 | "BOBS" |
| 0x1420afd38 | sGenericCraftKeywordName10 | "LOST SOCKS" |
| 0x1420ae640 | sGFWLive | "LIVE" |
| 0x1420afb88 | sGlass | "GLASS" |
| 0x1420abd48 | sGold | "gold" |
| 0x1420ad230 | sGotAwayWithStealing | "got away with stealing" |
| 0x1420ae6a0 | sGrassFade | "Grass Fade" |
| 0x1420ace88 | sHairColor0 | "sHairColor0" |
| 0x1420acea0 | sHairColor1 | "sHairColor1" |
| 0x1420acf78 | sHairColor10 | "sHairColor10" |
| 0x1420acf90 | sHairColor11 | "sHairColor11" |
| 0x1420acfa8 | sHairColor12 | "sHairColor12" |
| 0x1420acfc0 | sHairColor13 | "sHairColor13" |
| 0x1420acfd8 | sHairColor14 | "sHairColor14" |
| 0x1420acff0 | sHairColor15 | "sHairColor15" |
| 0x1420aceb8 | sHairColor2 | "sHairColor2" |
| 0x1420aced0 | sHairColor3 | "sHairColor3" |
| 0x1420acee8 | sHairColor4 | "sHairColor4" |
| 0x1420acf00 | sHairColor5 | "sHairColor5" |
| 0x1420acf18 | sHairColor6 | "sHairColor6" |
| 0x1420acf30 | sHairColor7 | "sHairColor7" |
| 0x1420acf48 | sHairColor8 | "sHairColor8" |
| 0x1420acf60 | sHairColor9 | "sHairColor9" |
| 0x142079da8 | sHandToHandIcon | "Icons\\Weapons\\HandToHand.dds" |
| 0x1420aece8 | sHarvest | "Harvest" |
| 0x1420ad5c0 | sHealth | "Health" |
| 0x142077440 | sHealthDataPrefixArmo1 | "Fine" |
| 0x142077488 | sHealthDataPrefixArmo2 | "Very Fine" |
| 0x1420774d0 | sHealthDataPrefixArmo3 | "Extra Fine" |
| 0x142077518 | sHealthDataPrefixArmo4 | "Super Fine" |
| 0x142077560 | sHealthDataPrefixArmo5 | "Super Duper Fine" |
| 0x1420775a8 | sHealthDataPrefixArmo6 | "Ultra Fine" |
| 0x142077428 | sHealthDataPrefixWeap1 | "Fine" |
| 0x142077470 | sHealthDataPrefixWeap2 | "Very Fine" |
| 0x1420774b8 | sHealthDataPrefixWeap3 | "Extra Fine" |
| 0x142077500 | sHealthDataPrefixWeap4 | "Super Fine" |
| 0x142077548 | sHealthDataPrefixWeap5 | "Super Duper Fine" |
| 0x142077590 | sHealthDataPrefixWeap6 | "Ultra Fine" |
| 0x1420af588 | sHeavyArmorNoJump | "Your heavy armor prevents you from jumping." |
| 0x1420af5a0 | sHeavyArmorSink | "Your heavy armor is causing you to sink." |
| 0x1420ae490 | sHelp | "Help" |
| 0x1420afc18 | sHide | "HIDE" |
| 0x1420ad2c0 | sHigh | "High" |
| 0x1420ad308 | sHold | "Hold" |
| 0x14207a4f8 | sHolidayEmperorsBirthday | "Emperor's Birthday" |
| 0x14207a420 | sHolidayFirstPlanting | "First Planting" |
| 0x14207a4b0 | sHolidayHarvestsEnd | "Harvest's End" |
| 0x14207a438 | sHolidayJestersDay | "Jester's Day" |
| 0x14207a480 | sHolidayMerchantsFestival | "Merchant's Festival" |
| 0x14207a468 | sHolidayMidYearCelebration | "Mid Year Celebration" |
| 0x14207a3f0 | sHolidayNewLifeFestival | "New Life Festival" |
| 0x14207a528 | sHolidayNorthWindsPrayer | "North Wind's Prayer" |
| 0x14207a540 | sHolidayOldLifeFestival | "Old Life Festival" |
| 0x14207a450 | sHolidaySecondPlanting | "Second Planting" |
| 0x14207a408 | sHolidaySouthWindsPrayer | "South Wind's Prayer" |
| 0x14207a498 | sHolidaySunsRest | "Sun's Rest" |
| 0x14207a4c8 | sHolidayTalesAndTallows | "Tales and Tallows" |
| 0x14207a510 | sHolidayWarriorsFestival | "Warrior's Festival" |
| 0x14207a4e0 | sHolidayWitchesFestival | "Witches' Festival" |
| 0x1420aeee0 | sHUDArmorRating | "ARMOR RATING" |
| 0x1420ac7b0 | sHUDColor | "HUD Color" |
| 0x1420aef10 | sHUDCompleted | "Completed" |
| 0x1420aeec8 | sHUDDamage | "DAMAGE" |
| 0x1420aef28 | sHUDFailed | "Failed" |
| 0x1420ae2e0 | sHUDOpacity | "HUD Opacity" |
| 0x1420aeef8 | sHUDStarted | "Started" |
| 0x1420b6200 | sIgnoreText | "Ignore" |
| 0x1420ad788 | sIllusion | "ILLUSION" |
| 0x1420a6738 | sImpactParticleConcreteDefault | "Effects\\ImpactBallisticConcrete01.nif" |
| 0x1420a6720 | sImpactParticleMetalDefault | "Effects\\ImpactBallisticMetal01.nif" |
| 0x1420a6750 | sImpactParticleWoodDefault | "Effects\\ImpactBallisticWood01.nif" |
| 0x1420ad338 | sImperial | "IMPERIAL" |
| 0x1420ac168 | sImpossibleLock | "This lock cannot be picked. It requires a key to open." |
| 0x1420afdc8 | sImprovement | "Improvement" |
| 0x1420add58 | sInaccessible | "[INACCESSIBLE]" |
| 0x1420b0128 | sIngredient | "Ingredient" |
| 0x1420af720 | sIngredientFail | " Ingredient had no effect." |
| 0x1420ad6e0 | sIngredients | "INGREDIENTS" |
| 0x1420ae790 | sInsufficientGoldToTrain | "You have insufficient gold to train." |
| 0x1420accc0 | sInvalidPickpocket | "You cannot place items in a container while pickpocketing." |
| 0x14209cc58 | sInvalidTagString | "[...]" |
| 0x1420afbe8 | sIron | "IRON" |
| 0x1420afee8 | sItem | "Item" |
| 0x1420ac828 | sItemFade | "Item Fade" |
| 0x1420aeac0 | sItemTooExpensive | "You don't have enough gold." |
| 0x1420aeaa8 | sItemTooHeavy | "The item is too heavy to carry." |
| 0x1420afc48 | sJewelry | "JEWELRY" |
| 0x1420ae7a8 | sJourneyman | "Journeyman" |
| 0x142079100 | sJourneymanDisplayName | "Journeyman" |
| 0x1420ad638 | sJunk | "Junk" |
| 0x1420ace58 | sKeyLocked | "That key cannot be remapped" |
| 0x1420ad740 | sKeys | "KEYS" |
| 0x1420afa08 | sKinectAllyTooFarToTrade | "Your follower is too far to trade with." |
| 0x1420afa38 | sKinectCantInit | "The Kinect Sensor has failed to initialize. Voice commands have been disabled. Ensure that your Kinect Sensor is connected and updated." |
| 0x1420afa20 | sKinectNotCalibrated | "Your Kinect Sensor has not been calibrated. Voice commands have been disabled. Please use the Kinect Tuner to calibrate your Kinect Sensor." |
| 0x1420ac8b8 | sKnownEffects | "Known Effects" |
| 0x1420afe10 | sLackRequiredPerksToImprove | "You lack the required perks to improve this item" |
| 0x1420afe28 | sLackRequiredPerkToImproveMagical | "You lack the perk to improve magical items" |
| 0x1420afdf8 | sLackRequiredSkillToImprove | "You lack the required skill to improve this item" |
| 0x1420afab0 | sLackRequiredToCreate | "You lack the required components to create this item" |
| 0x1420afde0 | sLackRequiredToImprove | "You lack the required components to improve this item" |
| 0x1420abda8 | sLarge | "Large" |
| 0x1420affa8 | sLearn | "Learn" |
| 0x1420affc0 | sLearningEnchantments | "Learning Enchantments" |
| 0x1420afba0 | sLeather | "LEATHER" |
| 0x1420acd38 | sLeaveMarker | "Leave It" |
| 0x1420aebc8 | sLegendaryResetConfirm | "Are you sure you want to reset this skill?" |
| 0x1420aebe0 | sLegendaryResetSecondConfirm | "If you do this you will lose your perks and be reset to 15?" |
| 0x1420af090 | sLevelAbbrev | "Level" |
| 0x1420addd0 | sLevelProgress | "Level Progress" |
| 0x1420aee98 | sLevelUpAvailable | "Level up available." |
| 0x1420ae6d0 | sLightFade | "Light Fade" |
| 0x1420ac438 | sLoadFromMainMenu | "Are you sure you want to load this game?" |
| 0x1420ac528 | sLoading | "Loading..." |
| 0x1420af840 | sLoadingArea | "Loading area..." |
| 0x1420ac660 | sLoadingContentMessage | "Loading extra content. Please wait." |
| 0x1420ae2f8 | sLoadingLOD | "Loading distant LOD..." |
| 0x1420ae8c8 | sLoadVanillaSaveWithMods | "Mods are currently loaded. Note: Achievements are disabled.  Do you wish to continue loading this save ?" |
| 0x1420ae8e0 | sLoadVanillaSaveWithMods_Orbis | "Mods are currently loaded. Note: Trophies are disabled. Do you wish to continue loading this save ?" |
| 0x1420ac450 | sLoadWhilePlaying | "Are you sure you want to load this game?  All unsaved progress will be lost." |
| 0x1420accd8 | sLockBroken | "The lock has been broken." |
| 0x1420ada28 | sLocked | "Locked" |
| 0x142077320 | sLockLevelNameAverage | "Average" |
| 0x142077308 | sLockLevelNameEasy | "Easy" |
| 0x142077338 | sLockLevelNameHard | "Hard" |
| 0x142077368 | sLockLevelNameImpossible | "Requires Key" |
| 0x1420772f0 | sLockLevelNameVeryEasy | "Very Easy" |
| 0x142077350 | sLockLevelNameVeryHard | "Very Hard" |
| 0x1420ac180 | sLockpickInsufficientPerks | "You lack the required perk to pick this lock." |
| 0x1420ac6a8 | sLostController | "The Xbox 360 Controller has been disconnected. Click OK to use the Keyboard/Mouse, or reconnect the Xbox 360 Controller and press the A Button." |
| 0x1420ad2a8 | sLow | "Low" |
| 0x1420af6f0 | sMagnitudeIsLevelText | "Target Level" |
| 0x1420ac8e8 | sMagnitudeText | "Magnitude" |
| 0x1420acd68 | sMainMenu | "Main Menu" |
| 0x1420ad248 | sMakeDefaults | "Make these your default settings?" |
| 0x1420ad218 | sMapMarkerAdded | "Map marker added." |
| 0x1420ae7d8 | sMaster | "Master" |
| 0x142079130 | sMasterDisplayName | "Master" |
| 0x1420acb58 | sMasterVolume | "Master" |
| 0x1420abd90 | sMedium | "Medium" |
| 0x1420ac318 | sMenuDisplayAutosaveName | "Autosave" |
| 0x1420ac360 | sMenuDisplayDayString | "Day" |
| 0x1420ac330 | sMenuDisplayLevelString | "Level" |
| 0x1420ac2e8 | sMenuDisplayNewSave | "New Save" |
| 0x1420ac2d0 | sMenuDisplayNoSaves | "No saved games." |
| 0x1420ac2b8 | sMenuDisplayPlayTime | "Play Time" |
| 0x1420ac300 | sMenuDisplayQuicksaveName | "Quicksave" |
| 0x1420ac2a0 | sMenuDisplaySave | "Save" |
| 0x1420ae628 | sMenuDisplayShortXBoxSaveMessage | "Saving..." |
| 0x1420ac348 | sMenuDisplayUnknownLocationString | "Unknown Location" |
| 0x1420ac288 | sMenuDisplayXBoxSaveMessage | "Saving content. Please don't turn off your console." |
| 0x1420ad710 | sMisc | "MISC" |
| 0x1420af708 | sMiscConstantEffect | "Constant Effect" |
| 0x1420acc48 | sMiscPlayerDeadLoadOption | "Reload" |
| 0x1420acc60 | sMiscPlayerDeadMenuOption | "Main Menu" |
| 0x1420acc30 | sMiscPlayerDeadMessage | "Reloading the most recent save game" |
| 0x1420aea30 | sMiscQuestDescription | "Miscellaneous quests!" |
| 0x1420aea18 | sMiscQuestName | "Miscellaneous" |
| 0x1420acc00 | sMiscUnknownEffect | "(Unknown Effect)" |
| 0x1420acdb0 | sMissingImage | "Data\\Textures\\Interface\\Shared\\missing_image.dds" |
| 0x1420acd98 | sMissingName | "<Missing Name>" |
| 0x1420af4b0 | sModdedString | "Modded" |
| 0x14207a270 | sMonthApril | "Rains Hand" |
| 0x14207a2d0 | sMonthAugust | "Last Seed" |
| 0x14207a330 | sMonthDecember | "Evening Star" |
| 0x14207a240 | sMonthFebruary | "Sun's Dawn" |
| 0x14207a228 | sMonthJanuary | "Morning Star" |
| 0x14207a2b8 | sMonthJuly | "Sun's Height" |
| 0x14207a2a0 | sMonthJune | "Mid Year" |
| 0x14207a258 | sMonthMarch | "First Seed" |
| 0x14207a288 | sMonthMay | "Second Seed" |
| 0x14207a318 | sMonthNovember | "Sun's Dusk" |
| 0x14207a300 | sMonthOctober | "Frost Fall" |
| 0x14207a2e8 | sMonthSeptember | "Heart Fire" |
| 0x1420ae328 | sMouseSensitivity | "Mouse Sensitivity" |
| 0x1420acd20 | sMoveMarker | "Move It" |
| 0x1420acd08 | sMoveMarkerQuestion | "Do you want to move your marker or remove it?" |
| 0x1420af048 | sMultipleDragonSoulCount | "%i Dragon Souls" |
| 0x1420acb70 | sMusicVolume | "Music" |
| 0x1420ad2d8 | sMustRestart | "You must exit and restart Skyrim for changes in this setting to take effect." |
| 0x1420ad590 | sName | "Name" |
| 0x1420ad368 | sNeutral | "Neutral" |
| 0x1420ae460 | sNewSave | "[NEW SAVE]" |
| 0x1420abce8 | sNext | "Next" |
| 0x1420abca0 | sNo | "No" |
| 0x1420aea60 | sNoArrows | "No arrows equipped." |
| 0x1420aea78 | sNoBolts | "No bolts equipped." |
| 0x1420ad518 | sNoChargeItems | "No items to charge enchantment" |
| 0x1420af780 | sNoChildUse | "Children cannot use that." |
| 0x1420ac5a0 | sNoDeviceSelected | "You have not selected a storage device.  You will need to select one before you can save.  Until then, Autosave is disabled." |
| 0x1420af7b0 | sNoEatQuestItem | "You can not eat quest items." |
| 0x1420af828 | sNoFastTravelAlarm | "You cannot fast travel while guards are pursuing you." |
| 0x1420acac8 | sNoFastTravelCell | "You cannot fast travel from this location." |
| 0x1420acab0 | sNoFastTravelCombat | "You cannot fast travel during combat!" |
| 0x1420aca98 | sNoFastTravelDefault | "You cannot fast travel at this time." |
| 0x1420af7f8 | sNoFastTravelHostileActorsNear | "You cannot fast travel when enemies are nearby." |
| 0x1420acb28 | sNoFastTravelInAir | "You can't fast travel while jumping or falling." |
| 0x1420acaf8 | sNoFastTravelOverencumbered | "You cannot fast travel while overencumbered." |
| 0x1420acae0 | sNoFastTravelScriptBlock | "Fast travel is currently unavaliable from this location." |
| 0x1420acb10 | sNoFastTravelUndiscovered | "You have not discovered this location yet." |
| 0x1420ad470 | sNoItemsToRepair | "No items to repair" |
| 0x1420ac018 | sNoJumpWarning | "You can not drop objects while in the air." |
| 0x1420af570 | sNoKeyDropWarning | "You cannot drop keys." |
| 0x1420af5b8 | sNoLockPickIfCrimeAlert | "You can't pick a lock while being pursued by guards." |
| 0x1420af7c8 | sNoMoreFollowers | "You have too many followers." |
| 0x1420abdf0 | sNone | "None" |
| 0x1420af768 | sNoPickPocketAgain | " has already caught you." |
| 0x1420ac648 | sNoProfileSelected | "You have not signed in to a Gamer Profile.  You will need to sign in to a Gamer Profile and then select a storage device before you can save.  Until then, Autosave is disabled." |
| 0x1420af2a0 | sNoRepairHostileActorsNear | "You cannot repair items when enemies are nearby." |
| 0x1420ad4b8 | sNoRepairInCombat | "You cannot repair items while in combat." |
| 0x1420ac5e8 | sNoRestart | "No, keep playing." |
| 0x1420ae508 | sNormal | "Normal" |
| 0x1420a6798 | sNormalWeaponsResisted | "Your attack has no effect." |
| 0x1420ae478 | sNoSaves | "[NO SAVES FOUND]" |
| 0x1420af798 | sNoSitOnOwnedFurniture | "You cannot sit on owned furniture." |
| 0x1420af378 | sNoSleepDefault | "You cannot sleep at this time." |
| 0x1420af3c0 | sNoSleepHostileActorsNear | "You cannot sleep when enemies are nearby." |
| 0x1420af3d8 | sNoSleepInAir | "You cannot sleep in the air." |
| 0x1420af3f0 | sNoSleepInCell | "You cannot sleep in this location." |
| 0x1420af438 | sNoSleepInOwnedBed | "You cannot sleep in an owned bed." |
| 0x1420af408 | sNoSleepTakingHealthDamage | "You cannot sleep while taking health damage." |
| 0x1420af390 | sNoSleepTrespass | "You cannot sleep while trespassing." |
| 0x1420af3a8 | sNoSleepWarnToLeave | "You cannot sleep while being asked to leave." |
| 0x1420af420 | sNoSleepWhileAlarm | "You cannot sleep while guards are pursuing you." |
| 0x1420ad488 | sNoSpareParts | "NO USABLE SPARE PARTS" |
| 0x1420af750 | sNoTalkFleeing | " is fleeing for their life." |
| 0x1420af738 | sNoTalkUnConscious | " is unconscious." |
| 0x1420af870 | sNotAllowedToUseAutoDoorsWhileonHorse | "Dismount Horse before going through door." |
| 0x1420ac000 | sNotEnoughRoomWarning | "You do not have enough room to drop this object." |
| 0x1420aea90 | sNotEnoughVendorGold | "Transaction value: %d gold.\nVendor only has %d gold." |
| 0x1420b61a0 | sNoText | "No" |
| 0x1420790d0 | sNoviceDisplayName | "Novice" |
| 0x1420af2b8 | sNoWaitDefault | "You cannot wait at this time." |
| 0x1420af300 | sNoWaitHostileActorsNear | "You cannot wait when enemies are nearby." |
| 0x1420af318 | sNoWaitInAir | "You cannot wait in the air." |
| 0x1420af330 | sNoWaitInCell | "You cannot wait in this location." |
| 0x1420af348 | sNoWaitTakingHealthDamage | "You cannot wait while taking health damage." |
| 0x1420af2d0 | sNoWaitTrespass | "You cannot wait while trespassing." |
| 0x1420af2e8 | sNoWaitWarnToLeave | "You cannot wait while being asked to leave." |
| 0x1420af360 | sNoWaitWhileAlarm | "You cannot wait while guards are pursuing you." |
| 0x1420ade00 | sNumberAbbrev | "No." |
| 0x1420ac840 | sObjectFade | "Object Fade" |
| 0x1420aca50 | sObjectInUse | "This object is already in use by someone else." |
| 0x1420ae700 | sObjectLODFade | "Object LOD Fade" |
| 0x1420af468 | sOf | " of " |
| 0x1420abe50 | sOff | "OFF" |
| 0x1420abc70 | sOk | "Ok" |
| 0x1420b6218 | sOKText | "OK" |
| 0x1420ad1d0 | sOldDownloadsAvailable | "View Available Content" |
| 0x1420abe38 | sOn | "ON" |
| 0x1420aed18 | sOpen | "Open" |
| 0x1420acbe8 | sOpenedContainer | "Opened the container with a key." |
| 0x1420ac1b0 | sOpenWithKey | "Unlocked with %s." |
| 0x1420b0140 | sOptional | "Optional" |
| 0x1420aef40 | sOr | "OR" |
| 0x1420afb40 | sOrcish | "ORCISH" |
| 0x1420ac198 | sOutOfLockpicks | "You are out of lockpicks." |
| 0x1420ac090 | sOverEncumbered | "You are carrying too much to be able to run." |
| 0x1420aee20 | sOwned | "Owned" |
| 0x142079180 | sParticleArrayAttachExcludeList | "Node1,Node2,Node3" |
| 0x1420ad200 | sPauseText | "Pause" |
| 0x1420b01a0 | sPCControlsTextNone | "None" |
| 0x1420b01d0 | sPCControlsTextPrefix | "Text" |
| 0x1420b01b8 | sPCControlsTriggerPrefix | "Trigger" |
| 0x1420af9a8 | sPCRelationshipNegativeChangeText | " is no longer your " |
| 0x1420af990 | sPCRelationshipPositiveChangeText | " is now your " |
| 0x1420ad278 | sPickpocket | "Pickpocket" |
| 0x1420ad650 | sPickpocketFail | "You've been caught pickpocketing." |
| 0x1420ac7c8 | sPipboyColor | "Pip-Boy Color" |
| 0x1420af0c0 | sPlaceMarker | "Place Marker" |
| 0x1420af0d8 | sPlaceMarkerUndiscovered | "You have not discovered this location yet.\nPlace marker?" |
| 0x1420aee68 | sPlayerDisarmedMessage | "You have been disarmed!" |
| 0x1420acc18 | sPlayerLeavingBorderRegion | "You cannot go that way." |
| 0x1420accf0 | sPlayerSetMarkerName | "Custom Destination" |
| 0x1420ae550 | sPlayTime | "Play Time" |
| 0x1420ae748 | sPleaseStandBy | "PLEASE STAND BY" |
| 0x1420ac1e0 | sPoisonAlreadyPoisonedMessage | "The current weapon is already poisoned." |
| 0x1420af5e8 | sPoisonBowConfirmMessage | "Do you want to poison your next shot with the " |
| 0x1420ac1f8 | sPoisonConfirmMessage | "Do you want to poison the " |
| 0x1420af8d0 | sPoisoned | "You have been poisoned." |
| 0x1420ac1c8 | sPoisonNoWeaponMessage | "You must first equip a weapon to poison it." |
| 0x1420af600 | sPoisonUnableToPoison | "Current weapon cannot be poisoned." |
| 0x1420ad6c8 | sPotions | "POTIONS" |
| 0x1420ad7e8 | sPowers | "POWERS" |
| 0x1420b01e8 | sPresenceInMenu | "In Menu" |
| 0x1420b0200 | sPresencePlayingLevel | "Level: %d" |
| 0x1420ae4f0 | sPressControl | "Press the new control for this action" |
| 0x1420ae5b0 | sPrevious | "Previous" |
| 0x1420aff30 | sPreviousSelection | "Previous Selection" |
| 0x1420af258 | sPrisoner | "Prisoner" |
| 0x14209cae0 | sPronounFemale | "she" |
| 0x14209cbd0 | sPronounIntFemale | "herself" |
| 0x14209cbb8 | sPronounIntMale | "himself" |
| 0x14209cac8 | sPronounMale | "he" |
| 0x14209cb10 | sPronounObjFemale | "her" |
| 0x14209caf8 | sPronounObjMale | "him" |
| 0x14209cb40 | sPronounPosFemale | "hers" |
| 0x14209cb28 | sPronounPosMale | "his" |
| 0x14209cb70 | sPronounPosObjFemale | "her" |
| 0x14209cb58 | sPronounPosObjMale | "his" |
| 0x14209cba0 | sPronounRefFemale | "herself" |
| 0x14209cb88 | sPronounRefMale | "himself" |
| 0x1420ad5a8 | sQuantity | "Quantity" |
| 0x1420abee0 | sQuestAddedText | "Quest added" |
| 0x1420abef8 | sQuestCompletedText | "Quest completed" |
| 0x1420abf28 | sQuestFailed | "Quest FAILED" |
| 0x1420abf10 | sQuestUpdatedText | "Quest updated" |
| 0x1420ac498 | sQuickLoading | "Quickloading..." |
| 0x1420ae538 | sQuicksaveAbbrev | "QUICK" |
| 0x1420ac480 | sQuickSaving | "Quicksaving..." |
| 0x1420b0188 | sQuitAlchemy | "Quit alchemy?" |
| 0x1420aff48 | sQuitEnchanting | "Quit enchanting?" |
| 0x1420acc90 | sRadioSignalLost | "%s signal lost." |
| 0x1420acca8 | sRadioStationDiscovered | "%s signal found." |
| 0x1420ae3a0 | sRadioVolume | "Radio" |
| 0x14207b108 | sRandomDoorTeleportFailureMessage | "This door leads nowhere." |
| 0x1420ac930 | sRangeText | "Range" |
| 0x1420af078 | sRanksText | "Ranks" |
| 0x1420aed48 | sRead | "Read" |
| 0x14207bcf0 | sRefAttachNodeName | "REF_ATTACH_NODE" |
| 0x1420aca68 | sRemoteActivation | "This object is activated from somewhere else." |
| 0x1420b0170 | sRemove | "Remove" |
| 0x1420af9f0 | sRemoveCrimeGold | "crimegold removed from" |
| 0x1420abe98 | sRemoveItemfromInventory | "Removed" |
| 0x1420acd50 | sRemoveMarker | "Remove It" |
| 0x1420aff78 | sRenameItem | "Rename Item" |
| 0x1420ad3e0 | sRepair | "REPAIR" |
| 0x1420ad458 | sRepairAllItems | "Repair All (%d)" |
| 0x1420ad428 | sRepairCost | "Cost: %d caps" |
| 0x1420ad440 | sRepairItem | "Repair" |
| 0x1420ad3f8 | sRepairServicesTitle | "Repair Services" |
| 0x1420ad410 | sRepairSkill | "Repair Skill" |
| 0x1420ad4a0 | sRepairSkillTooLow | "%d%s REPAIR SKILL NEEDED" |
| 0x1420b0218 | sReportModCat_Explicit | "Explicit Content" |
| 0x1420ae958 | sReportModCat_General | "Other" |
| 0x1420b0230 | sReportModCat_Harassment | "Harassment" |
| 0x1420b0248 | sReportModCat_Impersonation | "Impersonation of User" |
| 0x1420b0260 | sReportModCat_PrivateInfo | "Use of Private Information" |
| 0x1420b0278 | sReportModCat_Profanity | "Profanity" |
| 0x1420b0290 | sReportModCat_Racial | "Racial Discrimination" |
| 0x1420b02a8 | sReportModCat_Religious | "Religious Discrimination" |
| 0x1420b02c0 | sReportModCat_Slander | "Slander" |
| 0x1420b02d8 | sReportModCat_Spam | "Spam" |
| 0x1420ae928 | sReportModChooseCategory | "What Terms of Service violation is this mod being reported for?" |
| 0x1420ae940 | sReportModConfirm | "Report mod for explicit content, general abuse or violations of Code of Conduct/Terms of Service?" |
| 0x1420afa68 | sRequirements | "Requirements" |
| 0x1420af060 | sRequirementsText | "Requires:  " |
| 0x1420ae658 | sResetToDefaults | "Reset your control mappings to their default settings?" |
| 0x1420ac798 | sResolution | "Resolution" |
| 0x1420ad3b0 | sResource | "Resource" |
| 0x1420ac630 | sRestartBecauseContentRemoved | "The game must restart now because downloaded content has been removed." |
| 0x1420ae730 | sRestartSignedOut | "You have signed out of your profile and will now be returned to the main menu." |
| 0x1420ac5b8 | sRestartToUseNewContent | "New content has been added.  You will need to restart to use this content.  All unsaved progress will be lost." |
| 0x1420ac618 | sRestartToUseProfileContent | "In order to use the downloaded content associated with this profile, you will need to restart." |
| 0x1420ad7d0 | sRestoration | "RESTORATION" |
| 0x1420ae880 | sResultsFor | "Results For '%s'" |
| 0x1420b61e8 | sRetryText | "Retry" |
| 0x1420abe20 | sReturn | "Return" |
| 0x1420af918 | sRewardXP | "Experience Points Earned" |
| 0x1420af930 | sRewardXPIcon | "Interface\\Shared\\Messages\\glow_XP_Gain.dds" |
| 0x1420aedf0 | sRide | "Ride" |
| 0x1420ade48 | sRSMAge | "Age" |
| 0x1420ae208 | sRSMBody | "Body" |
| 0x1420ae268 | sRSMBrow | "Brow" |
| 0x1420ae0a0 | sRSMBrowForward | "Brow Forward" |
| 0x1420ae070 | sRSMBrowHeight | "Brow Height" |
| 0x1420aded8 | sRSMBrowTypes | "Brow Type" |
| 0x1420ae088 | sRSMBrowWidth | "Brow Width" |
| 0x1420ae010 | sRSMCheekboneHeight | "Cheekbone Height" |
| 0x1420ae028 | sRSMCheekboneWidth | "Cheekbone Width" |
| 0x1420ae160 | sRSMCheekColor | "Cheek Color" |
| 0x1420af1e0 | sRSMCheekColorLower | "Cheek Color Lower" |
| 0x1420af210 | sRSMChinColor | "Chin Color" |
| 0x1420ae118 | sRSMChinForward | "Chin Forward" |
| 0x1420ae100 | sRSMChinLength | "Chin Length" |
| 0x1420ae0e8 | sRSMChinWidth | "Chin Width" |
| 0x1420af168 | sRSMComplexion | "Complexion" |
| 0x1420af180 | sRSMComplexionColor | "Complexion Color" |
| 0x1420af0f0 | sRSMConfirm | "Are you sure you want to be this character?" |
| 0x1420af108 | sRSMConfirmDestruction | "Change preset and lose your changes?" |
| 0x1420af198 | sRSMDirt | "Dirt" |
| 0x1420af1b0 | sRSMDirtColor | "Dirt Color" |
| 0x1420adec0 | sRSMEyeColor | "Eye Color" |
| 0x1420ae130 | sRSMEyeDepth | "Eye Depth" |
| 0x1420ae058 | sRSMEyeHeight | "Eye Height" |
| 0x1420ae178 | sRSMEyelinerColor | "Eyeliner Color" |
| 0x1420ae250 | sRSMEyes | "Eyes" |
| 0x1420ae1a8 | sRSMEyeSocketLowerColor | "Eye Tint" |
| 0x1420ae190 | sRSMEyeSocketUpperColor | "Eye Shadow" |
| 0x1420adea8 | sRSMEyeTypes | "Eye Shape" |
| 0x1420ae040 | sRSMEyeWidth | "Eye Width" |
| 0x1420ae238 | sRSMFace | "Face" |
| 0x1420adf50 | sRSMFacialHairColorPresets | "Facial Hair Color" |
| 0x1420adf38 | sRSMFacialHairPresets | "Facial Hair" |
| 0x1420af138 | sRSMFinishedWarning | "Finished?" |
| 0x1420af240 | sRSMForeheadColor | "Forehead Color" |
| 0x1420ae298 | sRSMHair | "Hair" |
| 0x1420adf20 | sRSMHairColorPresets | "Hair Color" |
| 0x1420adf08 | sRSMHairPresets | "Hair" |
| 0x1420ae220 | sRSMHead | "Head" |
| 0x1420ade60 | sRSMHeadPresets | "Presets" |
| 0x1420adff8 | sRSMJawForward | "Jaw Forward" |
| 0x1420adfe0 | sRSMJawHeight | "Jaw Height" |
| 0x1420adfc8 | sRSMJawWidth | "Jaw Width" |
| 0x1420af1c8 | sRSMLaughLines | "Laugh Lines" |
| 0x1420ae148 | sRSMLipColor | "Lip Color" |
| 0x1420ae280 | sRSMMouth | "Mouth" |
| 0x1420ae0d0 | sRSMMouthForward | "Mouth Forward" |
| 0x1420ae0b8 | sRSMMouthHeight | "Mouth Height" |
| 0x1420adef0 | sRSMMouthTypes | "Mouth Shape" |
| 0x1420ae1d8 | sRSMName | "Name" |
| 0x1420af120 | sRSMNameWarning | "Rename character." |
| 0x1420af228 | sRSMNeckColor | "Neck Color" |
| 0x1420af1f8 | sRSMNoseColor | "Nose Color" |
| 0x1420adfb0 | sRSMNoseHeight | "Nose Height" |
| 0x1420adf98 | sRSMNoseLength | "Nose Length" |
| 0x1420ade90 | sRSMNoseTypes | "Nose Type" |
| 0x1420adf80 | sRSMPaint | "War Paint" |
| 0x1420af150 | sRSMPaintColor | "War Paint Color" |
| 0x1420ae1f0 | sRSMRace | "Race" |
| 0x1420adf68 | sRSMScars | "Scars" |
| 0x1420ade18 | sRSMSex | "Sex" |
| 0x1420ae1c0 | sRSMSkinColor | "Skin Tone" |
| 0x1420ade78 | sRSMTone | "Skin Tone" |
| 0x1420ade30 | sRSMWeight | "Weight" |
| 0x1420ae388 | sRumble | "Vibration" |
| 0x1420ac558 | sSaveFailed | "Save failed." |
| 0x1420ac228 | sSaveGameContentIsMissing | "This save relies on content that is no longer present. Some objects may no longer be available. Continue Loading?" |
| 0x1420ac3a8 | sSaveGameCorrupt | "SAVE CORRUPT" |
| 0x1420ac3f0 | sSaveGameCorruptMenuMessage | "The save game is corrupt and cannot be loaded." |
| 0x1420ac240 | sSaveGameDeviceError | "There was an error accessing the device.  Please try again." |
| 0x1420ac390 | sSaveGameIsCorrupt | "The save game is corrupt.  Returning to game." |
| 0x1420ac3d8 | sSaveGameNoLongerAvailable | "The save game is no longer available.  Returning to game." |
| 0x1420ac378 | sSaveGameNoMasterFilesFound | "None of the master files used in this save game are loaded.  Returning to game." |
| 0x1420ac3c0 | sSaveGameOldVersion | "SAVE OBSOLETE" |
| 0x1420ac258 | sSaveGameOutOfDiskSpace | "The maximum number of saves has been reached. Please delete older saves in order to be able to create a new one." |
| 0x1420ac270 | sSaveNotAvailable | "No valid save game found." |
| 0x1420ac750 | sSaveOnRest | "Save On Rest" |
| 0x1420ac780 | sSaveOnTravel | "Save On Travel" |
| 0x1420ac768 | sSaveOnWait | "Save On Wait" |
| 0x1420ac408 | sSaveOverSaveGame | "Are you sure you want to overwrite this save game?" |
| 0x1420ac540 | sSaveSuccessful | "Save successful." |
| 0x1420af858 | sSceneBlockingActorActivation | "This person is in a conversation." |
| 0x1420ac138 | sScrollEquipped | " equipped." |
| 0x1420ad6f8 | sScrolls | "SCROLLS" |
| 0x1420ad290 | sSearch | "Search" |
| 0x14207a588 | sSeasonFall | "Fall" |
| 0x14207a558 | sSeasonSpring | "Spring" |
| 0x14207a570 | sSeasonSummer | "Summer" |
| 0x14207a5a0 | sSeasonWinter | "Winter" |
| 0x14207a1b0 | sSecondOrdSuffix | "nd" |
| 0x1420abe68 | sSelect | "Select" |
| 0x1420ac870 | sSelectItemToRepair | "CHOOSE ITEM TO REPAIR WITH" |
| 0x1420ac948 | sSelfRange | "Self" |
| 0x1420af450 | sServeSentenceQuestion | "Do you want to serve your time in jail?" |
| 0x1420aca80 | sServeTimeQuestion | "Do you just want to serve your time?" |
| 0x1420ae988 | sSexFemale | "female" |
| 0x1420ae9b8 | sSexFemalePossessive | "her" |
| 0x1420ae9e8 | sSexFemalePronoun | "she" |
| 0x1420ae970 | sSexMale | "male" |
| 0x1420ae9a0 | sSexMalePossessive | "his" |
| 0x1420ae9d0 | sSexMalePronoun | "he" |
| 0x1420ae6b8 | sShadowFade | "Shadow Fade" |
| 0x1420aeca0 | sShouts | "SHOUTS" |
| 0x1420af030 | sSingleDragonSoulCount | "%i Dragon Soul" |
| 0x1420aedc0 | sSit | "Sit" |
| 0x1420acdc8 | sSkillIncreased | "%s Increased to %i" |
| 0x1420acde0 | sSkillIncreasedNum | "%s increased by %d" |
| 0x1420abfe8 | sSkillsCount | "Tag %d Skill" |
| 0x1420abfa0 | sSkillsTitle | "SKILLS:  %d/%d Selected" |
| 0x1420abd78 | sSmall | "Small" |
| 0x1420afe40 | sSmithingConfirm | "Do you want to improve this item?" |
| 0x1420afdb0 | sSmithingMenuDescription | "Choose an item to improve" |
| 0x1420ad578 | sSortMethod | "Sort" |
| 0x1420ac0a8 | sSoulCaptured | "You have captured a soul!" |
| 0x1420aff18 | sSoulGem | "Soul Gem" |
| 0x1420afe88 | sSoulGems | "SOUL GEMS" |
| 0x1420acbd0 | sSoulGemTooSmall | "There is no Soul Gem large enough to capture the soul." |
| 0x1420aefd0 | sSoulLevel | "Filled with %s Soul" |
| 0x14207b540 | sSoulLevelNameCommon | "Common" |
| 0x14207b5a0 | sSoulLevelNameGrand | "Grand" |
| 0x14207b570 | sSoulLevelNameGreater | "Greater" |
| 0x14207b510 | sSoulLevelNameLesser | "Lesser" |
| 0x14207b4e0 | sSoulLevelNamePetty | "Petty" |
| 0x1420abc58 | sSpace | " " |
| 0x1420ae6e8 | sSpecularityFade | "Specularity Fade" |
| 0x1420ada10 | sSpeechChallengeFailure | "[FAILED]" |
| 0x1420ad9f8 | sSpeechChallengeSuccess | "[SUCCESS]" |
| 0x1420a94e0 | sSplashParticles | "Effects\\waterSplash.NIF" |
| 0x1420adbc0 | sStatsMustSelectPerk | "You must select a perk." |
| 0x1420aebb0 | sStatsNextRank | "Next Rank:" |
| 0x1420aeb98 | sStatsPerkConfirm | "Are you sure you want this perk?" |
| 0x1420ad260 | sSteal | "Steal" |
| 0x1420aee50 | sStealFrom | "Steal from" |
| 0x1420acd80 | sStealHorse | "Do you want to steal this horse?" |
| 0x1420afbb8 | sSteel | "STEEL" |
| 0x1420ad350 | sStormcloak | "Stormcloak" |
| 0x1420afbd0 | sStudded | "STUDDED" |
| 0x1420af6a8 | sSuccessfulSneakAttackEnd | "X damage!" |
| 0x1420af690 | sSuccessfulSneakAttackMain | "Sneak attack for " |
| 0x1420aed78 | sTake | "Take" |
| 0x1420ad500 | sTakeAll | "Take All" |
| 0x1420aedd8 | sTalk | "Talk" |
| 0x1420ac960 | sTargetRange | "Target" |
| 0x1420aec70 | sTeammateCantGiveOutfit | "Your teammate already owns that armor." |
| 0x1420aec58 | sTeammateCantTakeOutfit | "You can't take your teammate's starting armor." |
| 0x1420ad668 | sTeammateOverencumbered | "can't carry any more." |
| 0x14209de68 | sTestTopicSetting | "" |
| 0x1420acb40 | sTESVDLC2DragonUnableToFlyMessage | "Your dragon cannot fast travel right now." |
| 0x1420af510 | sTESVDLC2FlyingDragonNoCastMessage | "You cannot cast that type of spell while riding a dragon." |
| 0x1420af558 | sTESVDLC2FlyingMountCancelLandingMessage | "Cancelling your request to land." |
| 0x1420af528 | sTESVDLC2FlyingMountCannotLandMessage | "Your dragon cannot land at this time." |
| 0x1420af540 | sTESVDLC2FlyingMountLandingMessage | "Your dragon is searching for a place to land." |
| 0x1420ac7e0 | sTextureSize | "Texture Size" |
| 0x14207a1c8 | sThirdOrdSuffix | "rd" |
| 0x14207a168 | sTimeAM | "AM" |
| 0x14207a1f8 | sTimeHours | "Hours" |
| 0x14207a210 | sTimeMinutes | "Minutes" |
| 0x14207a180 | sTimePM | "PM" |
| 0x14207a648 | sTimeSpanAfternoon | "afternoon" |
| 0x14207a690 | sTimeSpanEvening | "evening" |
| 0x14207a768 | sTimeSpanMidnight | "midnight" |
| 0x14207a600 | sTimeSpanMorning | "morning" |
| 0x14207a720 | sTimeSpanNight | "night" |
| 0x14207a5b8 | sTimeSpanSunrise | "sunrise" |
| 0x14207a6d8 | sTimeSpanSunset | "sunset" |
| 0x1420abd30 | sTo | "To" |
| 0x1420ac978 | sTouchRange | "Strike" |
| 0x1420abfd0 | sTraitsCount | "Choose up to %d Trait" |
| 0x1420abf88 | sTraitsTitle | "OPTIONAL TRAITS:  %d/%d Selected" |
| 0x1420ae718 | sTreeLODFade | "Tree LOD Fade" |
| 0x1420af498 | sTweenDisabledMessage | "Character screen not available to werewolves." |
| 0x1420abec8 | sUnequipItemOnPlayer | "was unequipped" |
| 0x1420aed00 | sUnlock | "Unlock" |
| 0x1420aed90 | sUse | "Use" |
| 0x1420ad5f0 | sValue | "Value" |
| 0x1420ad878 | sVatsAimed | "Aimed" |
| 0x1420ad860 | sVatsAiming | "Aiming" |
| 0x1420ad890 | sVatsBodyPart | "Body Part" |
| 0x1420ad938 | sVATSMessageLowAP | "Low" |
| 0x1420ad968 | sVATSMessageNoAmmo | "You don't have enough ammo." |
| 0x1420ad950 | sVATSMessageZeroChance | "You have zero chance to hit." |
| 0x1420ad8c0 | sVatsSelect | "Select" |
| 0x1420ad8a8 | sVatsTarget | "Target" |
| 0x1420ae5f8 | sVDSGManual | "VDSG MANUAL" |
| 0x1420adde8 | sVDSGPlate | "VDSG Plate" |
| 0x142079d90 | sVerletCape | "vamplordcapemesh" |
| 0x1420ad1a0 | sVideoChange | "You must exit and restart Skyrim for the new resolution to take effect." |
| 0x1420ac7f8 | sViewDistance | "View Distance" |
| 0x1420acba0 | sVoiceVolume | "Voice" |
| 0x1420aee38 | sWaitHere | "Wait Here" |
| 0x1420ac0d8 | sWeaponBreak | "Your weapon has broken." |
| 0x1420afe58 | sWeaponEnchantments | "WEAPON ENCHANTMENTS" |
| 0x1420ad698 | sWeapons | "WEAPONS" |
| 0x1420afd80 | sWeaponSmithing | "Weapon Smithing" |
| 0x1420ad5d8 | sWeight | "Weight" |
| 0x1420ae580 | sWhite | "WHITE" |
| 0x1420af9d8 | sWitnessKilled | "Last witness killed." |
| 0x1420afc30 | sWood | "WOOD" |
| 0x1420ae340 | sXSensitivity | "X-Sensitivity" |
| 0x1420abc88 | sYes | "Yes" |
| 0x1420ac5d0 | sYesRestart | "Yes, restart the game." |
| 0x1420b6188 | sYesText | "Yes" |
| 0x1420b61b8 | sYesToAllText | "Yes to All" |
| 0x1420abd60 | sYour | "Your" |
| 0x1420ae358 | sYSensitivity | "Y-Sensitivity" |

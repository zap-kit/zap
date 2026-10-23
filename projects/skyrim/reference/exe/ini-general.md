# Ini settings: [General], [Archive], [Language], [Messages], [Papyrus], [SaveGame] and the rest without a section

The value compiled into `SkyrimSE.exe` for each ini setting: what the game uses when neither `Skyrim.ini` nor `SkyrimPrefs.ini` sets it. `skyrim/ini.zap` keeps the few the port reads; this is the whole table. A setting the game fills at run time holds 0 here (NOTES.md names iDifficulty, fAutosaveEveryXMins).

Read from the static `SettingT<INISettingCollection>` objects in `.data` (24 bytes: the vtable, the value, the pointer to the name; the vtable's RTTI names the class), found by scanning `.data` for pointers to names and checked against REA's `read_bytes` at 0x1420d9078 (fShadowBiasScale:Display). The address is the object's; the value is decoded by the name's type letter (f float, i int, u unsigned, b bool, s string, r and a 32-bit colors).

| address | setting | value |
|---|---|---|
| 0x1420b5858 | bActivateFromSave:General | 0 |
| 0x1420cf710 | bAllowFileWrite:MESSAGES | 0 |
| 0x1420b5468 | bAllowProfileTransfer:SaveGame | 0 |
| 0x1420b5480 | bAllowScriptedAutosave:SaveGame | 1 |
| 0x1420b5498 | bAllowScriptedForceSave:SaveGame | 1 |
| 0x1420b62a8 | bAllowYesToAll:MESSAGES | 1 |
| 0x1420b58b8 | bAlwaysActive:General | 0 |
| 0x142078038 | bAnimateDoorPhysics:General | 0 |
| 0x1420b5918 | bAssertsWithoutDebugger:Messages | 0 |
| 0x1420bc9c0 | bAutoSaveOnUserStale:SaveGame | 1 |
| 0x14207b790 | bBackgroundCellLoads:BackgroundLoad | 1 |
| 0x1420b6860 | bBackgroundLoadLipFiles:BackgroundLoad | 1 |
| 0x142078f20 | bBackgroundLoadVMData:General | 0 |
| 0x1420b6248 | bBlockMessageBoxes:MESSAGES | 0 |
| 0x1420b7488 | bBorderRegionsEnabled:General | 1 |
| 0x14207af30 | bCalculateArmorMeshAndTextureFileCounts:General | 1 |
| 0x1420b5ba0 | bChangeTimeMultSlowly:General | 1 |
| 0x14207be08 | bCheckCellOffsetsOnInit:General | 0 |
| 0x142077988 | bCheckPurgedTextureList:General | 0 |
| 0x1420b5ff0 | bCheckRuntimeCollisions:Archive | 0 |
| 0x1420b5688 | bCompressBuffer:SaveGame | 0 |
| 0x1420b54b0 | bConvertNonUtilitySaves:SaveGame | 0 |
| 0x1420b54c8 | bCopySaveGameToHostOrMemStick:SaveGame | 0 |
| 0x1420b58e8 | bCRTMemoryChecks:General | 0 |
| 0x1420cf7a0 | bCullingJobEnablePlaneOptimization:General | 0 |
| 0x1420b07a0 | bDebugFaceGenCriticalSection:Debug | 0 |
| 0x1420b0788 | bDebugFaceGenMultithreading:Debug | 0 |
| 0x1420b7560 | bDebugFlyingMountLeash:Debug | 0 |
| 0x1420b8aa0 | bDebugSpectatorThreats:General | 0 |
| 0x14207ba98 | bDefaultCOCPlacement:General | 0 |
| 0x1420b6a10 | bDisableAllGore:General | 0 |
| 0x1420b6278 | bDisableAssertQueuing:MESSAGES | 1 |
| 0x1420b54e0 | bDisableAutoSave:SaveGame | 0 |
| 0x142077ce8 | bDisableDuplicateReferenceCheck:General | 1 |
| 0x14209c9b8 | bDisableGearedUp:General | 1 |
| 0x1420b6290 | bDisableWarningWindows:General | 0 |
| 0x1420b5d08 | bDisplayBoundingVolumes:General | 0 |
| 0x1420b54f8 | bDisplayMissingContentDialogue:SaveGame | 1 |
| 0x1420b5d20 | bEnableBoundingVolumeOcclusion:General | 1 |
| 0x1420b5900 | bEnableFileCaching:General | 0 |
| 0x1420b6170 | bEnableFriendHenchman:General | 0 |
| 0x142079f20 | bEnableLipLookup | 1 |
| 0x1420bca08 | bEnableLogging:Papyrus | 0 |
| 0x1420bcaf8 | bEnableProfiling:Papyrus | 0 |
| 0x1420bcbc0 | bEnableTrace:Papyrus | 0 |
| 0x14207bdd8 | bExternalLODDataFiles:General | 1 |
| 0x1420b07e0 | bFacegenDisableMorphs:General | 0 |
| 0x1420b07b8 | bFaceGenWarnings:MESSAGES | 0 |
| 0x142077d60 | bFileCheckModelCollision:TestAllCells | 0 |
| 0x14207bca8 | bFileControllerOnRoot:TestAllCells | 1 |
| 0x142077d78 | bFileGoneMessage:TestAllCells | 1 |
| 0x142077d90 | bFileNeededMessage:TestAllCells | 1 |
| 0x142077df0 | bFileShowIcons:TestAllCells | 1 |
| 0x142077e08 | bFileShowTextures:TestAllCells | 1 |
| 0x142077dd8 | bFileSkipIconChecks:TestAllCells | 0 |
| 0x142077d48 | bFileSkipModelChecks:TestAllCells | 0 |
| 0x142077da8 | bFileTestLoad:TestAllCells | 0 |
| 0x142077dc0 | bFileUnusedObject:TestAllCells | 0 |
| 0x142078158 | bFixAIPackagesOnLoad:General | 0 |
| 0x1420b7500 | bFlyingMountFastTravelCruiseEnabled:GENERAL | 0 |
| 0x1420ced30 | bForceAsync:Archive | 0 |
| 0x1420a1370 | bHealthRegenFromRacePlayerOnly:General | 1 |
| 0x1420b6068 | bInvalidateOlderFiles:Archive | 1 |
| 0x1420ceaa8 | bJoblistActiveWait:General | 1 |
| 0x1420795a8 | bKeepDLStringBlocksLoaded:General | 0 |
| 0x1420795c0 | bKeepILStringBlocksLoaded:General | 1 |
| 0x142077eb8 | bKeepPluginWhenMerging:General | 0 |
| 0x1420cec88 | bLoadArchiveInMemory:Archive | 0 |
| 0x1420b0728 | bLoadBackgroundFaceGen:BackgroundLoad | 0 |
| 0x1420bcae0 | bLoadDebugInformation:Papyrus | 0 |
| 0x142077fe0 | bLoadEsmInMemory:Archive | 1 |
| 0x142079dc0 | bLoadHelmetsInBackground:BackgroundLoad | 1 |
| 0x1420bb328 | bModManagerMenuEnabled:General | 1 |
| 0x1420b5810 | bNoBreaksForAsserts:Messages | 0 |
| 0x1420b5510 | bOutputSaveGameScreenshot:SaveGame | 1 |
| 0x1420b7ff8 | bParallelAnimUpdate:General | 0 |
| 0x1420b58d0 | bPauseWhenConstrained:General | 1 |
| 0x1420b5df8 | bPreCullActors:General | 1 |
| 0x142077730 | bPreemptivelyUnloadCells:General | 0 |
| 0x1420d3c68 | bPreloadIntroSequence:General | 1 |
| 0x14207bab0 | bPreloadLinkedInteriors:General | 0 |
| 0x14207bb80 | bPrimitivesOn | 0 |
| 0x1420779a0 | bQueueWarnings:General | 0 |
| 0x1420795d8 | bReconstructIDTags:General | 0 |
| 0x1420b5960 | bResetGameAfterStreamingInstall:StreamInstall | 0 |
| 0x1420b8028 | bRunMiddleLowLevelProcess:General | 1 |
| 0x1420b5b70 | bRunVTuneTest:General | 0 |
| 0x1420776b8 | bSelectivePurgeUnusedOnFastTravel:BackgroundLoad | 0 |
| 0x1420b6398 | bShowCheckMemoryOutput:General | 0 |
| 0x1420b77d8 | bShowGunTarget:General | 0 |
| 0x142077790 | bShowLoadingAreaMessage:General | 0 |
| 0x1420cc900 | bShowMissingAudioWarnings:MESSAGES | 1 |
| 0x1420b68a8 | bShowMissingLipWarnings:MESSAGES | 1 |
| 0x1420b62f0 | bSkipInitializationFlows:MESSAGES | 1 |
| 0x1420b62c0 | bSkipProgramFlows:MESSAGES | 1 |
| 0x1420b8010 | bTaskletActorSceneGraphUpdates:General | 1 |
| 0x1420b64a8 | bTaskletCellTransformsUpdate:General | 1 |
| 0x1420b68f0 | bTrackAllDeaths:General | 0 |
| 0x142077b98 | bTrackFileLoading:Archive | 0 |
| 0x1420b58a0 | bUseArchives:Archive | 1 |
| 0x1420b5fc0 | bUseBackgroundFileLoader:BackgroundLoad | 0 |
| 0x142079dd8 | bUseBodyMorphs:General | 1 |
| 0x1420b0710 | bUseEyeEnvMapping:General | 1 |
| 0x1420b06b0 | bUseFaceGenPreprocessedHeads:General | 1 |
| 0x1420b5de0 | bUseHardDriveCache:General | 0 |
| 0x1420b6a58 | bUseMovementBlockedPackage:General | 0 |
| 0x14207ba68 | bUseMultibounds:General | 1 |
| 0x1420b06f8 | bUseMultiThreadedFaceGen:BackgroundLoad | 1 |
| 0x1420779b8 | bUseMultiThreadedTrees:BackgroundLoad | 1 |
| 0x142079030 | bUseOptimizedTextureLoading:General | 1 |
| 0x1420b5408 | bUseSaveGameHistory:SaveGame | 0 |
| 0x1420b5be8 | bUseThreadedMorpher:General | 0 |
| 0x1420b5bd0 | bUseThreadedParticleSystem:General | 0 |
| 0x1420b5bb8 | bUseThreadedTempEffects:General | 1 |
| 0x1420b3770 | bUseWaterHDR | 1 |
| 0x1420b6260 | bUseWindowsMessageBox:MESSAGES | 0 |
| 0x1420d90f0 | bWarnOnMaterialCollisions:General | 0 |
| 0x142079018 | bWarnOnMissingFileEntry:General | 0 |
| 0x142077bb0 | bWriteTACOutputToFile:Debug | 0 |
| 0x1420b5888 | fArchiveInitBufferMB:Papyrus | 8.0 |
| 0x14207b0c0 | fAutoDoorFadeSecs:General | 0.5 |
| 0x1420b7138 | fBetaDeferredKillTimer:General | 15.0 |
| 0x1420cf628 | fBSTaskTime:General | 2.0 |
| 0x1420b48d0 | fCloakEffectUpdateInterval:General | 0.5 |
| 0x1420b7080 | fDragonLandingForPlayerNavMeshSize:GENERAL | 250.0 |
| 0x1420b7068 | fDragonLandingForPlayerSearchDist:GENERAL | 3000.0 |
| 0x1420b76b8 | fEncumberedReminderTimer:General | 30.0 |
| 0x1420bca68 | fExtraTaskletBudgetMS:Papyrus | 1.2 |
| 0x1420d9178 | fFadingFracStart | 0.25 |
| 0x1420bc528 | fFastTravelFadeSecs:General | 0.5 |
| 0x14207ba80 | fFlickeringLightDistance:General | 1024.0 |
| 0x1420b6e78 | fFlyingMountDismountOffset:GENERAL | 30.0 |
| 0x1420b75c0 | fFlyingMountFastTravelArrivalHeight:GENERAL | 1000.0 |
| 0x1420b75d8 | fFlyingMountFastTravelDragonSpeed:GENERAL | 7000.0 |
| 0x1420b75a8 | fFlyingMountLandingRequestTimer:GENERAL | 3.0 |
| 0x1420b7590 | fFlyingMountSlowestSpeedMult:GENERAL | 0.25 |
| 0x1420b75f0 | fFlyingMountTutorialMessageDelay:GENERAL | 15.0 |
| 0x1420bb268 | fJoyConStrapInstructionDelay:General | 5.0 |
| 0x1420bcce8 | fKinectMaxAllyTradeDistance:Kinect | 60000.0 |
| 0x1420bcd30 | fKinectMinConfidence:Kinect | 0.3 |
| 0x1420bcd18 | fKinectMinReportConfidence:Kinect | 0.01 |
| 0x1420bcd48 | fKinectMinReportShoutConfidence:Kinect | 0.005 |
| 0x1420bcd00 | fKinectMinRuleConfidence:Kinect | 0.25 |
| 0x1420bcd60 | fKinectMinShoutConfidence:Kinect | 0.0075 |
| 0x1420bc6f8 | fLoadGameFadeSecs:General | 1.0 |
| 0x1420b9de8 | fLowPerfCombatantVoiceDistance | 1000.0 |
| 0x1420bc540 | fMapWorldTargetTransitionTime | 0.5 |
| 0x14207b0f0 | fNormalDoorFadeSecs:General | 0.4 |
| 0x14207b0d8 | fNormalDoorFadeWait:General | 0.01 |
| 0x1420b7518 | fPlayerFlyingMountBaseTargetSpeed:GENERAL | 700.0 |
| 0x1420b7530 | fPlayerFlyingMountFastBaseTargetSpeed:GENERAL | 1400.0 |
| 0x1420b7548 | fPlayerFlyingMountNothingLoadingMult:GENERAL | 10.0 |
| 0x1420b18a8 | fPlayerFlyingMountTravelMaxHeight:GENERAL | 400.0 |
| 0x1420b1890 | fPlayerFlyingMountTravelMinHeight:GENERAL | 200.0 |
| 0x1420bca80 | fPostLoadUpdateTimeMS:Papyrus | 2000.0 |
| 0x1420b7fe0 | fProcessListsUpdateHighFrameRate:General | 30.0 |
| 0x1420b7fc8 | fProcessListsUpdateLowFrameRate:General | 10.0 |
| 0x1420b7f98 | fProcessListsUpdateTimeMax:General | 5.0 |
| 0x1420b7fb0 | fProcessListsUpdateTimeMin:General | 0.5 |
| 0x14207e518 | fQuestScriptDelayTime:MAIN | 5.0 |
| 0x1420d8bd8 | fSnowSSSDarkColorIntensity | 0.1 |
| 0x1420b3b88 | fStoryTellerQuestFindTime:General | 2.0 |
| 0x1420bca50 | fUpdateBudgetMS:Papyrus | 1.2 |
| 0x1420b5528 | iAutoSaveCount:SaveGame | 3 |
| 0x1420b69b0 | iDetectionHighNumPicks | 40 |
| 0x1420b0ed8 | iEnumRefsAllowedPerFrame:General | 1 |
| 0x1420b6080 | iFileLogging:MESSAGES | 0 |
| 0x1420b7578 | iFlyingMountSlowestQueuedRefCount:GENERAL | 250 |
| 0x1420b5b88 | iFPSClamp:General | 0 |
| 0x1420d1808 | iHWThread1:General | 4 |
| 0x1420d1820 | iHWThread2:General | 4 |
| 0x1420d1838 | iHWThread3:General | 4 |
| 0x1420d1850 | iHWThread4:General | 5 |
| 0x1420d1868 | iHWThread5:General | 5 |
| 0x1420d1880 | iHWThread6:General | 5 |
| 0x1420d3c98 | iIntroSequencePriority:General | 3 |
| 0x142077c58 | iLargeIntRefCount:General | 1000 |
| 0x1420b7f80 | iLowProcessingMilliseconds:General | 2 |
| 0x1420bcac8 | iMaxAllocatedMemoryBytes:Papyrus | 153600 |
| 0x1420b57f8 | iMaxJobThreads:General | 32 |
| 0x1420bcab0 | iMaxMemoryPageSize:Papyrus | 512 |
| 0x1420b74d0 | iMaxQuestObjectives | 3000 |
| 0x1420bca98 | iMinMemoryPageSize:Papyrus | 128 |
| 0x1420b6488 | iNumBitsForFullySeen:General | 248 |
| 0x142077778 | iNumHWThreads:General | 4 |
| 0x1420cf640 | iPostProcessMilliseconds:BackgroundLoad | 2 |
| 0x1420cf670 | iPostProcessMillisecondsEditor:BackgroundLoad | 50 |
| 0x1420cf658 | iPostProcessMillisecondsLoadingQueuedPriority:BackgroundLoad | 20 |
| 0x1420cf688 | iPostProcessTaskWarningMilliseconds:BackgroundLoad | 20 |
| 0x1420d3c80 | iPreloadSizeLimit:General | 26214400 |
| 0x1420b6008 | iRetainDirectoryStringTable:Archive | 1 |
| 0x1420b6038 | iRetainFilenameOffsetTable:Archive | 1 |
| 0x1420b6020 | iRetainFilenameStringTable:Archive | 1 |
| 0x1420b5540 | iSaveGameBackupCount:SaveGame | 1 |
| 0x1420d89f8 | iSnowNoiseTextureSize | 512 |
| 0x1420b0ef0 | iUpdateDetectionsAllowedPerFrame:General | 100 |
| 0x1420b5978 | sArchiveList:Archive | "Skyrim - Textures.bsa, Skyrim - Meshes.bsa, Skyrim - Voices.bsa" |
| 0x1420ceca0 | sArchiveToLoadInMemoryList:Archive | "Skyrim - Animations.bsa, Skyrim - Interface.bsa, Skyrim - Misc.bsa, Skyrim - Sounds.bsa" |
| 0x1420bb298 | sCharGenQuest:General | "0003372b" |
| 0x1420ccd10 | sControlsDefinitionFile | "Interface/Controls/PC/ControlMap.txt" |
| 0x1420ce8a0 | sControlsDefinitionFile | "Interface/Controls/PC/GamepadOrbis.txt" |
| 0x1420ccd28 | sControlsRemapFile | "ControlMap_Custom.txt" |
| 0x1420b5fa8 | sCopyProtectionMessage2:CopyProtectionStrings | "Insert the Skyrim Disc." |
| 0x1420b5f78 | sCopyProtectionMessage:CopyProtectionStrings | "Unable to find a CD-ROM/DVD drive on this computer." |
| 0x1420b5f90 | sCopyProtectionTitle2:CopyProtectionStrings | "Skyrim Disc Not Found" |
| 0x1420b5f60 | sCopyProtectionTitle:CopyProtectionStrings | "CD-ROM Drive Not Found" |
| 0x1420b62d8 | sDisabledProgramFlowContexts:MESSAGES | "" |
| 0x142077ff8 | sEsmToLoadInMemoryList:Archive | "Skyrim.esm, Update.esm, Dawnguard.esm, HearthFires.esm, Dragonborn.esm" |
| 0x1420b5930 | sEssentialFileCacheList:General | "" |
| 0x142077a00 | sFailureMessage:LANGUAGE | "Something is broken" |
| 0x14209cd50 | sFileTypeGame:Voice | "wav" |
| 0x14209cd80 | sFileTypeLip:Voice | "lip" |
| 0x14209cd98 | sFileTypeLTF:Voice | "ltf" |
| 0x14209cd68 | sFileTypeSource:Voice | "wav" |
| 0x1420d2fd8 | sFontConfigFile:Fonts | "Interface\\FontConfig.txt" |
| 0x1420ba9c0 | sGameCode:OAuth | "" |
| 0x1420ccd68 | sGamepadDefinitionFile | "Interface/Controls/PC/Gamepad.txt" |
| 0x1420bb310 | sGamerIconTextureName:General | "BGSUserIcon" |
| 0x142077d30 | sGeneralMasterMismatchWarning:GeneralWarnings | "One or more plugins could not find the correct versions of the master files they depend on. Errors may occur during load or game play. Check the \"Warnings.txt\" file for more information.\r\n" |
| 0x1420b5750 | sIntroMovie:General | "" |
| 0x1420b5720 | sIntroSequence:General | "BGS_Logo.bik" |
| 0x1420b6050 | sInvalidationFile:Archive | "ArchiveInvalidation.txt" |
| 0x1420ce568 | sKeyboardDefinitionFile | "Interface/Controls/PC/Keyboard_" |
| 0x1420779e8 | sLanguage:General | "ENGLISH" |
| 0x142077cd0 | sLocalCharacterDataPath:General | "Saves\\Character\\" |
| 0x142077ca0 | sLocalMasterPath:General | "Data\\" |
| 0x142077cb8 | sLocalSavePath:General | "Saves\\" |
| 0x1420b5738 | sMainMenuMovieIntro:General | "" |
| 0x1420bb2b0 | sMainMenuMusic:General | "\\Data\\Music\\Special\\MUS_MainTheme.xwm" |
| 0x142077d18 | sMasterMismatchWarning:GeneralWarnings | "One of the files that \"%s\" is dependent on has changed since the last save." |
| 0x1420ce590 | sMouseDefinitionFile | "Interface/Controls/PC/Mouse.txt" |
| 0x1420b59a8 | sResourceArchiveList2:Archive | "" |
| 0x1420b5990 | sResourceArchiveList:Archive | "Skyrim - Misc.bsa, Skyrim - Shaders.bsa, Skyrim - Textures.bsa, Skyrim - Meshes.bsa, Skyrim - Animations.bsa, Skyrim - Voices.bsa, Skyrim - VoicesExtra.bsa, Skyrim - Interface.bsa, Skyrim - Sounds.bsa, MarketplaceTextures.bsa, Skyrim - Patch.bsa" |
| 0x1420b59c0 | sResourceArchiveListBeta:Archive | "" |
| 0x1420b59f0 | sResourceArchiveRetainFileNameList:Archive | "" |
| 0x1420b59d8 | sResourcePrefixList:Archive | "TEXTURES\\, MESHES\\, FACEGEN\\, INTERFACE\\ , MUSIC\\, SOUND\\, SCRIPTS\\, MAXHEIGHTS\\, VIS\\, GRASS\\, STRINGS\\, SHADERSFX\\" |
| 0x1420b5558 | sSaveGameGameVersionOutdated:SaveGame | "This save game was created on a later version of Skyrim. Please download any updates." |
| 0x1420b5570 | sSaveGameSafeMarkerID:SaveGame | "1DC0A" |
| 0x1420b53f0 | sSaveGameScreenshotName | "BGSSaveLoadHeader_Screenshot" |
| 0x1420b5af8 | sStartingCell:General | "" |
| 0x1420b5b28 | sStartingCellX:General | "" |
| 0x1420b5b40 | sStartingCellY:General | "" |
| 0x1420b5b58 | sStartingConsoleCommand:General | "" |
| 0x1420b5b10 | sStartingWorld:General | "" |
| 0x142077a30 | sSysUtil_AutoSaveWarning:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077b38 | sSysUtil_AwardsConfiguring:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077b08 | sSysUtil_AwardsInstalling:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077af0 | sSysUtil_AwardsLoading:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077b20 | sSysUtil_AwardsReinstalling:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077b50 | sSysUtil_AwardsUpdating:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077ad8 | sSysUtil_DirtyDisc:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077ac0 | sSysUtil_DiscEject:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077b80 | sSysUtil_GameContentInstalling:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077a60 | sSysUtil_GameDataCorrupt:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077a48 | sSysUtil_GameDataInsufficientSpace:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077b68 | sSysUtil_NPDRMInstalling:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077a18 | sSysUtil_Retry:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077a78 | sSysUtil_SaveDataCreateNew:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077a90 | sSysUtil_SaveDataInsufficientSpace:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x142077aa8 | sSysUtil_SaveDataOwnershipWarning:LANGUAGE | "No Default string.  Must be loaded from INIFile" |
| 0x1420b5ae0 | sTestFile10:General | "" |
| 0x1420b5a08 | sTestFile1:General | "Skyrim.esm" |
| 0x1420b5a20 | sTestFile2:General | "" |
| 0x1420b5a38 | sTestFile3:General | "" |
| 0x1420b5a50 | sTestFile4:General | "" |
| 0x1420b5a68 | sTestFile5:General | "" |
| 0x1420b5a80 | sTestFile6:General | "" |
| 0x1420b5a98 | sTestFile7:General | "" |
| 0x1420b5ab0 | sTestFile8:General | "" |
| 0x1420b5ac8 | sTestFile9:General | "" |
| 0x1420b5948 | sUnessentialFileCacheList:General | "" |
| 0x142079ea8 | uGridsToLoad:General | 5 |
| 0x14207b638 | uLMaxCellDemotePerFrame:General | 1 |
| 0x1420bb2e0 | uMainMenuMusicAttnmB:General | 1200 |
| 0x1420bb2c8 | uMainMenuMusicFadeTimeMS:General | 1500 |
| 0x1420bb2f8 | uModMenuMusicAttnmB:General | 2000 |
| 0x1420bccb8 | uTraceStatusOfQuest:Papyrus | 0 |

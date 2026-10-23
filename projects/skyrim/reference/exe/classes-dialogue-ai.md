# Dialogue, scenes, packages and AI (188 classes, 1 template classes left out)

From the MSVC RTTI of `SkyrimSE.exe`: 7,831 type descriptors (`.?AV...@@` in `.data`), 8,457 complete object locators and 7,159 classes with a vtable in `.rdata`. Here the classes of the inn's systems with their primary vtable (the one at offset 0 of the object) and how many virtual functions follow it before the next vtable (the count includes the slots of the base classes; a class's own slots come last). A secondary vtable (a base at another offset) is listed with that offset. Template classes (`BSTEventSink<...>`, `ConcreteFormFactory<...>`, the behavior tree's `CombatBehaviorTreeNodeObject<...>`) are left out; their count is in the system's heading. The vtable's slot k holds the address of the virtual function, so a function is found as the vtable's address plus 8 k, and `procedure_pseudo_code` on that address gives its code.

The layouts to read a slot by name: CommonLibSSE-NG's headers declare each class's virtual functions in vtable order (`IMenu`: 0 destructor, 1 Accept(CallbackProcessor), 2 PostCreate, 3 Unk_03, 4 ProcessMessage(UIMessage), 5 AdvanceMovie(interval, currentTime), 6 PostDisplay, 7 PreDisplay, 8 RefreshPlatform).

| class | vtable | slots | other vtables (offset: address, slots) |
|---|---|---|---|
| ActorPackageData | 0x1418d5d38 | 9 |  |
| BGSBaseAlias | 0x1418560f8 | 4 |  |
| BGSDialogueBranch | 0x141853b18 | 59 |  |
| BGSIdleCollection | 0x1417f7ee8 | 4 |  |
| BGSIdleMarker | 0x1418558f8 | 83 | 48: 0x141855b98, 7, 88: 0x141855bd8, 4 |
| BGSPackageDataBool | 0x1418c4770 | 13 |  |
| BGSPackageDataFloat | 0x1418c48d0 | 14 |  |
| BGSPackageDataInt | 0x1418c4a38 | 14 |  |
| BGSPackageDataLocation | 0x1418c4e80 | 5 | 8: 0x1418c4eb0, 13 |
| BGSPackageDataLocationWrapper | 0x1418c5648 | 4 | 8: 0x1418c5670, 13 |
| BGSPackageDataObjectList | 0x1418c5718 | 12 | 8: 0x1418c5780, 13 |
| BGSPackageDataRef | 0x1418c5de0 | 13 | 8: 0x1418c5e50, 13 |
| BGSPackageDataRefOLD | 0x1418c4c68 | 13 | 8: 0x1418c4cd8, 13 |
| BGSPackageDataTargetSelector | 0x1418c4f98 | 14 |  |
| BGSPackageDataTopic | 0x1418c60e8 | 13 |  |
| BGSProcedureAcquire | 0x1418c92c8 | 35 |  |
| BGSProcedureAcquireExecState | 0x1418c9438 | 9 |  |
| BGSProcedureActivate | 0x1418c97a8 | 35 |  |
| BGSProcedureActivateExecState | 0x1418c9918 | 9 |  |
| BGSProcedureBase | 0x1418c8af8 | 34 |  |
| BGSProcedureDialogue | 0x1418c9c28 | 35 |  |
| BGSProcedureDialogueActivate | 0x1418ca140 | 35 |  |
| BGSProcedureDialogueActivateExecState | 0x1418ca2b0 | 9 |  |
| BGSProcedureDialogueExecState | 0x1418c73d0 | 9 |  |
| BGSProcedureDone | 0x1418c8d30 | 35 |  |
| BGSProcedureDoneExecState | 0x1418c6a40 | 9 |  |
| BGSProcedureEat | 0x1418ca588 | 35 |  |
| BGSProcedureEatExecState | 0x1418c7470 | 9 |  |
| BGSProcedureEscort | 0x1418cab40 | 35 |  |
| BGSProcedureEscortExecState | 0x1418cacb0 | 9 |  |
| BGSProcedureFind | 0x1418caff8 | 35 |  |
| BGSProcedureFindExecState | 0x1418c7510 | 9 |  |
| BGSProcedureFlee | 0x1418cb608 | 35 |  |
| BGSProcedureFleeExecState | 0x1418cb778 | 9 |  |
| BGSProcedureFlightGrab | 0x1418cbab0 | 35 |  |
| BGSProcedureFlightGrabExecState | 0x1418cbc20 | 9 |  |
| BGSProcedureFollow | 0x1418cc0d8 | 35 |  |
| BGSProcedureFollowExecState | 0x1418cc488 | 9 |  |
| BGSProcedureFollowTo | 0x1418cc318 | 35 |  |
| BGSProcedureForceGreet | 0x1418cc820 | 35 |  |
| BGSProcedureGuard | 0x1418ccbf8 | 35 |  |
| BGSProcedureGuardExecState | 0x1418c75b0 | 9 |  |
| BGSProcedureHoldPosition | 0x1418ccf38 | 35 |  |
| BGSProcedureHoldPositionExecState | 0x1418c7650 | 9 |  |
| BGSProcedureHover | 0x1418cd320 | 35 |  |
| BGSProcedureHoverExecState | 0x1418cd490 | 9 |  |
| BGSProcedureKeepAnEyeOn | 0x1418cd758 | 35 |  |
| BGSProcedureKeepAnEyeOnExecState | 0x1418c76f0 | 9 |  |
| BGSProcedureLock | 0x1418cdb78 | 35 |  |
| BGSProcedureLockUnlockExecState | 0x1418cdf28 | 9 |  |
| BGSProcedureOrbit | 0x1418ce3d8 | 35 |  |
| BGSProcedureOrbitExecState | 0x1418ce548 | 9 |  |
| BGSProcedurePatrol | 0x1418cebe0 | 35 |  |
| BGSProcedurePatrolExecState | 0x1418ced50 | 9 |  |
| BGSProcedurePursue | 0x1418cf000 | 35 |  |
| BGSProcedureSandbox | 0x1418cf7c0 | 35 |  |
| BGSProcedureSandboxExecState | 0x1418cf930 | 9 |  |
| BGSProcedureSay | 0x1418cfb80 | 35 |  |
| BGSProcedureSayExecState | 0x1418c7790 | 9 |  |
| BGSProcedureShout | 0x1418d0110 | 35 |  |
| BGSProcedureShoutExecState | 0x1418d0298 | 9 | 8: 0x1418d02e8, 2 |
| BGSProcedureSit | 0x1418d0668 | 35 |  |
| BGSProcedureSitSleepExecState | 0x1418d0a18 | 9 |  |
| BGSProcedureSleep | 0x1418d08a8 | 35 |  |
| BGSProcedureTravel | 0x1418d0db0 | 35 |  |
| BGSProcedureTravelExecState | 0x1418d0f20 | 9 |  |
| BGSProcedureTreeBranch | 0x1418c6b20 | 18 |  |
| BGSProcedureTreeConditionalItem | 0x1418c6a90 | 17 |  |
| BGSProcedureTreeOneChildExecState | 0x1418c6bb8 | 10 |  |
| BGSProcedureTreeProcedure | 0x1418d1310 | 17 |  |
| BGSProcedureTreeRandom | 0x1418c7238 | 18 |  |
| BGSProcedureTreeRandomExecState | 0x1418c7328 | 10 |  |
| BGSProcedureTreeSequence | 0x1418c6ca8 | 18 |  |
| BGSProcedureTreeSequenceExecState | 0x1418c6d98 | 10 |  |
| BGSProcedureTreeSimultaneous | 0x1418c7068 | 18 |  |
| BGSProcedureTreeSimultaneousExecState | 0x1418c7150 | 9 |  |
| BGSProcedureTreeStacked | 0x1418c6e88 | 18 |  |
| BGSProcedureTreeStackedExecState | 0x1418c6f78 | 10 |  |
| BGSProcedureUnlock | 0x1418cddb8 | 35 |  |
| BGSProcedureUseIdleMarker | 0x1418d1650 | 35 |  |
| BGSProcedureUseIdleMarkerExecState | 0x1418d17c0 | 9 |  |
| BGSProcedureUseMagic | 0x1418d1bf0 | 35 |  |
| BGSProcedureUseMagicExecState | 0x1418d1d60 | 9 | 8: 0x1418d1db0, 2 |
| BGSProcedureUseWeapon | 0x1418d2420 | 35 |  |
| BGSProcedureUseWeaponExecState | 0x1418d2590 | 9 |  |
| BGSProcedureWait | 0x1418d27d8 | 35 |  |
| BGSProcedureWaitExecState | 0x1418c7830 | 9 |  |
| BGSProcedureWander | 0x1418d2c08 | 35 |  |
| BGSProcedureWanderExecState | 0x1418d2d78 | 9 |  |
| BGSRefAlias | 0x141858618 | 4 |  |
| BGSScene | 0x1418592f8 | 59 |  |
| BGSSceneAction | 0x141859580 | 20 |  |
| BGSSceneActionDialogue | 0x141859628 | 20 |  |
| BGSSceneActionPackage | 0x1418596d0 | 20 |  |
| BGSSceneActionTimer | 0x141859ac0 | 20 |  |
| BGSSceneInfo | 0x141802210 | 1 |  |
| BGSSceneInfo::TextureUse | 0x1418021f8 | 2 |  |
| BGSStoryTeller | 0x1418e8940 | 2 |  |
| BSNavmesh | 0x141abfd50 | 2 |  |
| BSNavmeshInfoMap | 0x141ac02e0 | 6 |  |
| BSNavmeshInfoMap::IRecursiveVisitor | 0x141ac02c0 | 3 |  |
| BSNavmeshInfoMap::IVisitor | 0x1418da7f8 | 2 |  |
| BSNavmeshInfoSearch | 0x141abcd58 | 3 |  |
| BSNavmeshObstacleData | 0x141ac05a8 | 2 |  |
| BSNavmeshObstacleUndoData | 0x141acbd08 | 2 |  |
| BSNavmeshReferenceObstacleArray | 0x1418dbc40 | 2 |  |
| BSNavmeshSearch | 0x141ac1948 | 3 |  |
| BSNavmeshSearchFilters | 0x141ac17f0 | 2 |  |
| BSNavmeshSearchHideFilter | 0x1418de770 | 2 |  |
| BSNavmeshSearchMaxCostFilters | 0x1418de938 | 2 |  |
| BSPathing | 0x141abc9a0 | 9 |  |
| BSPathing::CheckLineOfSightFilter | 0x1418fc068 | 2 |  |
| BSPathing::EdgeFoundVisitor | 0x141abc988 | 2 |  |
| BSPathingCell | 0x1418dd0a8 | 11 |  |
| BSPathingCellManager | 0x1418dcd70 | 11 |  |
| BSPathingDoor | 0x1418dd498 | 18 |  |
| BSPathingLOSGrid | 0x141ac1de8 | 3 |  |
| BSPathingLOSGridCell | 0x141ac1e08 | 3 |  |
| BSPathingLOSGridMap | 0x141ac1dc8 | 3 |  |
| BSPathingLockData | 0x1418dd7e0 | 6 |  |
| BSPathingNumericIDVisitor | 0x1418dd868 | 2 |  |
| BSPathingRequest | 0x141abd278 | 7 |  |
| BSPathingSearchRayCast | 0x141acac00 | 1 |  |
| BSPathingSpace | 0x1418dda28 | 4 |  |
| BSPathingStreamRead | 0x1418d9768 | 20 |  |
| BSPathingStreamSimpleBufferRead | 0x141ac4320 | 20 |  |
| BSPathingStreamSimpleBufferWrite | 0x14192fac8 | 17 |  |
| BSPathingStreamWrite | 0x14192fa38 | 17 |  |
| DialoguePackage | 0x1418d5468 | 64 |  |
| ExtraInfoGeneralTopic | 0x1417ed3b0 | 3 |  |
| ExtraPackage | 0x1417ed3d0 | 3 |  |
| ExtraPackageData | 0x1417ea478 | 3 |  |
| ExtraPackageStartLocation | 0x1417e9c98 | 3 |  |
| ExtraSayToTopicInfo | 0x1417ed570 | 3 |  |
| ExtraSayTopicInfoOnceADay | 0x1417ed550 | 3 |  |
| MovementAgent | 0x141ac6210 | 13 |  |
| MovementAgentActorAvoider | 0x141ac60e0 | 13 | 24: 0x141ac6150, 4, 32: 0x141ac6178, 7, 40: 0x141ac61b8, 3 |
| MovementAgentActorState | 0x141abd018 | 13 | 24: 0x141abd088, 4, 32: 0x141abd0b0, 3, 40: 0x141abd0d0, 3 |
| MovementAgentPathFollowerFlight | 0x141ac7a40 | 14 | 24: 0x141ac7ab8, 4, 32: 0x141ac7ae0, 7, 40: 0x141ac7b20, 21, 48: 0x141ac7bd0, 1 |
| MovementAgentPathFollowerStandard | 0x141abe270 | 13 | 24: 0x141abe2e0, 4, 32: 0x141abe308, 7, 40: 0x141abe348, 21, 48: 0x141abe3f8, 2, 56: 0x141abe410, 4, 64: 0x141abe438, 4 |
| MovementAgentPathFollowerVirtual | 0x141ac7ed0 | 14 | 24: 0x141ac7f48, 4, 32: 0x141ac7f70, 7, 40: 0x141ac7fb0, 21, 48: 0x141ac8060, 2 |
| MovementControllerAI | 0x141ac4220 | 10 |  |
| MovementControllerNPC | 0x14192f0e8 | 21 | 288: 0x14192f198, 4, 296: 0x14192f1c0, 9, 304: 0x14192f210, 6, 312: 0x14192f248, 9, 320: 0x14192f298, 6, 328: 0x14192f2d0, 2 |
| MovementControllerNullDataTracker | 0x141ac43e0 | 2 |  |
| MovementPathManagerAgent | 0x141abeb88 | 13 | 24: 0x141abebf8, 7 |
| MovementPathManagerAgentAvoidBox | 0x141ac9450 | 13 | 24: 0x141ac94c0, 7 |
| MovementPathManagerAgentLoadedAreaMonitor | 0x141ac75b0 | 13 | 24: 0x141ac7620, 7 |
| MovementPathManagerAgentStaticAvoider | 0x141ac5828 | 13 | 24: 0x141ac5898, 7, 32: 0x141ac58d8, 4, 40: 0x141ac5900, 3 |
| MovementPathManagerArbiter | 0x141abece0 | 18 | 24: 0x141abed78, 5, 32: 0x141abeda8, 14 |
| MovementPathManagerNullTracker | 0x141abee98 | 4 |  |
| NavMesh | 0x1418d9388 | 63 | 32: 0x1418d9588, 2, 40: 0x1418d95a0, 2 |
| NavMeshInfoMap | 0x1418da810 | 59 | 32: 0x1418da9f0, 6 |
| NavMeshObstacleManager | 0x1418dbc28 | 2 |  |
| NavMeshSearchClosePoint | 0x1418de238 | 3 |  |
| NavMeshSearchFitSphere | 0x1418de610 | 3 |  |
| NavMeshSearchFlee | 0x1418de6a8 | 3 |  |
| NavMeshSearchHide | 0x1418de750 | 3 |  |
| NavMeshSearchLOS | 0x1418de880 | 3 |  |
| NavMeshSearchMaxCost | 0x1418de918 | 3 |  |
| NavMeshSearchMultipleGoals | 0x1418de9f0 | 3 |  |
| NavMeshSearchSLPoint | 0x1418dea88 | 3 |  |
| PackageList::IPackageVisitor | 0x14191b4f0 | 1 |  |
| PathManagerPositionPlayerAdapter | 0x14190f930 | 2 | 8: 0x14190f948, 2, 16: 0x14190f960, 2, 24: 0x14190f978, 2, 32: 0x14190f990, 2 |
| PathingRequest | 0x1418dd9d8 | 7 |  |
| PathingRequestClosePoint | 0x1418debc8 | 7 |  |
| PathingRequestClosestGoal | 0x1418def58 | 7 |  |
| PathingRequestCover | 0x1418df1a0 | 7 |  |
| PathingRequestFlee | 0x1418df2c8 | 7 |  |
| PathingRequestFly | 0x1418df418 | 7 |  |
| PathingRequestFlyAction | 0x1418df568 | 7 |  |
| PathingRequestFlyHover | 0x1418df780 | 7 |  |
| PathingRequestFlyLand | 0x1418df8d0 | 7 |  |
| PathingRequestFlyOrbit | 0x1418df9f8 | 7 |  |
| PathingRequestFlyTakeOff | 0x1418dfb20 | 7 |  |
| PathingRequestHide | 0x1418dfca0 | 7 |  |
| PathingRequestLOS | 0x1418dfeb8 | 7 |  |
| PathingRequestOptimalLocation | 0x1418dffe0 | 7 |  |
| PathingRequestRotate | 0x1418e0138 | 7 |  |
| PathingRequestSafeStraightLine | 0x1418e0260 | 7 |  |
| PathingRequestStopMoving | 0x1418e0390 | 7 |  |
| ProcessLists::GetActorsFilter | 0x1418f8870 | 2 |  |
| TESFurniture | 0x141811840 | 83 | 48: 0x141811ae0, 6, 64: 0x141811b18, 7, 120: 0x141811b58, 4, 136: 0x141811b80, 4, 144: 0x141811ba8, 6 |
| TESIdleForm | 0x14185c410 | 59 |  |
| TESPackage | 0x1418d5260 | 64 |  |
| TESPackageData | 0x1418d5730 | 6 |  |
| TESQuest | 0x141860910 | 63 | 40: 0x141860b10, 6 |
| TESTopic | 0x141862fe0 | 59 | 32: 0x1418631c0, 6 |
| TESTopicInfo | 0x1418639f0 | 59 |  |

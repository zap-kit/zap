# Combat (118 classes, 265 template classes left out)

From the MSVC RTTI of `SkyrimSE.exe`: 7,831 type descriptors (`.?AV...@@` in `.data`), 8,457 complete object locators and 7,159 classes with a vtable in `.rdata`. Here the classes of the inn's systems with their primary vtable (the one at offset 0 of the object) and how many virtual functions follow it before the next vtable (the count includes the slots of the base classes; a class's own slots come last). A secondary vtable (a base at another offset) is listed with that offset. Template classes (`BSTEventSink<...>`, `ConcreteFormFactory<...>`, the behavior tree's `CombatBehaviorTreeNodeObject<...>`) are left out; their count is in the system's heading. The vtable's slot k holds the address of the virtual function, so a function is found as the vtable's address plus 8 k, and `procedure_pseudo_code` on that address gives its code.

The layouts to read a slot by name: CommonLibSSE-NG's headers declare each class's virtual functions in vtable order (`IMenu`: 0 destructor, 1 Accept(CallbackProcessor), 2 PostCreate, 3 Unk_03, 4 ProcessMessage(UIMessage), 5 AdvanceMovie(interval, currentTime), 6 PostDisplay, 7 PreDisplay, 8 RefreshPlatform).

| class | vtable | slots | other vtables (offset: address, slots) |
|---|---|---|---|
| ArrowProjectile | 0x14193c248 | 196 | 32: 0x14193c870, 2, 48: 0x14193c888, 2, 56: 0x14193c8a0, 19 |
| BGSAttackData | 0x1418c42e0 | 2 |  |
| BGSAttackDataForm | 0x1417f76f0 | 4 |  |
| BGSAttackDataMap | 0x1418c42f8 | 2 |  |
| BarrierProjectile | 0x14193cb90 | 194 | 32: 0x14193d1a8, 2, 48: 0x14193d1c0, 2, 56: 0x14193d1d8, 19 |
| BeamProjectile | 0x14193d630 | 194 | 32: 0x14193dc48, 2, 48: 0x14193dc60, 2, 56: 0x14193dc78, 19, 480: 0x14193dd18, 2 |
| CombatAimController | 0x141943e28 | 11 |  |
| CombatAimControllerBase | 0x141944600 | 5 |  |
| CombatApproachTargetSpeedController | 0x14195a878 | 6 |  |
| CombatArea | 0x141944790 | 12 |  |
| CombatAreaHoldPosition | 0x141944930 | 12 |  |
| CombatAreaRadius | 0x1419447f8 | 12 |  |
| CombatAreaReference | 0x141944860 | 12 |  |
| CombatAreaStandard | 0x1419448c8 | 12 |  |
| CombatBehaviorResource | 0x1419570e8 | 2 |  |
| CombatBehaviorTree | 0x1419574d8 | 1 |  |
| CombatBehaviorTreeAcquireWeapon | 0x1419577b0 | 1 |  |
| CombatBehaviorTreeAction | 0x141958320 | 1 |  |
| CombatBehaviorTreeActionEquipmentSelector | 0x141958348 | 1 |  |
| CombatBehaviorTreeBlock | 0x141959648 | 1 |  |
| CombatBehaviorTreeCheckUnreachableTarget | 0x141962668 | 1 |  |
| CombatBehaviorTreeCloseMovement | 0x141959d40 | 1 |  |
| CombatBehaviorTreeCombat | 0x1419574f8 | 1 |  |
| CombatBehaviorTreeDodgeThreat | 0x141959238 | 1 |  |
| CombatBehaviorTreeExitWater | 0x1419628a8 | 1 |  |
| CombatBehaviorTreeFindAttackLocation | 0x14195b6e0 | 1 |  |
| CombatBehaviorTreeFlankingMovement | 0x14195ca48 | 1 |  |
| CombatBehaviorTreeFlee | 0x14195de48 | 1 |  |
| CombatBehaviorTreeFlight | 0x14195fa40 | 1 |  |
| CombatBehaviorTreeHide | 0x14195e218 | 1 |  |
| CombatBehaviorTreeLinkNode | 0x141957480 | 10 |  |
| CombatBehaviorTreeLowCombat | 0x1419611e8 | 1 |  |
| CombatBehaviorTreeMagic | 0x1419615f8 | 1 |  |
| CombatBehaviorTreeMelee | 0x1419621d8 | 1 |  |
| CombatBehaviorTreeMovement | 0x141963b90 | 1 |  |
| CombatBehaviorTreeNode | 0x141957700 | 10 |  |
| CombatBehaviorTreeRanged | 0x1418ecda0 | 1 |  |
| CombatBehaviorTreeRangedMovement | 0x141963fa8 | 1 |  |
| CombatBehaviorTreeReturnToCombatArea | 0x141962690 | 1 |  |
| CombatBehaviorTreeRootNode | 0x141957428 | 10 |  |
| CombatBehaviorTreeSearch | 0x141964638 | 1 |  |
| CombatBehaviorTreeShout | 0x1419660a0 | 1 |  |
| CombatBehaviorTreeUseCover | 0x141966578 | 1 |  |
| CombatBehaviorTreeUsePotion | 0x1419672c8 | 1 |  |
| CombatBehaviorTreeWrapperNode | 0x141958650 | 10 |  |
| CombatBlackboardKeyBase | 0x141944f40 | 7 |  |
| CombatCoverLocation | 0x1419452d8 | 5 |  |
| CombatCoverSearch | 0x141945278 | 5 |  |
| CombatCoverSearchDebugData | 0x141945308 | 5 |  |
| CombatCoverSearchResult | 0x1419452a8 | 5 |  |
| CombatDisableActionController | 0x141962d30 | 5 |  |
| CombatDisableAimController | 0x141943fa8 | 11 |  |
| CombatFlankingSearchData | 0x14195ca70 | 5 |  |
| CombatGroupDetectionListener | 0x1419468f8 | 6 |  |
| CombatInventoryItem | 0x141947468 | 21 |  |
| CombatInventoryItemComposite | 0x141947518 | 21 |  |
| CombatInventoryItemMagic | 0x141948200 | 23 |  |
| CombatInventoryItemMelee | 0x1419475c8 | 21 |  |
| CombatInventoryItemOneHandedBlock | 0x1419477d8 | 21 |  |
| CombatInventoryItemPotion | 0x141949e40 | 23 |  |
| CombatInventoryItemRanged | 0x141947678 | 21 |  |
| CombatInventoryItemScroll | 0x141949f60 | 23 |  |
| CombatInventoryItemShield | 0x141947728 | 21 |  |
| CombatInventoryItemShout | 0x141949c20 | 23 |  |
| CombatInventoryItemStaff | 0x141949d20 | 23 |  |
| CombatInventoryItemTorch | 0x141947888 | 21 |  |
| CombatMagicCaster | 0x141953718 | 14 |  |
| CombatMagicCasterArmor | 0x14194bcf0 | 14 |  |
| CombatMagicCasterBoundItem | 0x14194bb78 | 14 |  |
| CombatMagicCasterCloak | 0x14194b6f0 | 14 |  |
| CombatMagicCasterDisarm | 0x14194b558 | 14 |  |
| CombatMagicCasterInvisibility | 0x14194ba00 | 14 |  |
| CombatMagicCasterLight | 0x14194b868 | 14 |  |
| CombatMagicCasterOffensive | 0x14194acc0 | 14 |  |
| CombatMagicCasterParalyze | 0x14194c200 | 14 |  |
| CombatMagicCasterReanimate | 0x1419538e0 | 14 |  |
| CombatMagicCasterRestore | 0x14194b0b0 | 14 |  |
| CombatMagicCasterScript | 0x14194c398 | 14 |  |
| CombatMagicCasterStagger | 0x14194b420 | 14 |  |
| CombatMagicCasterSummon | 0x14194b2a8 | 14 |  |
| CombatMagicCasterTargetEffect | 0x14194be88 | 14 |  |
| CombatMagicCasterWard | 0x14194ae58 | 14 |  |
| CombatMagicItemData | 0x1419536e8 | 2 |  |
| CombatMagicItemSkillChecker | 0x141953700 | 2 |  |
| CombatMeleeAimController | 0x141943ee8 | 11 |  |
| CombatNavmeshSearch | 0x1419685a8 | 8 |  |
| CombatObject | 0x1419445d0 | 5 |  |
| CombatPath | 0x1419547a0 | 13 |  |
| CombatPathBuilder | 0x141968530 | 4 |  |
| CombatPathBuilderOpen | 0x141968580 | 4 |  |
| CombatPathBuilderStandard | 0x141968558 | 4 |  |
| CombatPathSpeedController | 0x14195a820 | 6 |  |
| CombatPathingDebugData | 0x1419690c8 | 5 |  |
| CombatPathingRequest | 0x141954488 | 13 |  |
| CombatPathingRequestAdapter | 0x141968878 | 13 |  |
| CombatPathingRequestMultiGoal | 0x141968968 | 13 |  |
| CombatPathingRequestStandard | 0x141968808 | 13 |  |
| CombatProjectileAimController | 0x141943f48 | 11 |  |
| CombatSearchLockData | 0x141964b18 | 7 |  |
| CombatTargetLocation | 0x1419546c8 | 5 |  |
| CombatTargetLocationSearch | 0x1419546f8 | 5 |  |
| CombatTargetLocationSearchResult | 0x141954728 | 5 |  |
| CombatTargetSelector | 0x141955910 | 7 |  |
| CombatTargetSelectorFixed | 0x141955990 | 7 |  |
| CombatTargetSelectorStandard | 0x141955950 | 7 |  |
| CombatThreat | 0x141955f18 | 5 |  |
| CombatTrackTargetAimController | 0x141943e88 | 11 |  |
| ConeProjectile | 0x14193dea0 | 195 | 32: 0x14193e4c0, 2, 48: 0x14193e4d8, 2, 56: 0x14193e4f0, 19 |
| DetectionState | 0x141937990 | 2 |  |
| ExtraCombatStyle | 0x1417ea3b8 | 3 |  |
| FlameProjectile | 0x14193f360 | 194 | 32: 0x14193f978, 2, 48: 0x14193f990, 2, 56: 0x14193f9a8, 19 |
| GrenadeProjectile | 0x14193fb90 | 194 | 32: 0x1419401a8, 2, 48: 0x1419401c0, 2, 56: 0x1419401d8, 19 |
| MissileProjectile | 0x141940e58 | 196 | 32: 0x141941480, 2, 48: 0x141941498, 2, 56: 0x1419414b0, 19 |
| Projectile | 0x141942a10 | 194 | 32: 0x141943028, 2, 48: 0x141943040, 2, 56: 0x141943058, 19 |
| Projectile::LaunchData | 0x1417f63b0 | 1 |  |
| ProjectilePickCache | 0x1419429f8 | 2 |  |
| TESCombatStyle | 0x141810538 | 59 |  |
| bhkCollisionObject | 0x141828388 | 49 |  |

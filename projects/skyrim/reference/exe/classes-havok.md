# Havok (the physics) (473 classes, 0 template classes left out)

From the MSVC RTTI of `SkyrimSE.exe`: 7,831 type descriptors (`.?AV...@@` in `.data`), 8,457 complete object locators and 7,159 classes with a vtable in `.rdata`. Here the classes of the inn's systems with their primary vtable (the one at offset 0 of the object) and how many virtual functions follow it before the next vtable (the count includes the slots of the base classes; a class's own slots come last). A secondary vtable (a base at another offset) is listed with that offset. Template classes (`BSTEventSink<...>`, `ConcreteFormFactory<...>`, the behavior tree's `CombatBehaviorTreeNodeObject<...>`) are left out; their count is in the system's heading. The vtable's slot k holds the address of the virtual function, so a function is found as the vtable's address plus 8 k, and `procedure_pseudo_code` on that address gives its code.

The layouts to read a slot by name: CommonLibSSE-NG's headers declare each class's virtual functions in vtable order (`IMenu`: 0 destructor, 1 Accept(CallbackProcessor), 2 PostCreate, 3 Unk_03, 4 ProcessMessage(UIMessage), 5 AdvanceMovie(interval, currentTime), 6 PostDisplay, 7 PreDisplay, 8 RefreshPlatform).

| class | vtable | slots | other vtables (offset: address, slots) |
|---|---|---|---|
| bhkAabbPhantom | 0x141827460 | 51 |  |
| bhkAcousticSpacePhantomCallbackShape | 0x141827db8 | 13 |  |
| bhkAction | 0x141865328 | 51 |  |
| bhkAngularDashpotAction | 0x141a90608 | 54 |  |
| bhkAttachmentCollisionObject | 0x141a826d0 | 49 |  |
| bhkAvoidBox | 0x141a85518 | 51 |  |
| bhkBackfaceContactListener | 0x141866530 | 7 |  |
| bhkBallAndSocketConstraint | 0x141a8a0c0 | 55 |  |
| bhkBallSocketConstraintChain | 0x141a8e688 | 56 |  |
| bhkBinaryAction | 0x141a90450 | 54 |  |
| bhkBipedOrientationController | 0x141a8ab30 | 11 |  |
| bhkBlendCollisionObject | 0x141a85198 | 49 |  |
| bhkBlendController | 0x141a917c0 | 47 |  |
| bhkBoxShape | 0x141828d48 | 54 |  |
| bhkBreakableConstraint | 0x141a90128 | 55 |  |
| bhkBvTreeShape | 0x141865eb0 | 54 |  |
| bhkCachingShapePhantom | 0x141a88de0 | 51 |  |
| bhkCapsuleShape | 0x141a844f8 | 54 |  |
| bhkCartTether | 0x141864db8 | 49 |  |
| bhkCharControllerShape | 0x141a92a38 | 54 |  |
| bhkCharProxyController | 0x141a89540 | 6 | 16: 0x141a89578, 20 |
| bhkCharProxyControllerCinfo | 0x141a89508 | 6 |  |
| bhkCharRigidBodyController | 0x141a89bf0 | 20 | 816: 0x141a89c98, 8 |
| bhkCharRigidBodyControllerCinfo | 0x141a89bb8 | 6 |  |
| bhkCharacterCollisionHandler | 0x14192e428 | 2 |  |
| bhkCharacterController | 0x141a7f7a0 | 20 |  |
| bhkCharacterControllerCinfo | 0x141a7f768 | 6 |  |
| bhkCharacterPointCollector | 0x141a96730 | 3 |  |
| bhkCharacterProxy | 0x141a89370 | 50 |  |
| bhkCharacterProxyCinfo | 0x141a89350 | 3 |  |
| bhkCharacterRigidBody | 0x141a899d8 | 50 |  |
| bhkCharacterRigidBodyCinfo | 0x141a899b8 | 3 |  |
| bhkCharacterState | 0x141a7f718 | 9 |  |
| bhkCharacterStateClimbing | 0x141a7f8a8 | 9 |  |
| bhkCharacterStateFlying | 0x141a7f8f8 | 9 |  |
| bhkCharacterStateInAir | 0x141a925c8 | 9 |  |
| bhkCharacterStateJumping | 0x141a92640 | 9 |  |
| bhkCharacterStateOnGround | 0x141a92808 | 9 |  |
| bhkCharacterStateSwimming | 0x141a92888 | 9 |  |
| bhkCollisionBox | 0x141a7f948 | 52 |  |
| bhkCollisionFilter | 0x141a825f0 | 4 | 16: 0x141a82618, 2, 24: 0x141a82630, 4, 32: 0x141a82658, 2, 40: 0x141a82670, 2 |
| bhkCompressedMeshShape | 0x141a8b820 | 55 |  |
| bhkCompressedMeshShapeData | 0x141a8b6f0 | 37 |  |
| bhkConstraint | 0x141864f78 | 55 |  |
| bhkConstraintChain | 0x141a8e490 | 56 |  |
| bhkContactListener | 0x1418664f0 | 7 |  |
| bhkConvexShape | 0x141827fe0 | 54 |  |
| bhkConvexSweepShape | 0x141a8bb98 | 54 |  |
| bhkConvexTransformShape | 0x141a8bf08 | 54 |  |
| bhkConvexTranslateShape | 0x141a8c278 | 54 |  |
| bhkConvexVerticesShape | 0x141a8c688 | 54 |  |
| bhkCylinderShape | 0x141a8c9f8 | 54 |  |
| bhkDashpotAction | 0x141a90900 | 54 |  |
| bhkEntity | 0x141827120 | 51 |  |
| bhkEntityListener | 0x141863d40 | 10 |  |
| bhkExtraData | 0x141a91ba0 | 39 |  |
| bhkFilteredCdBodyCollector | 0x14191d450 | 3 |  |
| bhkFixedConstraint | 0x141a8f298 | 55 |  |
| bhkGenericConstraint | 0x141a8f0d8 | 55 |  |
| bhkGroupConstraint | 0x141a8e990 | 55 |  |
| bhkHeightFieldShape | 0x141a8d0d8 | 54 |  |
| bhkHingeConstraint | 0x141941580 | 55 |  |
| bhkHingeLimitsConstraint | 0x141a8ed38 | 55 |  |
| bhkICharOrientationController | 0x141a7f848 | 11 |  |
| bhkIWorldStepListener | 0x141a06300 | 3 |  |
| bhkLimitedHingeConstraint | 0x141a82c38 | 55 |  |
| bhkLiquidAction | 0x141a90c20 | 51 |  |
| bhkListShape | 0x141a7fcb0 | 55 |  |
| bhkMalleableConstraint | 0x141a85b30 | 55 |  |
| bhkMemorySystem | 0x141a8add0 | 23 |  |
| bhkMoppBvTreeShape | 0x141a8d9c0 | 54 |  |
| bhkMotorAction | 0x141a90f28 | 51 |  |
| bhkMouseSpringAction | 0x14192a358 | 51 |  |
| bhkMultiSphereShape | 0x141a8cdb8 | 54 |  |
| bhkNiCollisionObject | 0x141a80058 | 49 |  |
| bhkNiTriStripsShape | 0x141a84be8 | 55 |  |
| bhkObstacleDeactivationListener | 0x1418dbc78 | 3 |  |
| bhkObstacleRemovalListener | 0x1418dbc98 | 6 |  |
| bhkOnExitCallback | 0x141a7c370 | 2 |  |
| bhkOnStartupCallback | 0x141a7c358 | 2 |  |
| bhkOrientHingedBodyAction | 0x141a91230 | 52 |  |
| bhkPCollisionObject | 0x141828518 | 49 |  |
| bhkPackedNiTriStripsShape | 0x141a84f60 | 55 |  |
| bhkPhantom | 0x1418272c0 | 51 |  |
| bhkPlaneShape | 0x141a8d290 | 54 |  |
| bhkPointToPathConstraint | 0x141a97c68 | 55 |  |
| bhkPoseArray | 0x141a91df8 | 37 |  |
| bhkPositionConstraintMotor | 0x141a93398 | 25 |  |
| bhkPrismaticConstraint | 0x141865168 | 55 |  |
| bhkQuadOrientationController | 0x141a92d08 | 11 |  |
| bhkRagdollConstraint | 0x141a8a528 | 55 |  |
| bhkRagdollController | 0x141a82090 | 3 |  |
| bhkRagdollLimitsConstraint | 0x141a8f7a8 | 55 |  |
| bhkRagdollPenetrationUtil | 0x141a7ebe8 | 2 |  |
| bhkRagdollShareData | 0x141a81f60 | 37 |  |
| bhkRagdollTemplate | 0x141a8a3b0 | 40 |  |
| bhkRagdollTemplateData | 0x141a8a280 | 37 |  |
| bhkRefObject | 0x141a83508 | 39 |  |
| bhkRigidBody | 0x141828198 | 61 |  |
| bhkRigidBodyT | 0x141a82ef8 | 61 |  |
| bhkSPCollisionObject | 0x14193d278 | 49 |  |
| bhkSerializable | 0x141826cd0 | 50 |  |
| bhkShape | 0x141826ec8 | 54 |  |
| bhkShapeCollection | 0x141a7faf0 | 55 |  |
| bhkShapePhantom | 0x1418286a8 | 51 |  |
| bhkSimpleShapePhantom | 0x141828848 | 51 |  |
| bhkSphereRepShape | 0x141827e28 | 54 |  |
| bhkSphereShape | 0x141828f00 | 54 |  |
| bhkSpringAction | 0x141a91540 | 54 |  |
| bhkSpringDamperConstraintMotor | 0x141a935c8 | 25 |  |
| bhkStiffSpringConstraint | 0x141a7d988 | 55 |  |
| bhkTaskletManagerCallback | 0x141a7c340 | 2 |  |
| bhkTelekinesisListener | 0x141914188 | 7 |  |
| bhkThreadMemorySource | 0x141a96e60 | 11 | 8: 0x141a96ec0, 15 |
| bhkTransformShape | 0x141a8dd58 | 54 |  |
| bhkTrapListener | 0x141867db8 | 10 | 24: 0x141867e10, 5 |
| bhkTriSampledHeightFieldBvTreeShape | 0x141866068 | 54 |  |
| bhkTriangleShape | 0x141a8d588 | 54 |  |
| bhkUnaryAction | 0x1418654c8 | 51 |  |
| bhkVelocityConstraintMotor | 0x141a934b0 | 25 |  |
| bhkWheelConstraint | 0x141a8fcb8 | 55 |  |
| bhkWindListener | 0x141a7e478 | 11 |  |
| bhkWorld | 0x141a7cda8 | 55 |  |
| bhkWorld::bhkConstraintProjector | 0x141a7cd68 | 7 |  |
| bhkWorldCinfo | 0x141824020 | 3 |  |
| bhkWorldM | 0x141a831e8 | 55 |  |
| bhkWorldObject | 0x141a7b808 | 51 |  |
| hkBaseObject | 0x141820b98 | 1 |  |
| hkClassNameRegistry | 0x1419e58b8 | 6 |  |
| hkContainerDebugAllocator::Allocator | 0x1419ba430 | 11 |  |
| hkContainerHeapAllocator::Allocator | 0x1419ba3d0 | 11 |  |
| hkContainerResourceMap | 0x1419e6750 | 2 |  |
| hkContainerTempAllocator::Allocator | 0x1419ba370 | 11 |  |
| hkMemoryAllocator | 0x1419ba2b0 | 11 |  |
| hkMemoryResourceContainer | 0x1419e66c8 | 16 |  |
| hkMemoryResourceHandle | 0x1419e6650 | 14 |  |
| hkMemoryStreamReader | 0x141a1b928 | 12 |  |
| hkMemorySystem | 0x1419c03c8 | 23 |  |
| hkMemoryTrackStreamReader | 0x1419bfb10 | 12 |  |
| hkMemoryTrackStreamWriter | 0x1419bf0c0 | 10 |  |
| hkMemoryTracker | 0x1419c0310 | 9 |  |
| hkReferencedObject | 0x141820ba8 | 3 |  |
| hkReferencedObjectLock | 0x1419ba278 | 3 |  |
| hkResource | 0x141a12040 | 8 |  |
| hkResourceBase | 0x1419e6508 | 5 |  |
| hkResourceContainer | 0x1419e65b0 | 16 |  |
| hkResourceHandle | 0x1419e6538 | 14 |  |
| hkResourceMap | 0x1419e6638 | 2 |  |
| hkaAnimatedReferenceFrame | 0x141a0b800 | 6 |  |
| hkaAnimation | 0x141a0b838 | 16 |  |
| hkaAnimationBinding | 0x141a04fb0 | 3 |  |
| hkaAnimationContainer | 0x141a0c260 | 3 |  |
| hkaAnimationControl | 0x141a0d578 | 14 |  |
| hkaAnimationPreviewColorContainer | 0x141a0bd88 | 3 |  |
| hkaBoneAttachment | 0x141a0c1b0 | 3 |  |
| hkaDefaultAnimatedReferenceFrame | 0x141a0c048 | 6 |  |
| hkaDefaultAnimationControl | 0x141a09e38 | 14 |  |
| hkaDefaultAnimationControlMapperData | 0x141a09eb0 | 3 |  |
| hkaDetectRagdollPenetration | 0x141a922e8 | 3 |  |
| hkaFootPlacementIkSolver | 0x1419ba1e8 | 3 |  |
| hkaFootstepAnalysisInfo | 0x141a162a8 | 3 |  |
| hkaFootstepAnalysisInfoContainer | 0x141a0c0f0 | 3 |  |
| hkaInterleavedUncompressedAnimation | 0x141a0b998 | 16 |  |
| hkaMeshBinding | 0x141a16148 | 3 |  |
| hkaMirroredSkeleton | 0x141a0d430 | 3 |  |
| hkaQuantizedAnimation | 0x141a0ba70 | 16 |  |
| hkaRagdollInstance | 0x141a09e10 | 4 |  |
| hkaRagdollRaycastInterface | 0x141a7ebd0 | 2 |  |
| hkaRaycastInterface | 0x1418e9d00 | 3 |  |
| hkaSkeleton | 0x141a07ce0 | 3 |  |
| hkaSkeletonMapper | 0x141a09ad8 | 3 |  |
| hkaSplineCompressedAnimation | 0x141a0bb88 | 16 |  |
| hkp3AxisSweep | 0x141a0ff38 | 31 |  |
| hkpAabbPhantom | 0x1419ebce8 | 15 |  |
| hkpAction | 0x1419ebee8 | 8 |  |
| hkpAllCdBodyPairCollector | 0x14191d430 | 3 |  |
| hkpAllCdBodyPairTempCollector | 0x141867f78 | 3 |  |
| hkpAllCdPointCollector | 0x141867190 | 3 |  |
| hkpAllCdPointTempCollector | 0x1418683e8 | 3 |  |
| hkpAllRayHitCollector | 0x141a7ebb8 | 2 |  |
| hkpAllRayHitTempCollector | 0x1417fde48 | 2 |  |
| hkpAngularDashpotAction | 0x1419f9fc0 | 8 |  |
| hkpArrayAction | 0x141a1b258 | 8 |  |
| hkpBallAndSocketConstraintData | 0x1419f2a20 | 19 |  |
| hkpBallGun | 0x1419fb268 | 9 |  |
| hkpBallSocketChainData | 0x1419f5b68 | 20 |  |
| hkpBinaryAction | 0x1419f9f78 | 8 |  |
| hkpBoxBoxAgent | 0x141a19a50 | 14 |  |
| hkpBoxMotion | 0x1419eb900 | 26 |  |
| hkpBoxShape | 0x1419e6e00 | 18 |  |
| hkpBreakableConstraintData | 0x1419f5a20 | 19 |  |
| hkpBroadPhase | 0x141a10078 | 31 |  |
| hkpBroadPhaseBorder | 0x1419f5f60 | 5 | 16: 0x1419f5f90, 3, 24: 0x1419f5fb0, 3, 32: 0x1419f5fd0, 3 |
| hkpBroadPhaseBorderListener | 0x1419f4fb8 | 3 | 16: 0x1419f4fd8, 3 |
| hkpBroadPhaseCastCollector | 0x1419f4ef8 | 2 |  |
| hkpBroadPhaseListener | 0x1419f4ed8 | 3 |  |
| hkpBvAgent | 0x141a19b38 | 14 |  |
| hkpBvShape | 0x1419e6bf8 | 11 |  |
| hkpBvTreeAgent | 0x141a19d08 | 14 |  |
| hkpBvTreeShape | 0x1419e9cd8 | 13 |  |
| hkpBvTreeStreamAgent | 0x141a19ea8 | 14 |  |
| hkpCachingShapePhantom | 0x1419f4688 | 19 |  |
| hkpCallbackConstraintMotor | 0x1419f3e78 | 4 |  |
| hkpCapsuleCapsuleAgent | 0x141a1a570 | 14 |  |
| hkpCapsuleShape | 0x1419e7248 | 18 |  |
| hkpCapsuleTriangleAgent | 0x141a1a5f8 | 14 |  |
| hkpCdBodyPairCollector | 0x141867d68 | 3 |  |
| hkpCdPointCollector | 0x141867170 | 3 |  |
| hkpCharacterContext | 0x1419f6900 | 3 |  |
| hkpCharacterControllerCinfo | 0x1419e4a60 | 3 |  |
| hkpCharacterMotion | 0x1419ebab0 | 26 |  |
| hkpCharacterProxy | 0x1419fae40 | 5 | 16: 0x1419fae70, 6, 24: 0x1419faea8, 5 |
| hkpCharacterProxyCinfo | 0x1419e4a80 | 3 |  |
| hkpCharacterProxyListener | 0x141a89318 | 6 |  |
| hkpCharacterRigidBody | 0x1419f69b0 | 6 | 16: 0x1419f69e8, 6, 24: 0x1419f6a20, 3 |
| hkpCharacterRigidBodyCinfo | 0x1419fa2a8 | 3 |  |
| hkpCharacterRigidBodyListener | 0x141a89b70 | 8 |  |
| hkpCharacterState | 0x141a7f6d0 | 8 |  |
| hkpCharacterStateManager | 0x1419f6990 | 3 |  |
| hkpClosestCdPointCollector | 0x1419568f0 | 3 |  |
| hkpClosestRayHitCollector | 0x141867638 | 2 |  |
| hkpCogWheelConstraintData | 0x1419f2b50 | 19 |  |
| hkpCollidableCollidableFilter | 0x1419e68b0 | 2 |  |
| hkpCollidableMediator | 0x141a996c0 | 6 |  |
| hkpCollisionAgent | 0x1419e76c8 | 14 |  |
| hkpCollisionCallbackUtil | 0x1419f4ff8 | 5 | 32: 0x1419f5028, 7 |
| hkpCollisionDispatcher | 0x1419e6840 | 3 |  |
| hkpCollisionFilter | 0x1419e77b8 | 4 | 16: 0x1419e77e0, 2, 24: 0x1419e77f8, 4, 32: 0x1419e7820, 2, 40: 0x1419e7838, 2 |
| hkpCollisionFilterList | 0x1419e99e8 | 4 | 16: 0x1419e9a10, 2, 24: 0x1419e9a28, 4, 32: 0x1419e9a50, 2, 40: 0x1419e9a68, 2 |
| hkpCompressedMeshShape | 0x141a97020 | 13 | 32: 0x141a97090, 7 |
| hkpCompressedSampledHeightFieldShape | 0x1419eabc0 | 15 |  |
| hkpConstrainedSystemFilter | 0x1419fa490 | 4 | 16: 0x1419fa4b8, 2, 24: 0x1419fa4d0, 4, 32: 0x1419fa4f8, 2, 40: 0x1419fa510, 2, 72: 0x1419fa528, 7 |
| hkpConstraintChainData | 0x1419f5ac0 | 20 |  |
| hkpConstraintChainInstance | 0x1419f3bf0 | 7 |  |
| hkpConstraintChainInstanceAction | 0x1419f3c70 | 8 |  |
| hkpConstraintCollisionFilter | 0x1419f27d8 | 4 | 16: 0x1419f2800, 2, 24: 0x1419f2818, 4, 32: 0x1419f2840, 2, 40: 0x1419f2858, 2, 96: 0x1419f2870, 7 |
| hkpConstraintData | 0x1419ebda8 | 19 |  |
| hkpConstraintInstance | 0x1419f2628 | 7 |  |
| hkpConstraintListener | 0x1419f2798 | 7 |  |
| hkpConstraintMotor | 0x1419f3e28 | 4 |  |
| hkpConstraintOwner | 0x1419f5600 | 7 |  |
| hkpConstraintUtils::CollectConstraintsFilter | 0x141a126a8 | 2 |  |
| hkpContactListener | 0x1418664b0 | 7 |  |
| hkpContactMgr | 0x1419f4e00 | 10 |  |
| hkpContactMgrFactory | 0x1419f4dc0 | 4 |  |
| hkpContinuousSimulation | 0x141a96198 | 22 |  |
| hkpConvexListAgent | 0x141a1ad30 | 14 |  |
| hkpConvexListFilter | 0x1419e6860 | 4 |  |
| hkpConvexListShape | 0x1419ea250 | 18 | 40: 0x1419ea2e8, 7 |
| hkpConvexPieceStreamData | 0x1419f6798 | 3 |  |
| hkpConvexShape | 0x1419e6d68 | 18 |  |
| hkpConvexTransformShape | 0x1419e9ed8 | 18 |  |
| hkpConvexTransformShapeBase | 0x1419e6ea0 | 18 |  |
| hkpConvexTranslateShape | 0x1419e9fa8 | 18 |  |
| hkpConvexVerticesConnectivity | 0x1419ea078 | 4 |  |
| hkpConvexVerticesShape | 0x141a11f18 | 18 |  |
| hkpCylinderShape | 0x1419eb208 | 18 |  |
| hkpDashpotAction | 0x1419fa040 | 8 |  |
| hkpDefaultConvexListFilter | 0x1419e6888 | 4 |  |
| hkpDefaultToiResourceMgr | 0x141a97f80 | 8 |  |
| hkpDefaultWorldMaintenanceMgr | 0x1419f6350 | 6 |  |
| hkpDefaultWorldMemoryWatchDog | 0x1419f4898 | 6 |  |
| hkpDeferredConstraintOwner | 0x141a98158 | 7 |  |
| hkpDisableEntityCollisionFilter | 0x1419fa5a8 | 4 | 16: 0x1419fa5d0, 2, 24: 0x1419fa5e8, 4, 32: 0x1419fa610, 2, 40: 0x1419fa628, 2, 72: 0x1419fa640, 6 |
| hkpDisplayBindingData | 0x1419fab38 | 3 |  |
| hkpDisplayBindingData::PhysicsSystem | 0x1419fab18 | 3 |  |
| hkpDisplayBindingData::RigidBody | 0x1419faaf8 | 3 |  |
| hkpDynamicsContactMgr | 0x1419f5ff0 | 19 |  |
| hkpEaseConstraintsAction | 0x141a126d8 | 8 |  |
| hkpEaseConstraintsAction::CollectSupportedConstraints | 0x141a126c0 | 2 |  |
| hkpEasePenetrationAction | 0x141a12920 | 8 |  |
| hkpEndOfStepCallbackUtil | 0x1419f63e0 | 3 | 16: 0x1419f6400, 3 |
| hkpEntity | 0x1419eb6f8 | 7 |  |
| hkpEntityActivationListener | 0x1418dbc58 | 3 |  |
| hkpEntityEntityBroadPhaseListener | 0x1419f5df8 | 3 | 16: 0x1419f5e18, 3 |
| hkpEntityListener | 0x141823fe8 | 6 |  |
| hkpExtendedMeshShape | 0x141a16e90 | 15 | 32: 0x141a16f10, 7 |
| hkpFastMeshShape | 0x141a10cf0 | 14 | 32: 0x141a10d68, 7 |
| hkpFirstCdBodyPairCollector | 0x14192a4f8 | 3 |  |
| hkpFirstPersonGun | 0x1419fb218 | 9 |  |
| hkpFixedBufferCdPointCollector | 0x14193f248 | 3 |  |
| hkpFixedBufferRayHitCollector | 0x141a987e8 | 2 |  |
| hkpFixedRigidMotion | 0x1419eb738 | 29 |  |
| hkpFlagCdBodyPairCollector | 0x141a19bb0 | 3 |  |
| hkpGenericConstraintData | 0x1419f5cb8 | 19 |  |
| hkpGravityGun | 0x1419fb2d8 | 9 |  |
| hkpGroupCollisionFilter | 0x1419fa6c0 | 4 | 16: 0x1419fa6e8, 2, 24: 0x1419fa700, 4, 32: 0x1419fa728, 2, 40: 0x1419fa740, 2 |
| hkpGroupFilter | 0x1419e72f0 | 5 | 16: 0x1419e7320, 2, 24: 0x1419e7338, 4, 32: 0x1419e7360, 2, 40: 0x1419e7378, 2 |
| hkpGskBaseAgent | 0x141a1ee58 | 14 |  |
| hkpGskfAgent | 0x141a1eef0 | 14 |  |
| hkpGunProjectile | 0x1419fb3c8 | 6 | 16: 0x1419fb400, 7 |
| hkpHavokSnapshot::ConvertListener | 0x1419f6948 | 4 |  |
| hkpHeightFieldAgent | 0x141a95f60 | 14 |  |
| hkpHeightFieldShape | 0x1419e7088 | 13 |  |
| hkpHingeConstraintData | 0x1419f2c78 | 19 |  |
| hkpHingeLimitsData | 0x1419f3930 | 19 |  |
| hkpIslandActivationListener | 0x141866678 | 3 |  |
| hkpIterativeLinearCastAgent | 0x141a199d8 | 14 |  |
| hkpKeyframedRigidMotion | 0x1419eb528 | 28 |  |
| hkpLimitedForceConstraintMotor | 0x1419f3e50 | 4 |  |
| hkpLimitedHingeConstraintData | 0x1419f2d88 | 19 |  |
| hkpLinearParametricCurve | 0x1419f2f30 | 14 |  |
| hkpListAgent | 0x141a1abc8 | 14 |  |
| hkpListShape | 0x1419eb078 | 13 | 32: 0x1419eb0e8, 7 |
| hkpMalleableConstraintData | 0x1419f5d58 | 19 |  |
| hkpMapPointsToSubShapeContactMgr | 0x141a11c10 | 10 |  |
| hkpMaxSizeMotion | 0x1419eb610 | 28 |  |
| hkpMeshShape | 0x141a16dc8 | 14 | 32: 0x141a16e40, 7 |
| hkpMoppAgent | 0x141a1a100 | 14 |  |
| hkpMoppAssembler | 0x141a98b88 | 7 |  |
| hkpMoppBvTreeShape | 0x1419e9dc0 | 14 |  |
| hkpMoppCachedShapeMediator | 0x141a98398 | 10 |  |
| hkpMoppCode | 0x141820be0 | 3 |  |
| hkpMoppCodeGenerator | 0x141a98b68 | 3 |  |
| hkpMoppCostFunction | 0x141a983f0 | 3 |  |
| hkpMoppDefaultAssembler | 0x141a98bc8 | 7 |  |
| hkpMoppDefaultSplitter | 0x141a98ab0 | 6 |  |
| hkpMoppMediator | 0x141a982e8 | 10 |  |
| hkpMoppModifier | 0x1419e9c38 | 3 |  |
| hkpMoppNodeMgr | 0x141a98a48 | 5 |  |
| hkpMoppShapeMediator | 0x141a98340 | 10 |  |
| hkpMoppSplitter | 0x141a98a78 | 6 |  |
| hkpMotion | 0x1419eb450 | 26 |  |
| hkpMotorAction | 0x1419fa0b8 | 8 |  |
| hkpMountedBallGun | 0x1419fb358 | 9 |  |
| hkpMouseSpringAction | 0x1419f6a78 | 8 |  |
| hkpMultiRayConvexAgent | 0x141a1a928 | 14 |  |
| hkpMultiRayShape | 0x1419ea430 | 11 |  |
| hkpMultiSphereAgent | 0x141a1af70 | 14 |  |
| hkpMultiSphereShape | 0x1419ea358 | 13 |  |
| hkpMultiSphereTriangleAgent | 0x141a1a808 | 14 |  |
| hkpMultiThreadedSimulation | 0x141a964b8 | 22 |  |
| hkpMultiThreadedSimulation::MtBroadPhaseBorderListener | 0x141a96498 | 3 |  |
| hkpMultiThreadedSimulation::MtEntityEntityBroadPhaseListener | 0x141a96458 | 3 |  |
| hkpMultiThreadedSimulation::MtPhantomBroadPhaseListener | 0x141a96478 | 3 |  |
| hkpNullAgent | 0x1419e7740 | 14 |  |
| hkpNullBroadPhaseListener | 0x141a0fe30 | 3 | 16: 0x141a0fe50, 3 |
| hkpNullCollisionFilter | 0x1419e6920 | 4 | 16: 0x1419e6948, 2, 24: 0x1419e6960, 4, 32: 0x1419e6988, 2, 40: 0x1419e69a0, 2 |
| hkpNullContactMgr | 0x1419f4e58 | 10 |  |
| hkpNullContactMgrFactory | 0x1419f4eb0 | 4 |  |
| hkpPairCollisionFilter | 0x1419f2700 | 4 | 16: 0x1419f2728, 2, 24: 0x1419f2740, 4, 32: 0x1419f2768, 2, 40: 0x1419f2780, 2 |
| hkpParametricCurve | 0x1419f2eb8 | 14 |  |
| hkpPhantom | 0x1419ebc68 | 15 |  |
| hkpPhantomAgent | 0x141a1a270 | 14 |  |
| hkpPhantomBroadPhaseListener | 0x1419f4f78 | 3 | 16: 0x1419f4f98, 3 |
| hkpPhantomCallbackShape | 0x1418270b0 | 13 |  |
| hkpPhantomListener | 0x141867d88 | 5 |  |
| hkpPhantomOverlapListener | 0x1419f5f20 | 3 |  |
| hkpPhysicsData | 0x1419fac20 | 3 |  |
| hkpPhysicsSystem | 0x1419f4a70 | 5 |  |
| hkpPhysicsSystemWithContacts | 0x1419fa790 | 5 |  |
| hkpPlaneShape | 0x1419e70f8 | 13 |  |
| hkpPointToPathConstraintData | 0x1419f3000 | 19 |  |
| hkpPointToPlaneConstraintData | 0x1419f30f0 | 19 |  |
| hkpPositionConstraintMotor | 0x1419f3f10 | 4 |  |
| hkpPoweredChainData | 0x141a11e48 | 20 |  |
| hkpPoweredChainMapper | 0x1419fa3b8 | 3 |  |
| hkpPredGskfAgent | 0x141a19958 | 14 |  |
| hkpPrismaticConstraintData | 0x1419ebe48 | 19 |  |
| hkpProjectileGun | 0x1419fb440 | 11 |  |
| hkpPulleyConstraintData | 0x1419f4080 | 19 |  |
| hkpRackAndPinionConstraintData | 0x1419f32a8 | 19 |  |
| hkpRagdollConstraintData | 0x1419f33d8 | 19 |  |
| hkpRagdollLimitsData | 0x1419f3a38 | 19 |  |
| hkpRayCollidableFilter | 0x1419e68c8 | 2 |  |
| hkpRayHitCollector | 0x1417fde30 | 2 |  |
| hkpRayShapeCollectionFilter | 0x1419e6908 | 2 |  |
| hkpRemoveTerminalsMoppModifier | 0x1419e9c58 | 3 | 16: 0x1419e9c78, 3 |
| hkpRemoveTerminalsMoppModifier2 | 0x1419eb158 | 3 | 16: 0x1419eb178, 3 |
| hkpReorientAction | 0x1419fa150 | 8 |  |
| hkpReportContactMgr | 0x1419f6278 | 19 |  |
| hkpReportContactMgr::Factory | 0x1419f6250 | 4 |  |
| hkpRigidBody | 0x1419ebbe8 | 8 |  |
| hkpRotationalConstraintData | 0x1419f3740 | 19 |  |
| hkpSafeEaseConstraintsAction | 0x141a8aaa8 | 8 | 104: 0x141a8aaf0, 7 |
| hkpSampledHeightFieldShape | 0x1419eab40 | 15 |  |
| hkpSaveContactPointsUtil::EntitySelector | 0x1419fb4a0 | 2 |  |
| hkpSerializedAgentNnEntry | 0x1419fa800 | 3 |  |
| hkpSerializedDisplayMarker | 0x1419fa958 | 3 |  |
| hkpSerializedDisplayMarkerList | 0x1419fa9b8 | 3 |  |
| hkpSerializedDisplayRbTransforms | 0x1419faa18 | 3 |  |
| hkpShape | 0x141826e68 | 11 |  |
| hkpShapeCollection | 0x1419eade8 | 13 | 32: 0x1419eae58, 7 |
| hkpShapeCollectionAgent | 0x141a1aee0 | 14 |  |
| hkpShapeCollectionFilter | 0x1419e68e0 | 4 |  |
| hkpShapeContainer | 0x1419e6b78 | 7 |  |
| hkpShapeInfo | 0x1419ea630 | 3 |  |
| hkpShapePhantom | 0x1419f45e8 | 19 |  |
| hkpSimpleClosestContactCollector | 0x141a19bd0 | 3 |  |
| hkpSimpleConstraintContactMgr | 0x1419f6168 | 20 |  |
| hkpSimpleConstraintContactMgr::Factory | 0x1419f6140 | 4 |  |
| hkpSimpleContactConstraintData | 0x1419f6090 | 21 |  |
| hkpSimpleMeshShape | 0x141a98958 | 13 | 32: 0x141a989c8, 7 |
| hkpSimpleShapePhantom | 0x1419f4778 | 19 |  |
| hkpSimpleWorldRayCaster | 0x1419f4f10 | 2 |  |
| hkpSimulation | 0x1419f4930 | 19 |  |
| hkpSimulationIsland | 0x1419f5e38 | 7 |  |
| hkpSingleShapeContainer | 0x1419e6bb8 | 7 |  |
| hkpSphereBoxAgent | 0x141a1a708 | 14 |  |
| hkpSphereCapsuleAgent | 0x141a1a370 | 14 |  |
| hkpSphereMotion | 0x1419eb828 | 26 |  |
| hkpSphereRepShape | 0x1419e6cf8 | 13 |  |
| hkpSphereShape | 0x1419e7178 | 18 |  |
| hkpSphereSphereAgent | 0x141a1a2e8 | 14 |  |
| hkpSphereTriangleAgent | 0x141a1a470 | 14 |  |
| hkpSpringAction | 0x1419fa1c8 | 8 |  |
| hkpSpringDamperConstraintMotor | 0x1419f3f78 | 4 |  |
| hkpStiffSpringChainData | 0x1419f5c10 | 20 |  |
| hkpStiffSpringConstraintData | 0x1419f3500 | 19 |  |
| hkpStorageExtendedMeshShape | 0x141a10478 | 15 | 32: 0x141a104f8, 7 |
| hkpStorageExtendedMeshShape::MeshSubpartStorage | 0x141a10438 | 3 |  |
| hkpStorageExtendedMeshShape::ShapeSubpartStorage | 0x141a10458 | 3 |  |
| hkpStorageMeshShape | 0x141a10378 | 14 | 32: 0x141a103f0, 7 |
| hkpStorageMeshShape::SubpartStorage | 0x141a10358 | 3 |  |
| hkpStorageSampledHeightFieldShape | 0x1419ead18 | 15 |  |
| hkpSuspendInactiveAgentsUtil | 0x141a8b060 | 3 | 16: 0x141a8b080, 3, 24: 0x141a8b0a0, 3 |
| hkpSymmetricAgentFlipBodyCollector | 0x141a19b18 | 3 |  |
| hkpSymmetricAgentFlipCastCollector | 0x141a19af8 | 3 |  |
| hkpSymmetricAgentFlipCollector | 0x141a19ad8 | 3 |  |
| hkpThinBoxMotion | 0x1419eb9d8 | 26 |  |
| hkpToiResourceMgr | 0x141a97f38 | 8 |  |
| hkpTransformAgent | 0x141a1aa40 | 14 |  |
| hkpTransformShape | 0x1419ea508 | 11 |  |
| hkpTriSampledHeightFieldBvTreeShape | 0x1419eae98 | 14 |  |
| hkpTriSampledHeightFieldCollection | 0x1419eaf10 | 13 | 32: 0x1419eaf80, 7 |
| hkpTriangleShape | 0x1419ea130 | 18 |  |
| hkpTriggerVolume | 0x1419fb010 | 5 | 16: 0x1419fb040, 7, 24: 0x1419fb080, 3, 32: 0x1419fb0a0, 6 |
| hkpUnaryAction | 0x1419ebf30 | 8 |  |
| hkpVelocityConstraintMotor | 0x1419f3fe0 | 4 |  |
| hkpWheelConstraintData | 0x1419f3630 | 19 |  |
| hkpWorld | 0x1419f4f58 | 3 |  |
| hkpWorldCinfo | 0x141823fc8 | 3 |  |
| hkpWorldDeletionListener | 0x1419f5f40 | 3 |  |
| hkpWorldExtension | 0x1419f63b0 | 5 |  |
| hkpWorldLinearCaster | 0x1419f4f40 | 2 |  |
| hkpWorldMaintenanceMgr | 0x1419f6318 | 6 |  |
| hkpWorldObject | 0x1419eb418 | 6 |  |
| hkpWorldPostSimulationListener | 0x1419189f8 | 3 |  |
| hkpWorldRayCaster | 0x1419f4f28 | 2 |  |
| hkxAnimatedFloat | 0x141a150f8 | 3 |  |
| hkxAnimatedMatrix | 0x141a15148 | 3 |  |
| hkxAnimatedQuaternion | 0x141a15198 | 3 |  |
| hkxAnimatedVector | 0x141a151e8 | 3 |  |
| hkxAttributeHolder | 0x141a15328 | 3 |  |
| hkxCamera | 0x141a15490 | 3 |  |
| hkxEdgeSelectionChannel | 0x141a15828 | 3 |  |
| hkxEnum | 0x141a15298 | 3 |  |
| hkxEnvironment | 0x141a1b2c0 | 3 |  |
| hkxIndexBuffer | 0x141a15a58 | 3 |  |
| hkxLight | 0x141a15598 | 3 |  |
| hkxMaterial | 0x141a155e0 | 3 |  |
| hkxMaterialEffect | 0x141a15698 | 3 |  |
| hkxMaterialShader | 0x141a156e8 | 3 |  |
| hkxMaterialShaderSet | 0x141a1b590 | 3 |  |
| hkxMesh | 0x141a1b5d0 | 3 |  |
| hkxMesh::UserChannelInfo | 0x141a15ad0 | 3 |  |
| hkxMeshSection | 0x141a15ab0 | 3 |  |
| hkxNode | 0x141a15528 | 3 |  |
| hkxNodeSelectionSet | 0x141a15c68 | 3 |  |
| hkxScene | 0x141a15ca8 | 3 |  |
| hkxSkinBinding | 0x141a15c88 | 3 |  |
| hkxSparselyAnimatedBool | 0x141a15258 | 3 |  |
| hkxSparselyAnimatedEnum | 0x141a152b8 | 3 |  |
| hkxSparselyAnimatedInt | 0x141a15278 | 3 |  |
| hkxSparselyAnimatedString | 0x141a152d8 | 3 |  |
| hkxTextureFile | 0x141a15798 | 3 |  |
| hkxTextureInplace | 0x141a157d8 | 3 |  |
| hkxTriangleSelectionChannel | 0x141a15880 | 3 |  |
| hkxVertexBuffer | 0x141a1b5b0 | 3 |  |
| hkxVertexFloatDataChannel | 0x141a158e0 | 3 |  |
| hkxVertexIntDataChannel | 0x141a15940 | 3 |  |
| hkxVertexSelectionChannel | 0x141a15998 | 3 |  |
| hkxVertexVectorDataChannel | 0x141a159f8 | 3 |  |

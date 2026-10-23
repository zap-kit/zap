# Game settings: magic, spells, enchanting, alchemy

The value compiled into `SkyrimSE.exe` for each game setting (GMST) it knows: what the game uses when `Skyrim.esm` has no record of that name (the plugin's record wins). `game/sim/settings.zap` keeps the few the port reads; this is the whole table.

Read from the static `SettingT<GameSettingCollection>` objects in `.data` (24 bytes: the vtable, the value, the pointer to the name; the vtable's RTTI names the class), found by scanning `.data` for pointers to names and checked against REA's `read_bytes` at 0x1420d9078 (fShadowBiasScale:Display). The address is the object's; the value is decoded by the name's type letter (f float, i int, u unsigned, b bool, s string, r and a 32-bit colors).

| address | setting | value |
|---|---|---|
| 0x1420aac50 | fAlchemyGoldMult | 1.0 |
| 0x1420aaab8 | fAlchemyIngredientInitMult | 4.0 |
| 0x1420aaad0 | fAlchemySkillFactor | 2.0 |
| 0x1420aae18 | fMagicAbsorbDistanceReachMult | 3.0 |
| 0x1420ab7c0 | fMagicAbsorbVisualTimer | 4.0 |
| 0x1420abb08 | fMagicAccumulatingModifierEffectHoldDuration | 0.5 |
| 0x1420aac98 | fMagicAreaBaseCostMult | 0.15 |
| 0x1420aaf50 | fMagicAreaScale | 1.75 |
| 0x1420aaf68 | fMagicAreaScaleMax | 100.0 |
| 0x1420aaf80 | fMagicAreaScaleMin | 2.5 |
| 0x142076b50 | fMagicBallMaximumDistance | 2000.0 |
| 0x142076b38 | fMagicBallOptimalDistance | 1000.0 |
| 0x1420ab988 | fMagicBarrierDepth | 30.0 |
| 0x1420ab970 | fMagicBarrierHeight | 500.0 |
| 0x1420ab958 | fMagicBarrierSpacing | 25.0 |
| 0x1420aae48 | fMagicBoltDuration | 1.5 |
| 0x142076b80 | fMagicBoltMaximumDistance | 2000.0 |
| 0x142076b68 | fMagicBoltOptimalDistance | 1000.0 |
| 0x1420aae30 | fMagicBoltSegmentLength | 300.0 |
| 0x1420aad10 | fMagicCasterPCSkillCostBase | 0.005 |
| 0x1420aad28 | fMagicCasterPCSkillCostMult | 1.0 |
| 0x1420aace0 | fMagicCasterSkillCostBase | 0.005 |
| 0x1420aacf8 | fMagicCasterSkillCostMult | 1.0 |
| 0x142076ca0 | fMagicCasterTargetUpdateInterval | 0.25 |
| 0x1420ab478 | fMagicCEEnchantMagOffset | 5.0 |
| 0x1420aaf20 | fMagicChainExplosionEffectivenessDelta | 0.1 |
| 0x1420ab040 | fMagicCloudAreaMin | 1.0 |
| 0x1420ab028 | fMagicCloudDurationMin | 5.0 |
| 0x1420ab010 | fMagicCloudFindTargetTime | 0.25 |
| 0x1420aafb0 | fMagicCloudLifeScale | 0.5 |
| 0x1420aafe0 | fMagicCloudSizeScale | 2.0 |
| 0x1420aaff8 | fMagicCloudSlowdownRate | 0.2 |
| 0x1420aaf98 | fMagicCloudSpeedBase | 750.0 |
| 0x1420aafc8 | fMagicCloudSpeedScale | 0.75 |
| 0x1420ab7d8 | fMagicCostScale | 1.1 |
| 0x1420abb20 | fMagicDefaultAccumulatingModifierEffectRate | 1.0 |
| 0x142076cb8 | fMagicDefaultCEBarterFactor | 1.0 |
| 0x1420aae00 | fMagicDefaultTouchDistance | 256.0 |
| 0x1420ab490 | fMagicDiseaseTransferBase | 0.0 |
| 0x1420ab4a8 | fMagicDiseaseTransferMult | 1.0 |
| 0x1420ab460 | fMagicDispelMagnitudeMult | 5.0 |
| 0x1420abbc8 | fMagicDualCastingCostBase | 0.0 |
| 0x1420abbe0 | fMagicDualCastingCostMult | 1.5 |
| 0x1420abb98 | fMagicDualCastingEffectivenessBase | 2.0 |
| 0x1420abbb0 | fMagicDualCastingEffectivenessMult | 0.0 |
| 0x1420abb68 | fMagicDualCastingTimeBase | 0.0 |
| 0x1420abb80 | fMagicDualCastingTimeMult | 1.5 |
| 0x1420aacb0 | fMagicDurMagBaseCostMult | 0.1 |
| 0x1420aad40 | fMagicEnchantmentChargeBase | 0.0 |
| 0x1420aad58 | fMagicEnchantmentChargeMult | 1.0 |
| 0x1420aad70 | fMagicEnchantmentDrainBase | 0.0 |
| 0x1420aad88 | fMagicEnchantmentDrainMult | 0.25 |
| 0x1420aaed8 | fMagicExplosionAgilityMult | 0.0 |
| 0x1420aaf38 | fMagicExplosionClutterMult | 6.5 |
| 0x1420aaef0 | fMagicExplosionIncorporealMult | 600.0 |
| 0x1420aaf08 | fMagicExplosionIncorporealTime | 1.25 |
| 0x1420aaea8 | fMagicExplosionPowerBase | 100.0 |
| 0x1420aae90 | fMagicExplosionPowerMax | 100.0 |
| 0x1420aae78 | fMagicExplosionPowerMin | 0.0 |
| 0x1420aaec0 | fMagicExplosionPowerMult | 0.4 |
| 0x142076be0 | fMagicFogMaximumDistance | 500.0 |
| 0x142076bc8 | fMagicFogOptimalDistance | 300.0 |
| 0x1420ab400 | fMagicGrabActorDrawSpeed | 100.0 |
| 0x1420ab3e8 | fMagicGrabActorMinDistance | 90.0 |
| 0x1420ab418 | fMagicGrabActorRange | 750.0 |
| 0x1420ab430 | fMagicGrabActorThrowForce | 25.0 |
| 0x1420aba90 | fMagicGuideSpacing | 500.0 |
| 0x1420a12f8 | fMagickaRegenDelayMax | 5.0 |
| 0x1420ab058 | fMagickaReturnBase | 0.75 |
| 0x1420ab070 | fMagickaReturnMult | 0.02 |
| 0x1420abaf0 | fMagicLesserPowerCooldownTimer | 3.0 |
| 0x1420ab160 | fMagicLightForwardOffset | 22.0 |
| 0x1420ab178 | fMagicLightHeightOffset | 10.0 |
| 0x1420ab1a8 | fMagicLightRadiusBase | 0.0 |
| 0x1420ab190 | fMagicLightSideOffset | 0.0 |
| 0x1420ab448 | fMagicNightEyeAmbient | 0.75 |
| 0x1420ab808 | fMagicPCSkillCostScale | 0.5 |
| 0x1420ab130 | fMagicPlayerMinimumInvisibility | 0.1 |
| 0x1420ab9a0 | fMagicPostDrawCastDelay | 1.5 |
| 0x1420aae60 | fMagicProjectileMaxDistance | 10000.0 |
| 0x1420aacc8 | fMagicRangeTargetCostMult | 1.5 |
| 0x1420aada0 | fMagicResistActorSkillBase | 0.0 |
| 0x1420aadb8 | fMagicResistActorSkillMult | -0.0025 |
| 0x1420aadd0 | fMagicResistTargetWillpowerBase | 0.0 |
| 0x1420aade8 | fMagicResistTargetWillpowerMult | 0.005 |
| 0x1420ab7f0 | fMagicSkillCostScale | 0.5 |
| 0x142076bb0 | fMagicSprayMaximumDistance | 1000.0 |
| 0x142076b98 | fMagicSprayOptimalDistance | 500.0 |
| 0x1420ab850 | fMagicSummonMaxAppearTime | 4.0 |
| 0x1420ab310 | fMagicTelekinesiDistanceMult | 1.0 |
| 0x1420ab370 | fMagicTelekinesisBaseDistance | 15.0 |
| 0x1420ab2e0 | fMagicTelekinesisComplexMaxForce | 1000.0 |
| 0x1420ab2c8 | fMagicTelekinesisComplexObjectDamping | 0.7 |
| 0x1420ab298 | fMagicTelekinesisComplexSpringDamping | 0.9 |
| 0x1420ab2b0 | fMagicTelekinesisComplexSpringElasticity | 0.1 |
| 0x1420ab3b8 | fMagicTelekinesisDamageBase | 5.0 |
| 0x1420ab388 | fMagicTelekinesisDamageMult | 1.0 |
| 0x1420ab208 | fMagicTelekinesisDistanceMin | 48.0 |
| 0x1420ab3a0 | fMagicTelekinesisDualCastDamageMult | 2.0 |
| 0x1420ab358 | fMagicTelekinesisDualCastThrowMult | 2.0 |
| 0x1420ab2f8 | fMagicTelekinesisLiftPowerMult | 0.5 |
| 0x1420ab280 | fMagicTelekinesisMaxForce | 1000.0 |
| 0x1420ab1d8 | fMagicTelekinesisMoveAccelerate | 400.0 |
| 0x1420ab1c0 | fMagicTelekinesisMoveBase | 50.0 |
| 0x1420ab1f0 | fMagicTelekinesisMoveMax | 1000.0 |
| 0x1420ab268 | fMagicTelekinesisObjectDamping | 0.95 |
| 0x1420ab238 | fMagicTelekinesisSpringDamping | 0.5 |
| 0x1420ab250 | fMagicTelekinesisSpringElasticity | 0.075 |
| 0x1420ab220 | fMagicTelekinesisThrow | 1000.0 |
| 0x1420ab340 | fMagicTelekinesisThrowAccelerate | 10.0 |
| 0x1420ab328 | fMagicTelekinesisThrowMax | 30.0 |
| 0x1420ab4c0 | fMagicTrackingLimit | 3.0 |
| 0x1420ab4d8 | fMagicTrackingLimitComplex | 1.0 |
| 0x1420ab4f0 | fMagicTrackingMultBall | 1.0 |
| 0x1420ab508 | fMagicTrackingMultBolt | 0.5 |
| 0x1420ab520 | fMagicTrackingMultFog | 1.0 |
| 0x1420aac80 | fMagicUnitsPerFoot | 22.0 |
| 0x1420ab8e0 | fMagicVACNoPartTargetedMult | 0.1 |
| 0x1420ab8c8 | fMagicVACPartTargetedMult | 0.1 |
| 0x1420abb38 | fMagicWardPowerMaxBase | 0.5 |
| 0x1420abb50 | fMagicWardPowerMaxMult | 0.0 |
| 0x1420a9318 | fPotionGoldValueMult | 1.0 |
| 0x1420a91c8 | fPotionMortPestleMult | 0.25 |
| 0x1420a9270 | fPotionT1AleDurMult | -0.01 |
| 0x1420a9258 | fPotionT1AleMagMult | -0.01 |
| 0x1420a9240 | fPotionT1CalDurMult | 0.0025 |
| 0x1420a9228 | fPotionT1CalMagMult | 0.0035 |
| 0x1420a91e0 | fPotionT1MagMult | 2.5 |
| 0x1420a9210 | fPotionT1RetDurMult | 0.003 |
| 0x1420a91f8 | fPotionT1RetMagMult | 0.005 |
| 0x1420a92b8 | fPotionT2AleDurMult | -0.02 |
| 0x1420a92a0 | fPotionT2CalDurMult | 0.0025 |
| 0x1420a9288 | fPotionT2RetDurMult | 0.0035 |
| 0x1420a9300 | fPotionT3AleMagMult | -0.01 |
| 0x1420a92e8 | fPotionT3CalMagMult | 0.003 |
| 0x1420a92d0 | fPotionT3RetMagMult | 0.005 |
| 0x1420bacf8 | fShoutMeterFinishTime:Interface | 3.0 |
| 0x142099138 | fShoutRumbleBigMotorDurationV1 | 0.0 |
| 0x142099168 | fShoutRumbleBigMotorDurationV2 | 0.0 |
| 0x142099198 | fShoutRumbleBigMotorDurationV3 | 0.0 |
| 0x142099120 | fShoutRumbleBigMotorFrequencyV1 | 0.0 |
| 0x142099150 | fShoutRumbleBigMotorFrequencyV2 | 0.0 |
| 0x142099180 | fShoutRumbleBigMotorFrequencyV3 | 0.0 |
| 0x1420991c8 | fShoutRumbleSmallMotorDurationV1 | 0.0 |
| 0x1420991f8 | fShoutRumbleSmallMotorDurationV2 | 0.0 |
| 0x142099228 | fShoutRumbleSmallMotorDurationV3 | 0.0 |
| 0x1420991b0 | fShoutRumbleSmallMotorFrequencyV1 | 0.0 |
| 0x1420991e0 | fShoutRumbleSmallMotorFrequencyV2 | 0.0 |
| 0x142099210 | fShoutRumbleSmallMotorFrequencyV3 | 0.0 |
| 0x1420ab910 | fShoutTime1 | 0.2 |
| 0x1420ab928 | fShoutTime2 | 0.9 |
| 0x1420ab940 | fShoutTimeout | 8.0 |
| 0x1420a0590 | fSpellCastingDetectionHitActorMod | 40.0 |
| 0x1420a0578 | fSpellCastingDetectionMod | 10.0 |
| 0x1420aba00 | fSummonDistanceCheckThreshold | 750.0 |
| 0x1420abad8 | fWardAngleForExplosions | 90.0 |
| 0x1420aba78 | iMagicGuideWaypoints | 10 |
| 0x1420ab148 | iMagicLightMaxCount | 4 |
| 0x1420b00e0 | sAlchemy | "Alchemy" |
| 0x1420b0110 | sAlchemyMenuDescription | "Combine ingredients to make potions" |
| 0x1420b0080 | sEnchantArmorIncompatible | "Chosen enchantment cannot be applied to this item" |
| 0x1420afff0 | sEnchantDeconstructMenuDescription | "Choose an item to destroy and learn its effects" |
| 0x1420b0068 | sEnchantInsufficientCharge | "Insufficient charge for enchantment" |
| 0x1420aff60 | sEnchantItem | "Enchant item?" |
| 0x1420afed0 | sEnchantMenuDescription | "Choose an item to destroy and learn its Enchantment, or combine an Item, Enchantment, and Soul Gem to create magic items" |
| 0x1420b0050 | sEnchantMustChooseItems | "Choose an item, enchantment, and soul gem" |
| 0x142076d60 | sMagicCastCastWhileShouting | "You cannot cast a spell while shouting" |
| 0x142076d78 | sMagicCastInsufficientItemCharge | "Your item has insufficient charge" |
| 0x142076ce8 | sMagicCastInsufficientMagicka | "You don't have enough Magicka" |
| 0x142076d30 | sMagicCastMultiCast | "You cannot cast this spell while casting another" |
| 0x142076cd0 | sMagicCastOKText | "" |
| 0x142076d00 | sMagicCastPowerUsed | "You can only cast Powers once per day" |
| 0x142076d18 | sMagicCastRangedUnderwater | "You cannot cast ranged spells underwater" |
| 0x142076d48 | sMagicCastShoutWhileCasting | "You cannot shout while casting a spell" |
| 0x142076a48 | sMagicConcentration | "Concentration" |
| 0x142076a18 | sMagicConstantEffect | "Constant Effect" |
| 0x142076a90 | sMagicDeliveryAimed | "Aimed" |
| 0x142076a60 | sMagicDeliverySelf | "Self" |
| 0x142076620 | sMagicDeliveryStrike | "Strike" |
| 0x142076aa8 | sMagicDeliveryTargetActor | "Target Actor" |
| 0x142076ac0 | sMagicDeliveryTargetLocation | "Target Location" |
| 0x142076a78 | sMagicDeliveryTouch | "Contact" |
| 0x142076608 | sMagicEffectItemAbsorb | "Absorb" |
| 0x142076578 | sMagicEffectItemCreateLock | "Create" |
| 0x1420765f0 | sMagicEffectItemDamage | "Damage" |
| 0x1420765d8 | sMagicEffectItemDrain | "Drain" |
| 0x142076548 | sMagicEffectItemFeet | "ft" |
| 0x142076488 | sMagicEffectItemFor | "for" |
| 0x1420765a8 | sMagicEffectItemFortify | "Fortify" |
| 0x1420764b8 | sMagicEffectItemIn | "in" |
| 0x142076560 | sMagicEffectItemLock | "Lock" |
| 0x1420764a0 | sMagicEffectItemOn | "on" |
| 0x1420764e8 | sMagicEffectItemPercent | "%" |
| 0x142076530 | sMagicEffectItemPointsPlural | "pts" |
| 0x142076500 | sMagicEffectItemPointsSingular | "pt" |
| 0x1420765c0 | sMagicEffectItemRestore | "Restore" |
| 0x142076518 | sMagicEffectItemSecondsPlural | "secs" |
| 0x1420764d0 | sMagicEffectItemSecondsSingular | "sec" |
| 0x142076590 | sMagicEffectItemUpToLevel | "up to level" |
| 0x1420af900 | sMagicEffectNotApplied | "%s is immune to %s." |
| 0x1420af8e8 | sMagicEffectResisted | "%s is too powerful for %s." |
| 0x1420af960 | sMagicEnhanceWeaponNoWeapon | "You must have a weapon drawn." |
| 0x1420af978 | sMagicEnhanceWeaponWeaponEnchanted | "Your current weapon is already enchanted." |
| 0x142076a30 | sMagicFireAndForget | "Fire and Forget" |
| 0x1420abaa8 | sMagicGuideNoMarker | "You must have an active quest or have placed a marker on the map." |
| 0x1420abac0 | sMagicGuideNoPath | "There's no way to get to the nearest active quest location or map marker." |
| 0x142076ad8 | sMagicProjectileTypeBall | "Ball" |
| 0x142076af0 | sMagicProjectileTypeBolt | "Bolt" |
| 0x142076b20 | sMagicProjectileTypeFog | "Fog" |
| 0x142076b08 | sMagicProjectileTypeSpray | "Spray" |
| 0x142076850 | sMagicSchoolAlteration | "Alteration" |
| 0x142076868 | sMagicSchoolConjuration | "Conjuration" |
| 0x142076880 | sMagicSchoolDestruction | "Destruction" |
| 0x142076898 | sMagicSchoolIllusion | "Illusion" |
| 0x1420768b0 | sMagicSchoolRestoration | "Restoration" |
| 0x1420ab3d0 | sMagicTelekinesisNoRecast | "You're already holding something." |
| 0x1420768e0 | sMagicTypeAbility | "Ability" |
| 0x1420769b8 | sMagicTypeAddiction | "Addiction" |
| 0x1420768f8 | sMagicTypeDisease | "Disease" |
| 0x142076958 | sMagicTypeEnchantment | "Enchantment" |
| 0x142076910 | sMagicTypeLesserPower | "Lesser Power" |
| 0x1420769a0 | sMagicTypeLevelled | "Levelled Spell" |
| 0x142076940 | sMagicTypePoison | "Poison" |
| 0x142076970 | sMagicTypePotion | "Potion" |
| 0x142076928 | sMagicTypePower | "Power" |
| 0x142076a00 | sMagicTypeScroll | "Scroll" |
| 0x1420768c8 | sMagicTypeSpell | "Spell" |
| 0x1420769e8 | sMagicTypeStaffEnchantment | "Staff Enchantment" |
| 0x1420769d0 | sMagicTypeVoicePower | "Voice Power" |
| 0x142076988 | sMagicTypeWortcraft | "Wortcraft" |
| 0x1420b00b0 | sPotionCreationFailed | "Potion creation failed" |
| 0x1420abf58 | sShoutAdded | "Word of Power Learned" |
| 0x1420af4e0 | sSpellAdded | "New Spell Learned" |

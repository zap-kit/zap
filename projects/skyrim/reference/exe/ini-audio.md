# Ini settings: [Audio]

The value compiled into `SkyrimSE.exe` for each ini setting: what the game uses when neither `Skyrim.ini` nor `SkyrimPrefs.ini` sets it. `skyrim/ini.zap` keeps the few the port reads; this is the whole table. A setting the game fills at run time holds 0 here (NOTES.md names iDifficulty, fAutosaveEveryXMins).

Read from the static `SettingT<INISettingCollection>` objects in `.data` (24 bytes: the vtable, the value, the pointer to the name; the vtable's RTTI names the class), found by scanning `.data` for pointers to names and checked against REA's `read_bytes` at 0x1420d9078 (fShadowBiasScale:Display). The address is the object's; the value is decoded by the name's type letter (f float, i int, u unsigned, b bool, s string, r and a 32-bit colors).

| address | setting | value |
|---|---|---|
| 0x1420b5c18 | bEnableAudio:Audio | 1 |
| 0x1420b5c30 | bEnableAudioCache:Audio | 1 |
| 0x1420b4a88 | fASFadeInTime:Audio | 3.0 |
| 0x1420b4aa0 | fASFadeOutTime:Audio | 8.0 |
| 0x1420b3d40 | fAudioRumbleBigDeadZone:audio | 0.0 |
| 0x1420b3cb0 | fAudioRumbleBigExponent:audio | 0.5 |
| 0x1420b3d28 | fAudioRumbleBigLerpMax:audio | 1.0 |
| 0x1420b3d10 | fAudioRumbleBigLerpMin:audio | 0.0 |
| 0x1420b3d58 | fAudioRumblePowerAttackAdj:audio | 0.15 |
| 0x1420b3cf8 | fAudioRumbleSmallDeadZone:audio | 0.0 |
| 0x1420b3c98 | fAudioRumbleSmallExponent:audio | 0.4 |
| 0x1420b3ce0 | fAudioRumbleSmallLerpMax:audio | 1.0 |
| 0x1420b3cc8 | fAudioRumbleSmallLerpMin:audio | 0.0 |
| 0x1420b5708 | fCollisionSoundHeavyThreshold:Audio | 160.0 |
| 0x1420b5c60 | fDefaultMasterVolume:Audio | 1.0 |
| 0x142079ed8 | fDialogueHeadPitchExaggeration:Audio | 2.0 |
| 0x142079ef0 | fDialogueHeadRollExaggeration:Audio | 2.0 |
| 0x142079f08 | fDialogueHeadYawExaggeration:Audio | 2.0 |
| 0x1420b6b78 | fHardLandingDamageThreshold:Audio | 500.0 |
| 0x1420b4b78 | fHighlightSpeechOverlap:Audio | 0.5 |
| 0x1420b4b60 | fMaxHighlightRadius:Audio | 250.0 |
| 0x1420b4b18 | fMenuModeFadeInTime:Audio | 0.5 |
| 0x1420b4b00 | fMenuModeFadeOutTime:Audio | 0.5 |
| 0x14209e2b8 | fMinSoundVel:Audio | 60.0 |
| 0x14207e310 | fMusicDuckingSeconds:Audio | 1.0 |
| 0x14207e340 | fMusicFinaleCrossFadeTimeIn:Audio | 3.0 |
| 0x14207e358 | fMusicFinaleCrossFadeTimeOut:Audio | 6.0 |
| 0x14207e328 | fMusicUnDuckingSeconds:Audio | 4.0 |
| 0x1420bab90 | fNonDialogVoiceDucking:Audio | 9.0 |
| 0x1420babc0 | fNonDialogVoiceDuckingFadeIn:Audio | 1.0 |
| 0x1420baba8 | fNonDialogVoiceDuckingFadeOut:Audio | 1.5 |
| 0x1420b4b30 | fNonHighlightSpeechAtten:Audio | 12.0 |
| 0x1420b4ab8 | fRegionLoopFadeInTime:Audio | 6.0 |
| 0x1420b4ad0 | fRegionLoopFadeOutTime:Audio | 8.0 |
| 0x1420b4a28 | fRegionRandomSoundPlacementBase:Audio | 100.0 |
| 0x1420b4a40 | fRegionSoundPlacementRandomOffset:Audio | 650.0 |
| 0x1420b4a58 | fRegionSoundPlacementZOffset:Audio | 256.0 |
| 0x1420b4ae8 | fReverbTransitionTime:Audio | 0.5 |
| 0x1420b35c0 | fWaterAudioFadeInSeconds:Audio | 3.0 |
| 0x1420b35d8 | fWaterAudioFadeOutSeconds:Audio | 5.0 |
| 0x1420b56f0 | iCollisionSoundTimeDelta:Audio | 150 |
| 0x1420b4b48 | iHighlightSpeechOverlap:Audio | 500 |
| 0x1420b5c00 | sAudioAPI:Audio | "XAudio2" |
| 0x1420ba030 | sDeathCameraEffect:Audio | "MAGShoutSlowTimeActiveLP" |
| 0x1420b5cc0 | sMissingAssetSoundFile:Audio | "" |
| 0x1420b5cf0 | uAsyncReadPriorityThreshold:Audio | 64 |
| 0x1420b4ba8 | uAudioThreadSleepTimeGameMode:Audio | 33 |
| 0x1420b4b90 | uAudioThreadSleepTimeMenuMode:Audio | 1 |
| 0x1420b5c48 | uMaxSizeForCachedSound:Audio | 262144 |
| 0x1420b4a70 | uRegionSoundsAllowedPerUpdate:Audio | 1 |
| 0x1420b5cd8 | uStreamingThreshold:Audio | 4194304 |
| 0x1420b3620 | uWaterAudioAmbientAttenuation:Audio | 2200 |
| 0x1420b3608 | uWaterAudioAxisSamplePoints:Audio | 8 |
| 0x1420b35f0 | uWaterAudioSamplePointsToUse:Audio | 8 |

# The clip triggers of a behavior graph (hkbBehaviorGraph packfiles, behaviors/*.hkx): Skyrim keeps
# an attack's "HitFrame", "weaponSwing" and "preHitFrame" not in the animation's annotations but
# as the triggers of the hkbClipGenerator that plays it (hkbClipTriggerArray: a local time, an
# event id, relative to the clip's end or not), the event ids naming the graph's string data
# (hkbBehaviorGraphStringData's eventNames). Layouts after the Havok 2010 64-bit classes as
# hkxpack and HavokLib lay them out: hkbClipTrigger is 32 bytes (localTime, the hkbEventProperty's
# id at 8, relativeToEndOfClip at 24). graph.zap reads them into its clip nodes.

triggerArrayTriggers = refObject
triggerSize = 32
triggerEvent = 8
triggerRelativeToEnd = 24

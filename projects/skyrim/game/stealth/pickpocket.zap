# Pickpocketing, as SkyrimSE.exe 1.7.104 does it. Activating a living actor of a race that allows
# it (RACE flag 0x800000) while sneaking shows "Pickpocket" (the activation text, 0x1403c1000); the
# container menu opens in its pickpocket mode (mode 2) and shows, for the selected item, its chance
# (ContainerMenu 0x140911310): the thief's and the victim's Pickpocket skills, the stack's gold
# value and the item's weight, less fPickPocketDetected when the victim has detected the player
# (0x14041d860). Taking an item rolls against that chance (PlayerCharacter::AttemptPickpocket
# 0x140759b90): a failure sets the victim's detection of the player to 100, adds a pickpocket crime
# and closes the menu ("You've been caught pickpocketing."); a success moves the item, marked stolen
# from the victim, the Pickpocket skill gaining its value to the fPickpocketSkillUsesCurve
# (0x140421ca0, skills.zap). The perks' entry point 0x38 (Modify Pickpocket Chance) changes the
# chance before its limits. Not modelled: the perk that allows taking worn items, items put into the victim.

import game.sim

# what taking an item from an actor did
pub type Pickpocket:
	Stole(item i64, count i64)
	Caught(bounty i64)
	Refused(reason str)

# the message of a failed attempt
pub caughtText = "You've been caught pickpocketing."

# The chance of stealing something worth `value` gold in all and weighing `weight` in all from a
# victim of this Pickpocket skill, by a thief of this one, before the perks and the limits
# (0x14041d860): the settings' sum, less fPickPocketDetected when the victim has detected the thief.
pub fn rawChance(
	settings {str: f64},
	thief f32,
	victim f32,
	value i64,
	weight f32,
	detected bool
) f32:
	chance = settings.gmst("fpickpockettargetskillmult") * victim +
		settings.gmst("fpickpockettargetskillbase") +
		settings.gmst("fpickpocketactorskillmult") * thief +
		settings.gmst("fpickpocketactorskillbase") +
		f32(value) * settings.gmst("fpickpocketamountmult") +
		settings.gmst("fpickpocketamountbase") +
		settings.gmst("fpickpocketweightmult") * weight +
		settings.gmst("fpickpocketweightbase")
	if detected: chance -= settings.gmst("fpickpocketdetected")
	chance

# the chance in percent: between fPickPocketMinChance and fPickPocketMaxChance, rounded
pub fn limitedChance(settings {str: f64}, chance f32) i64:
	shown = chance
		.min(settings.gmst("fpickpocketmaxchance"))
		.max(settings.gmst("fpickpocketminchance"))
	i64(shown + 0.5) if shown >= 0.0 else i64(shown)

# the chance in percent without the thief's perks
pub fn chanceOf(
	settings {str: f64},
	thief f32,
	victim f32,
	value i64,
	weight f32,
	detected bool
) i64:
	settings.limitedChance(settings.rawChance(thief, victim, value, weight, detected))

# The player's chance of taking the item (worth `value`, weighing `weight` in all) from the victim:
# the sum, then the perks' entry point 0x38 (the victim and the item its parameters), then the limits.
fn chanceFor(w sim.GameWorld, victim i64, form i64, value i64, weight f32):
	thief = (w.actors.get(w.player)?.valueOf("pickpocket")) ?? 0.0
	mark = (w.actors.get(victim)?.valueOf("pickpocket")) ?? 0.0
	raw = w.settings.rawChance(thief, mark, value, weight, w.isDetectedBy(victim))
	w.settings.limitedChance(
		w.entryPointValue(sim.epModPickpocketChance, w.player, [victim, form], raw)
	)

# the instances of the stack that are not worn: the ones a pickpocket can take
fn looseCount(s sim.Stack):
	s.count - s.extras.filter(.isEquipped()).map(.count).sum()

# what a victim holds that can be taken: its stacks less what it wears, gold and all
pub fn takableFrom(w sim.GameWorld, victim i64) sim.Stack[]:
	inv = w.inventories.get(victim) ?? return []
	out = []
	for s in inv.stacks:
		n = s.looseCount()
		if n <= 0 or w.items.get(s.form) == none: continue
		out.push(sim.Stack(form = s.form, count = n))
	out

# The chance the menu shows for the stack: one of an item that weighs something, the whole stack of
# one that weighs nothing (gold), the player's skill against the victim's (ContainerMenu 0x140911310).
pub fn shownChance(w sim.GameWorld, victim i64, s sim.Stack) i64:
	item = w.items.get(s.form) ?? return 0
	count = 1 if item.weight > 0.0 else s.count
	w.chanceFor(victim, s.form, item.value * count, item.weight)

# the chance of an attempt on `count` of the item: its whole value (at least 1) and weight
pub fn attemptChance(w sim.GameWorld, victim i64, item sim.Item, count i64) i64:
	w.chanceFor(victim, item.formId, (item.value * count).max(1), item.weight * f32(count))

# a roll of 0 to 99 from the world's pickpocket sequence
fn rollOf(mut w sim.GameWorld):
	r = Random(1)
	r.state = w.stealth.roll
	roll = r.nextInt(0, 100)
	w.stealth.roll = r.state
	roll

# The player takes `count` of the item from the victim: the roll against the chance. A success
# moves what the victim holds loose (at most `count`) into the player's inventory, marked stolen
# from the victim; a failure makes the victim notice the player and adds a pickpocket crime to its
# crime faction (CRVA's pickpocket gold).
pub fn attempt(mut w sim.GameWorld, victim i64, item i64, count i64) Pickpocket:
	if not w.canPickpocket(victim): return .Refused("the player cannot pickpocket {victim:08X}")
	taken = w.takableFrom(victim).find(.form == item) ??
		return .Refused("{item:08X} cannot be taken")
	info = w.items[item].copy()
	n = count.min(taken.count)
	if n <= 0: return .Refused("nothing to take")
	chance = w.attemptChance(victim, info, n)
	roll = w.rollOf()
	w.record("pickpocket {n} {info.editorId} from {victim:08X}: {chance}% chance, rolled {roll}")
	if roll >= chance: return w.caught(victim, item, n, info)
	owner = w.actors[victim].npc
	for x in w.inventories[victim].takeOut(item, n):
		w.ensureInventory(w.player)
		w.inventories[w.player].addExtra(item, sim.ItemExtra(..x, owner))
	w.useSkill("pickpocket", w.pickpocketUsage(info.value * n))
	.Stole(item, n)

fn caught(mut w sim.GameWorld, victim i64, item i64, count i64, info sim.Item) Pickpocket:
	a = w.actors[victim].copy()
	w.notice(victim)
	values = w.crimeValues.get(a.crimeFaction)
	bounty = values?.pickpocket ?? 0
	w.crimes.push(
		sim.Crime(
			kind = "pickpocket",
			actor = w.player,
			refId = victim,
			item,
			count,
			value = info.value * count,
			owner = a.npc,
			faction = a.crimeFaction,
			bounty
		)
	)
	w.notifications.push(caughtText.copy())
	.Caught(bounty)

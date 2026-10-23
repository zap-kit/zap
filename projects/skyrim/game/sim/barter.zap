# Buying and selling with a merchant, as the game's barter menu does. A merchant is an actor in a
# faction with a vendor record: VENC the container holding his stock and his gold (what the menu
# lists under his name, his gold the chest's), VEND a form list of keywords, VENV how the list is
# read (CommonLibSSE-NG's TESFaction::VendorData: start and end hour, radius, then "only buys
# stolen items" and "buy and sell everything not in the list"). The prices are economy.zap's
# factor of the player's Speech, each the menu's own rounding (BarterMenu.as multiplies the card's
# value by SetBarterMultipliers' buy or sell multiplier). He buys what his list names (or what it
# leaves out, when it is read the other way) and never a stolen item unless the player's
# BypassVendorStolenCheck says so; a fence buys only stolen ones, and what he buys is no longer
# stolen. The keyword list is bypassed by BypassVendorKeywordCheck.

import skyrim.actor
import skyrim.esm

# the gold item
pub goldForm = 0xF

pub type Vendor:
	chest i64   # VENC: the reference holding the merchant's stock and gold
	keywords i64[]   # the keywords of VEND's form list
	onlyStolen bool   # VENV: a fence, who buys only stolen items
	notInList bool   # VENV: he buys what the list does not name

# why a trade did not happen
pub type Refusal:
	NoStock   # the merchant has not that many
	NotBought   # his list does not name the item
	Stolen   # the item is stolen and he buys no stolen item
	PlayerPoor   # the player's gold is short
	MerchantPoor   # the merchant's gold is short

# the vendor data of the first of the factions with a merchant container, none when no faction has
pub fn vendorOf(mut plugin esm.Esm, factions actor.Membership[]) Vendor?:
	for m in factions:
		if m.rank < 0: continue
		r = plugin.recordOf(m.faction) ?? continue
		chest = r.formOf("VENC") ?? continue
		at = esm.dataOf(r.fields, "VENV") ?? continue
		list = plugin.recordOf(r.formOf("VEND") ?? 0)
		return Vendor(
			chest,
			keywords = esm.formsOf(list?.body ?? [], list?.fields ?? [], "LNAM"),
			onlyStolen = r.body[at + 8] != 0,
			notInList = r.body[at + 9] != 0
		)
	none

# the merchant's vendor data, none for an actor who sells nothing
pub fn vendorAt(w GameWorld, merchant i64) Vendor?:
	(try w.actors.get(merchant)).vendor

# the merchant's gold: what his chest holds
pub fn vendorGold(w GameWorld, v Vendor) i64:
	w.inventories.get(v.chest)?.countOf(goldForm) ?? 0

fn playerSpeech(w GameWorld):
	(w.actors.get(w.player)?.valueOf("speechcraft") ?? 0.0)

# the factor after the player's perks of the entry point changed it (0x140900xxx: the barter
# menu's), itself when none does
fn perked(w GameWorld, point i64, merchant i64, factor f64):
	changed = w.entryPointValue(point, w.player, [merchant], f32(factor))
	factor if changed == f32(factor) else f64(changed)

# what the merchant asks for an item of this value, at least the item's value (the menu clamps the
# perks' result to 1)
pub fn buyMultiplier(w GameWorld, merchant i64) f64:
	w.perked(epModBuyPrices, merchant, w.settings.barterFactor(w.playerSpeech())).max(1.0)

# what he pays, as a share of its value, at most all of it
pub fn sellMultiplier(w GameWorld, merchant i64) f64:
	w.perked(epModSellPrices, merchant, w.settings.sellFactor(w.playerSpeech())).min(1.0)

# what the merchant asks for one of the item
pub fn askingPrice(w GameWorld, merchant i64, item Item) i64:
	i64((item.value * w.buyMultiplier(merchant)).round()).max(1)

# what the merchant pays for one of the item
pub fn payingPrice(w GameWorld, merchant i64, item Item) i64:
	i64((item.value * w.sellMultiplier(merchant)).round())

# whether the merchant takes the item from the player, why not when he does not
pub fn buys(w GameWorld, v Vendor, item Item, stolen bool) Refusal?:
	a = w.actors.get(w.player) ?? return .NotBought
	if v.onlyStolen:
		if not stolen: return .NotBought
	elif stolen and a.valueOf("bypassvendorstolencheck") <= 0.0:
		return .Stolen
	if a.valueOf("bypassvendorkeywordcheck") > 0.0: return none
	listed = item.keywords.any(it in v.keywords)
	if listed == v.notInList: return .NotBought
	none

# `count` of the item bought from the merchant: the gold to his chest, the items to the player
pub fn buyFrom(mut w GameWorld, merchant i64, form i64, count i64) Refusal?:
	v = w.vendorAt(merchant) ?? return .NoStock
	item = w.items.get(form) ?? return .NoStock
	w.ensureInventory(v.chest)
	w.ensureInventory(w.player)
	n = count.min(w.inventories[v.chest].countOf(form))
	if n <= 0: return .NoStock
	price = w.askingPrice(merchant, item) * n
	if w.inventories[w.player].countOf(goldForm) < price: return .PlayerPoor
	chest = w.inventories[v.chest].copy()
	mine = w.inventories[w.player].copy()
	mine.takeOut(goldForm, price)
	chest.addItem(goldForm, price)
	chest.moveItems(mine, form, n)
	w.inventories[v.chest] = chest
	w.inventories[w.player] = mine
	w.record("buy {n} {item.editorId} for {price}")
	w.useSkill("speechcraft", f32(item.value))
	none

# `count` of the item sold to the merchant for what he pays for each
pub fn sellTo(mut w GameWorld, merchant i64, form i64, count i64) Refusal?:
	v = w.vendorAt(merchant) ?? return .NotBought
	item = w.items.get(form) ?? return .NotBought
	w.ensureInventory(v.chest)
	w.ensureInventory(w.player)
	mine = w.inventories[w.player].copy()
	taken = mine.takeOut(form, count)
	n = taken.map(.count).sum()
	if n <= 0: return .NotBought
	if w.buys(v, item, taken.any(.owner != 0)) is refusal: return refusal
	price = w.payingPrice(merchant, item) * n
	chest = w.inventories[v.chest].copy()
	if chest.countOf(goldForm) < price: return .MerchantPoor
	chest.takeOut(goldForm, price)
	mine.addItem(goldForm, price)
	for x in taken:
		sold = x.copy()
		sold.owner = 0
		chest.addExtra(form, sold)
	w.inventories[v.chest] = chest
	w.inventories[w.player] = mine
	w.record("sell {n} {item.editorId} for {price}")
	w.useSkill("speechcraft", f32(item.value))
	none

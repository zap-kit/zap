# Inventory with an enum of categories, a map of items and simple commands.
type Category:
	Weapon
	Armor
	Potion
type Item:
	name str
	category Category
	qty i64
	price f64
fn categoryName(c Category):
	match c:
		Weapon: "weapon"
		Armor: "armor"
		Potion: "potion"
mut items {str: Item} = {}
items["sword"] = Item(name = "Sword", category = .Weapon, qty = 2, price = 150.0)
items["shield"] = Item(name = "Shield", category = .Armor, qty = 1, price = 90.5)
items["potion"] = Item(name = "Red Potion", category = .Potion, qty = 10, price = 5.0)

mut total = 0.0
for key in items.keys().sorted():
	match items.get(key):
		item:
			value = item.price * item.qty
			total += value
			print(
				"{item.name}: {item.qty} x {item.price} = {value} ({item.category.categoryName()})"
			)
		none: continue
print("total: {total}")

# sell 3 potions: take the entry out, change it, put it back
match items.remove("potion"):
	mut p:
		updated = move p
		updated.qty -= 3
		items["potion"] = updated
	none: print("no potion")
print(items.get("potion")?.qty ?? 0)
print("bow" in items)
print(items.len)

test "inventory commands add, use and list items by category":
	main()
	prints """
	    Red Potion: 10 x 5 = 50 (potion)
	    Shield: 1 x 90.5 = 90.5 (armor)
	    Sword: 2 x 150 = 300 (weapon)
	    total: 440.5
	    7
	    false
	    3
	    """

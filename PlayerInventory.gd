extends Node
class_name PlayerInventory

# === STORAGE ===
var items: Array[Item] = []
var gold: int = 0

# === SIGNALS ===
signal inventory_changed()
signal item_equipped(item: Item)
signal item_unequipped(item: Item)
signal item_used(item: Item)

# === ADD ITEMS ===
func add_item(item: Item, quantity: int = 1) -> void:
	if item.is_stackable:
		# Try to stack with existing item
		for existing_item in items:
			if existing_item.can_stack_with(item):
				var space_available = existing_item.max_stack - existing_item.quantity
				var amount_to_add = min(quantity, space_available)
				existing_item.quantity += amount_to_add
				quantity -= amount_to_add
				
				if quantity <= 0:
					inventory_changed.emit()
					print("Stacked %d %s (total: %d)" % [amount_to_add, item.name, existing_item.quantity])
					return
		
		# Create new stack if needed
		if quantity > 0:
			var new_item = item.clone()
			new_item.quantity = min(quantity, item.max_stack)
			items.append(new_item)
			print("Added %d %s to inventory" % [new_item.quantity, item.name])
	else:
		# Non-stackable items (equipment)
		for i in quantity:
			var new_item = item.clone()
			new_item.quantity = 1
			items.append(new_item)
	print(items)
	inventory_changed.emit()

func add_item_by_name(item_name: String, item_type: Item.ItemType, quantity: int = 1) -> void:
	var new_item = Item.new(item_name, item_type)
	add_item(new_item, quantity)

func remove_item(item_name: String, quantity: int = 1) -> bool:
	for i in range(items.size() - 1, -1, -1):  # Reverse loop for safe removal
		var item = items[i]
		if item.name == item_name:
			if item.quantity >= quantity:
				item.quantity -= quantity
				print("Removed %d %s" % [quantity, item_name])
				
				if item.quantity <= 0:
					items.remove_at(i)
				
				inventory_changed.emit()
				return true
			else:
				print("Not enough %s! Have %d, need %d" % [item_name, item.quantity, quantity])
				return false
	
	print("Don't have %s in inventory" % item_name)
	return false

func equip_item(item_name: String) -> bool:
	print(item_name)
	var item_to_equip = find_item(item_name)
	
	# DEBUG: Add these lines
	if item_to_equip:
		print("Found item: %s, type: %s" % [item_to_equip.name, Item.ItemType.keys()[item_to_equip.item_type]])
		print("Can be equipped: %s" % item_to_equip.can_be_equipped())
	else:
		print("Item not found: %s" % item_name)
		
	if not item_to_equip or not item_to_equip.can_be_equipped():
		print("Cannot equip %s" % item_name)
		return false
	
	if item_to_equip.is_equipped:
		print("%s is already equipped" % item_name)
		return false
	
	# Unequip any item in the same slot
	unequip_slot(item_to_equip.equipment_slot)
	
	# Equip the new item
	item_to_equip.is_equipped = true
	print("Equipped %s" % item_name)
	item_equipped.emit(item_to_equip)
	inventory_changed.emit()
	return true

func unequip_item(item_name: String) -> bool:
	var item_to_unequip = find_item(item_name)
	if not item_to_unequip or not item_to_unequip.is_equipped:
		print("Cannot unequip %s" % item_name)
		return false
	
	item_to_unequip.is_equipped = false
	print("Unequipped %s" % item_name)
	item_unequipped.emit(item_to_unequip)
	inventory_changed.emit()
	return true

func unequip_slot(slot: Item.EquipmentSlot) -> void:
	for item in items:
		if item.is_equipped and item.equipment_slot == slot:
			item.is_equipped = false
			print("Unequipped %s from slot" % item.name)
			item_unequipped.emit(item)
			break

# === USE ITEMS (CONSUMABLES) ===
func use_item(item_name: String) -> bool:
	var item_to_use = find_item(item_name)
	if not item_to_use or not item_to_use.can_be_consumed():
		print("Cannot use %s" % item_name)
		return false
	
	# Get player reference
	var player = get_parent()
	if not player:
		print("No player reference found")
		return false
	
	# Apply item effects
	var used_successfully = false
	
	if item_to_use.heal_amount > 0 and player.has_method("heal"):
		player.heal(item_to_use.heal_amount)
		print("Restored %d HP" % item_to_use.heal_amount)
		used_successfully = true
	
	if item_to_use.stamina_restore > 0 and player.has_method("restore_stamina"):
		player.restore_stamina(item_to_use.stamina_restore)
		print("Restored %d stamina" % item_to_use.stamina_restore)
		used_successfully = true
	
	if used_successfully:
		remove_item(item_name, 1)
		item_used.emit(item_to_use)
		return true
	
	return false

# === UTILITY METHODS ===
func find_item(item_name: String) -> Item:
	for item in items:
		print(item.name)
		if item.name == item_name:
			return item
	return null

func has_item(item_name: String, quantity: int = 1) -> bool:
	var item = find_item(item_name)
	return item != null and item.quantity >= quantity

func get_equipped_items() -> Array[Item]:
	var equipped: Array[Item] = []
	for item in items:
		if item.is_equipped:
			equipped.append(item)
	return equipped

func get_equipped_in_slot(slot: Item.EquipmentSlot) -> Item:
	for item in items:
		if item.is_equipped and item.equipment_slot == slot:
			return item
	return null

func get_total_attack_bonus() -> int:
	var total = 0
	for item in get_equipped_items():
		total += item.attack_bonus
	return total

func get_total_defense_bonus() -> int:
	var total = 0
	for item in get_equipped_items():
		total += item.defense_bonus
	return total

func get_total_speed_bonus() -> int:
	var total = 0
	for item in get_equipped_items():
		total += item.speed_bonus
	return total

# === GOLD MANAGEMENT ===
func add_gold(amount: int) -> void:
	gold += amount
	print("Gained %d gold (total: %d)" % [amount, gold])
	inventory_changed.emit()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		print("Spent %d gold (remaining: %d)" % [amount, gold])
		inventory_changed.emit()
		return true
	else:
		print("Not enough gold! Need %d, have %d" % [amount, gold])
		return false

# === DEBUG/DISPLAY ===
func print_inventory() -> void:
	print("=== INVENTORY ===")
	print("Gold: %d" % gold)
	
	if items.size() == 0:
		print("Inventory is empty")
		return
	
	print("Items:")
	for item in items:
		var equipped_text = " (EQUIPPED)" if item.is_equipped else ""
		print("- %s x%d%s" % [item.name, item.quantity, equipped_text])
		if item.has_combat_stats():
			print("  └ Attack: +%d | Defense: +%d | Speed: +%d" % [item.attack_bonus, item.defense_bonus, item.speed_bonus])

func print_equipped_gear() -> void:
	print("=== EQUIPPED GEAR ===")
	var equipped = get_equipped_items()
	if equipped.size() == 0:
		print("No equipment equipped")
		return
	
	for item in equipped:
		print("- %s (%s)" % [item.name, Item.EquipmentSlot.keys()[item.equipment_slot]])
		if item.has_combat_stats():
			print("  └ Attack: +%d | Defense: +%d | Speed: +%d" % [item.attack_bonus, item.defense_bonus, item.speed_bonus])

# === EXAMPLE USAGE ===
func add_starter_items() -> void:
	# Add some starter gear
	var iron_sword = Item.create_weapon("Iron Sword", 15, "A sturdy iron blade")
	var leather_armor = Item.create_armor("Leather Armor", 8, "Basic leather protection")
	var health_potions = Item.create_consumable("Health Potion", 30, 0, "Restores 30 HP")
	var stamina_potions = Item.create_consumable("Stamina Potion", 0, 50, "Restores 50 stamina")
	
	add_item(iron_sword)
	add_item(leather_armor) 
	add_item(health_potions, 3)
	add_item(stamina_potions, 2)
	add_gold(100)
	
	# Auto-equip starter gear
	equip_item("Iron Sword")
	equip_item("Leather Armor")

# Item.gd - Simple item class for RPG
extends Resource
class_name Item

# === CORE PROPERTIES ===
var name: String = ""
var description: String = ""
var item_type: ItemType = ItemType.MISC
var quantity: int = 1

# === EQUIPMENT STATS ===
var attack_bonus: int = 0
var defense_bonus: int = 0
var speed_bonus: int = 0

# === EQUIPMENT STATE ===
var is_equipped: bool = false
var equipment_slot: EquipmentSlot = EquipmentSlot.NONE

# === CONSUMABLE PROPERTIES ===
var heal_amount: int = 0
var stamina_restore: int = 0

# === ITEM PROPERTIES ===
var is_stackable: bool = true
var max_stack: int = 99
var value: int = 1  # Gold value for selling

# === ENUMS ===
enum ItemType {
	MISC,
	CONSUMABLE,
	WEAPON,
	ARMOR,
	ACCESSORY
}

enum EquipmentSlot {
	NONE,
	WEAPON,
	ARMOR,
	ACCESSORY
}

# === CONSTRUCTOR ===
func _init(item_name: String = "", type: ItemType = ItemType.MISC):
	name = item_name
	item_type = type
	
	# Set default properties based on type
	match type:
		ItemType.CONSUMABLE:
			is_stackable = true
			max_stack = 99
			equipment_slot = EquipmentSlot.NONE
		
		ItemType.WEAPON:
			is_stackable = false
			max_stack = 1
			equipment_slot = EquipmentSlot.WEAPON
		
		ItemType.ARMOR:
			is_stackable = false
			max_stack = 1
			equipment_slot = EquipmentSlot.ARMOR
		
		ItemType.ACCESSORY:
			is_stackable = false
			max_stack = 1
			equipment_slot = EquipmentSlot.ACCESSORY
		
		ItemType.MISC:
			is_stackable = true
			max_stack = 99
			equipment_slot = EquipmentSlot.NONE

# === UTILITY METHODS ===

func can_stack_with(other_item: Item) -> bool:
	if not is_stackable or not other_item.is_stackable:
		return false
	return name == other_item.name

func can_be_equipped() -> bool:
	return item_type in [ItemType.WEAPON, ItemType.ARMOR, ItemType.ACCESSORY]

func can_be_consumed() -> bool:
	return item_type == ItemType.CONSUMABLE

func get_total_value() -> int:
	return value * quantity

func has_combat_stats() -> bool:
	return attack_bonus > 0 or defense_bonus > 0 or speed_bonus > 0

# === ITEM CREATION HELPERS ===

static func create_weapon(item_name: String, attack: int, desc: String = "") -> Item:
	var item = Item.new(item_name, ItemType.WEAPON)
	item.attack_bonus = attack
	item.description = desc
	return item

static func create_armor(item_name: String, defense: int, desc: String = "") -> Item:
	var item = Item.new(item_name, ItemType.ARMOR)
	item.defense_bonus = defense
	item.description = desc
	return item

static func create_consumable(item_name: String, heal: int = 0, stamina: int = 0, desc: String = "") -> Item:
	var item = Item.new(item_name, ItemType.CONSUMABLE)
	item.heal_amount = heal
	item.stamina_restore = stamina
	item.description = desc
	return item

static func create_misc(item_name: String, desc: String = "", gold_value: int = 1) -> Item:
	var item = Item.new(item_name, ItemType.MISC)
	item.description = desc
	item.value = gold_value
	return item

# === DEBUG ===
func print_item_info():
	print("=== %s ===" % name)
	print("Type: %s" % ItemType.keys()[item_type])
	print("Quantity: %d" % quantity)
	if description != "":
		print("Description: %s" % description)
	if has_combat_stats():
		print("Attack: +%d | Defense: +%d | Speed: +%d" % [attack_bonus, defense_bonus, speed_bonus])
	if can_be_consumed():
		print("Heal: +%d HP | Stamina: +%d" % [heal_amount, stamina_restore])
	print("Value: %d gold each" % value)
	print("Equipped: %s" % str(is_equipped))

func clone() -> Item:
	var new_item = Item.new(name, item_type)
	new_item.description = description
	new_item.attack_bonus = attack_bonus
	new_item.defense_bonus = defense_bonus
	new_item.speed_bonus = speed_bonus
	new_item.heal_amount = heal_amount
	new_item.stamina_restore = stamina_restore
	new_item.value = value
	new_item.max_stack = max_stack
	new_item.is_stackable = is_stackable
	new_item.equipment_slot = equipment_slot
	# Don't copy quantity or is_equipped - those are instance-specific
	return new_item

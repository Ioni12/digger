# Item.gd - Enhanced item class with digging tools
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

# === DIGGING TOOL PROPERTIES ===
var dig_speed_multiplier: float = 1.0  # 2.0 = twice as fast
var dig_pattern: String = "single"     # "single", "cross", "square", "line"
var dig_range: int = 1                 # Size of the digging area
var stamina_efficiency: float = 1.0    # 0.5 = half stamina cost

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
	ACCESSORY,
	TOOL  # New tool type
}

enum EquipmentSlot {
	NONE,
	WEAPON,
	ARMOR,
	ACCESSORY,
	TOOL  # New tool slot
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
		
		ItemType.TOOL:  # New tool type setup
			is_stackable = false
			max_stack = 1
			equipment_slot = EquipmentSlot.TOOL
		
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
	return item_type in [ItemType.WEAPON, ItemType.ARMOR, ItemType.ACCESSORY, ItemType.TOOL]

func can_be_consumed() -> bool:
	return item_type == ItemType.CONSUMABLE

func is_digging_tool() -> bool:
	return item_type == ItemType.TOOL

func get_total_value() -> int:
	return value * quantity

func has_combat_stats() -> bool:
	return attack_bonus > 0 or defense_bonus > 0 or speed_bonus > 0

func has_digging_properties() -> bool:
	return dig_speed_multiplier != 1.0 or dig_pattern != "single" or stamina_efficiency != 1.0

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

# === NEW: DIGGING TOOL CREATION ===
static func create_digging_tool(item_name: String, speed_mult: float, pattern: String, range_val: int = 1, stamina_eff: float = 1.0, desc: String = "", gold_value: int = 50) -> Item:
	var tool = Item.new(item_name, ItemType.TOOL)
	tool.dig_speed_multiplier = speed_mult
	tool.dig_pattern = pattern
	tool.dig_range = range_val
	tool.stamina_efficiency = stamina_eff
	tool.description = desc
	tool.value = gold_value
	return tool

# === PREDEFINED DIGGING TOOLS ===
static func create_basic_shovel() -> Item:
	return create_digging_tool("Basic Shovel", 1.2, "single", 1, 0.9, "A sturdy shovel for basic digging", 25)

static func create_iron_pickaxe() -> Item:
	return create_digging_tool("Iron Pickaxe", 1.5, "single", 1, 1.0, "Good for rocky terrain", 75)

static func create_mining_drill() -> Item:
	return create_digging_tool("Mining Drill", 2.0, "cross", 1, 1.3, "Digs in a cross pattern", 200)

static func create_excavator_shovel() -> Item:
	return create_digging_tool("Excavator Shovel", 1.3, "square", 1, 1.5, "Digs a 3x3 area", 150)

static func create_tunnel_bore() -> Item:
	return create_digging_tool("Tunnel Bore", 2.2, "line", 2, 1.2, "Creates tunnels efficiently", 300)

static func create_power_drill() -> Item:
	return create_digging_tool("Power Drill", 3.0, "cross", 1, 2.0, "High-speed drilling with high stamina cost", 500)

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
	if has_digging_properties():
		print("Dig Speed: x%.1f | Pattern: %s | Range: %d | Stamina Efficiency: x%.1f" % [dig_speed_multiplier, dig_pattern, dig_range, stamina_efficiency])
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
	new_item.dig_speed_multiplier = dig_speed_multiplier
	new_item.dig_pattern = dig_pattern
	new_item.dig_range = dig_range
	new_item.stamina_efficiency = stamina_efficiency
	new_item.value = value
	new_item.max_stack = max_stack
	new_item.is_stackable = is_stackable
	new_item.equipment_slot = equipment_slot
	# Don't copy quantity or is_equipped - those are instance-specific
	return new_item

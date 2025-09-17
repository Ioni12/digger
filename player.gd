# Player.gd - Updated to integrate with new inventory system
extends Node2D
class_name Player

# Component references
@onready var stats: PlayerStats = $PlayerStats
@onready var stamina_system: StaminaSystem = $StaminaSystem
@onready var movement: PlayerMovement = $PlayerMovement
@onready var visual: PlayerVisual = $PlayerVisual
@onready var inventory: PlayerInventory = $PlayerInventory

# Maintain original signals for backward compatibility
signal health_changed(current_hp: int, max_hp: int)
signal stamina_changed(current_stamina: int, max_stamina: int)
signal stats_changed()
signal level_up(new_level: int)

# Environment reference - forwards to components
var environment: GameEnviroment:
	set(value):
		_environment = value
		if movement:
			movement.environment = value
		if visual:
			visual.environment = value
	get:
		return _environment
var _environment: GameEnviroment

# Backward compatibility properties
var player_name: String:
	get: return stats.data.player_name if stats else "Hero"
var level: int:
	get: return stats.data.level if stats else 1
var max_hp: int:
	get: return stats.data.max_hp if stats else 100
var current_hp: int:
	get: return stats.data.current_hp if stats else 100
var base_attack: int:
	get: return stats.data.base_attack if stats else 25
var base_defense: int:
	get: return stats.data.base_defense if stats else 15
var base_speed: int:
	get: return stats.data.base_speed if stats else 12
var exp: int:
	get: return stats.data.exp if stats else 0
var exp_to_next: int:
	get: return stats.data.exp_to_next if stats else 100
var max_stamina: int:
	get: return stats.data.max_stamina if stats else 100
var stamina: int:
	get: return stats.data.current_stamina if stats else 100

# Combat stats (now include equipment bonuses from inventory)
var current_attack: int:
	get: 
		var base_attack = stats.data.base_attack if stats else 25
		var equipment_bonus = inventory.get_total_attack_bonus() if inventory else 0
		return base_attack + equipment_bonus

var current_defense: int:
	get: 
		var base_defense = stats.data.base_defense if stats else 15
		var equipment_bonus = inventory.get_total_defense_bonus() if inventory else 0
		return base_defense + equipment_bonus

var current_speed: int:
	get: 
		var base_speed = stats.data.current_speed if stats else 12
		var equipment_bonus = inventory.get_total_speed_bonus() if inventory else 0
		return base_speed + equipment_bonus

var is_defending: bool:
	get: return stats.data.is_defending if stats else false

# Movement properties
var grid_x: int:
	get: return movement.grid_x if movement else 0
var grid_y: int:
	get: return movement.grid_y if movement else 0
var current_state:
	get: return movement.current_state if movement else 0
var is_moving: bool:
	get: return movement.is_moving if movement else false

# Gold property for convenience
var gold: int:
	get: return inventory.gold if inventory else 0

func _ready() -> void:
	# Ensure components exist
	_setup_component("PlayerStats", PlayerStats)
	_setup_component("StaminaSystem", StaminaSystem) 
	_setup_component("PlayerMovement", PlayerMovement)
	_setup_component("PlayerVisual", PlayerVisual)
	_setup_component("PlayerInventory", PlayerInventory)
	
	# Give starter gear and setup inventory
	setup_inventory()
	
	# Connect component signals
	_connect_signals()
	
	# Setup movement references
	if movement and environment:
		movement.environment = environment
		movement.target_position = Vector2(movement.grid_x * environment.SIZE, movement.grid_y * environment.SIZE)
	
	if visual and environment:
		visual.environment = environment
	
	# Connect to EncounterManager
	if EncounterManager:
		EncounterManager.battle_started.connect(_on_battle_started)
		EncounterManager.battle_ended.connect(_on_battle_ended)
	else:
		print("No encounter manager found")

func _setup_component(node_name: String, component_class):
	if not has_node(node_name):
		var component_node = component_class.new()
		component_node.name = node_name
		add_child(component_node)
		
		# Update reference
		match node_name:
			"PlayerStats":
				stats = component_node
			"StaminaSystem":
				stamina_system = component_node
			"PlayerMovement":
				movement = component_node
			"PlayerVisual":
				visual = component_node
			"PlayerInventory":
				inventory = component_node

func setup_inventory():
	if inventory:
		inventory.add_starter_items()
		print("Player inventory initialized with starter items")

func _connect_signals():
	if stats:
		stats.health_changed.connect(_on_health_changed)
		stats.level_up.connect(_on_level_up)
		stats.stats_changed.connect(_on_stats_changed)
	
	if stamina_system:
		stamina_system.stamina_changed.connect(_on_stamina_changed)
	
	if inventory:
		inventory.inventory_changed.connect(_on_inventory_changed)
		inventory.item_equipped.connect(_on_item_equipped)
		inventory.item_unequipped.connect(_on_item_unequipped)

func _process(delta: float) -> void:
	# Components handle their own processing
	pass

# === SIGNAL FORWARDING ===
func _on_health_changed(current: int, max_val: int):
	health_changed.emit(current, max_val)

func _on_stamina_changed(current: int, max_val: int):
	stamina_changed.emit(current, max_val)

func _on_level_up(new_level: int):
	level_up.emit(new_level)

func _on_stats_changed():
	stats_changed.emit()

func _on_inventory_changed():
	# Equipment changed, so stats might have changed
	stats_changed.emit()

func _on_item_equipped(item: Item):
	print("Equipped %s - Attack: +%d, Defense: +%d" % [item.name, item.attack_bonus, item.defense_bonus])
	stats_changed.emit()

func _on_item_unequipped(item: Item):
	print("Unequipped %s" % item.name)
	stats_changed.emit()

# === BACKWARD COMPATIBILITY METHODS ===
func get_stats_dictionary() -> Dictionary:
	var stats_dict = stats.get_stats_dictionary() if stats else {}
	
	# Add inventory data
	if inventory:
		stats_dict["gold"] = inventory.gold
		stats_dict["items"] = []
		for item in inventory.items:
			stats_dict["items"].append({
				"name": item.name,
				"type": item.item_type,
				"quantity": item.quantity,
				"is_equipped": item.is_equipped
			})
	
	return stats_dict

func load_stats_from_dictionary(stats_dict: Dictionary):
	if stats:
		stats.load_stats_from_dictionary(stats_dict)
	
	# Load inventory data
	if inventory and stats_dict.has("gold"):
		inventory.gold = stats_dict["gold"]
		
		if stats_dict.has("items"):
			inventory.items.clear()
			for item_data in stats_dict["items"]:
				var item = Item.new(item_data["name"], item_data["type"])
				item.quantity = item_data["quantity"]
				item.is_equipped = item_data.get("is_equipped", false)
				inventory.items.append(item)

# === INVENTORY METHODS ===
func add_item(item: Item, quantity: int = 1):
	if inventory:
		inventory.add_item(item, quantity)

func add_item_by_name(item_name: String, item_type: Item.ItemType, quantity: int = 1):
	if inventory:
		inventory.add_item_by_name(item_name, item_type, quantity)

func remove_item(item_name: String, quantity: int = 1) -> bool:
	return inventory.remove_item(item_name, quantity) if inventory else false

func has_item(item_name: String, quantity: int = 1) -> bool:
	return inventory.has_item(item_name, quantity) if inventory else false

func use_item(item_name: String) -> bool:
	return inventory.use_item(item_name) if inventory else false

func equip_item(item_name: String) -> bool:
	return inventory.equip_item(item_name) if inventory else false

func unequip_item(item_name: String) -> bool:
	return inventory.unequip_item(item_name) if inventory else false

func add_gold(amount: int):
	if inventory:
		inventory.add_gold(amount)

func spend_gold(amount: int) -> bool:
	return inventory.spend_gold(amount) if inventory else false

# === ORIGINAL METHODS (Updated to work with inventory) ===
func reset_combat_stats():
	if stats:
		stats.reset_combat_stats()

func gain_exp(amount: int):
	if stats:
		stats.gain_exp(amount)

func level_up_character():
	if stats:
		stats.level_up_character()

func take_damage(damage: int):
	return stats.take_damage(damage) if stats else 0

func heal(amount: int):
	return stats.heal(amount) if stats else 0

func is_alive() -> bool:
	return stats.is_alive() if stats else true

func get_health_percentage() -> float:
	return stats.get_health_percentage() if stats else 1.0

func defend():
	if stats:
		stats.defend()

func act():
	if stats:
		stats.act()

func advance_time():
	if stats:
		stats.advance_time()

func get_speed_with_fatigue() -> int:
	return stats.data.get_speed_with_fatigue() if stats else 12

func get_current_defense() -> int:
	# This now includes equipment bonuses automatically via current_defense property
	return current_defense

# Stamina methods
func consume_stamina(amount: int):
	if stamina_system:
		stamina_system.consume_stamina(amount)

func restore_stamina(amount: int):
	if stamina_system:
		stamina_system.restore_stamina(amount)

# Movement methods
func get_current_tile() -> GameEnviroment.TileType:
	return movement.get_current_tile() if movement else GameEnviroment.TileType.DRY

func check_for_encounter(current_tile):
	if movement:
		movement.check_for_encounter(current_tile)

# Battle event handlers
func _on_battle_started():
	print("Player: Battle started, completing current movement")
	if movement:
		movement.on_battle_started()
	
	if stats:
		stats.reset_combat_stats()

func _on_battle_ended(won: bool, exp_gained: int):
	if won and stats:
		stats.gain_exp(exp_gained)
	
	if stats:
		stats.health_changed.emit(stats.data.current_hp, stats.data.max_hp)

# Debug methods
func debug_modify_stamina(amount: int):
	if stamina_system:
		stamina_system.debug_modify_stamina(amount)

func print_stats():
	if stats:
		stats.print_stats()
	if stamina_system and stats:
		print("Stamina: %d/%d | Exhaustion Level: %d" % [stats.data.stamina, stats.data.max_stamina, stats.data.exhaustion_level])
	
	print("Combat Stats (with equipment):")
	print("Attack: %d | Defense: %d | Speed: %d" % [current_attack, current_defense, current_speed])

func print_inventory():
	if inventory:
		inventory.print_inventory()

func print_equipped_gear():
	if inventory:
		inventory.print_equipped_gear()

# === REMOVED OLD EQUIPMENT METHODS ===
# The following methods are no longer needed since we use inventory:
# - give_starter_gear() -> replaced with setup_inventory()
# - equip_weapon() -> replaced with equip_item()
# - equip_armor() -> replaced with equip_item()
# - get_attack_bonus() -> replaced with inventory.get_total_attack_bonus()
# - get_defense_bonus() -> replaced with inventory.get_total_defense_bonus()

extends Node2D
class_name Player

@onready var stats: PlayerStats = $PlayerStats
@onready var stamina_system: StaminaSystem = $StaminaSystem
@onready var movement: PlayerMovement = $PlayerMovement
@onready var visual: PlayerVisual = $PlayerVisual
@onready var inventory: PlayerInventory = $PlayerInventory
@onready var interaction: PlayerInteraction = $PlayerInteraction

signal health_changed(current_hp: int, max_hp: int)
signal stamina_changed(current_stamina: int, max_stamina: int)
signal stats_changed()
signal level_up(new_level: int)
signal npc_interaction(npc_name: String, message: String, interaction_data: Dictionary)

var environment: GameEnviroment:
	set(value):
		_environment = value
		if movement:
			movement.environment = value
		if visual:
			visual.environment = value
		if interaction:
			interaction.setup_dependencies(movement, value)
	get:
		return _environment
var _environment: GameEnviroment

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


var current_attack: int:
	get: 
		var base_attack = stats.data.base_attack 
		var equipment_bonus = inventory.get_total_attack_bonus() 
		return base_attack + equipment_bonus

var current_defense: int:
	get: 
		var base_defense = stats.data.base_defense 
		var equipment_bonus = inventory.get_total_defense_bonus() 
		return base_defense + equipment_bonus

var current_speed: int:
	get: 
		var base_speed = stats.data.current_speed 
		var equipment_bonus = inventory.get_total_speed_bonus() 
		return base_speed + equipment_bonus

var is_defending: bool:
	get: return stats.data.is_defending if stats else false


var grid_x: int:
	get: return movement.grid_x 
var grid_y: int:
	get: return movement.grid_y 
var current_state:
	get: return movement.current_state 
var is_moving: bool:
	get: return movement.is_moving if movement else false

# Gold property for convenience
var gold: int:
	get: return inventory.gold 

func _ready() -> void:
	_setup_component("PlayerStats", PlayerStats)
	_setup_component("StaminaSystem", StaminaSystem) 
	_setup_component("PlayerMovement", PlayerMovement)
	_setup_component("PlayerVisual", PlayerVisual)
	_setup_component("PlayerInventory", PlayerInventory)
	_setup_component("PlayerInteraction", PlayerInteraction)
	
	setup_inventory()
	
	_connect_signals()
	
	# Setup component dependencies
	_setup_component_dependencies()
	
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
			"PlayerInteraction":
				interaction = component_node

func _setup_component_dependencies():
	"""Setup dependencies between components"""
	if interaction and movement and environment:
		interaction.setup_dependencies(movement, environment)

func setup_inventory():
	if inventory:
		inventory.add_starter_items()

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
	
	if interaction:
		interaction.dialogue_started.connect(_on_dialogue_started)
		interaction.dialogue_ended.connect(_on_dialogue_ended)


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

# === NEW INTERACTION SIGNAL HANDLERS ===
func _on_dialogue_started(npc: WorldNPC, message: String, npc_data: Dictionary):
	npc_interaction.emit(npc, message, npc_data)


func _on_dialogue_ended():
	"""Handle when dialogue ends"""
	print("Player: Dialogue session ended")

# === BACKWARD COMPATIBILITY METHODS ===
func get_stats_dictionary() -> Dictionary:
	var stats_dict = stats.get_stats_dictionary() if stats else {}
	
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

# === ORIGINAL METHODS ===
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

# === INTERACTION METHODS (Updated to use PlayerInteraction component) ===
func try_interact_with_npc() -> bool:
	"""Try to interact with an adjacent NPC. Returns true if interaction occurred."""
	return interaction.try_start_dialogue() if interaction else false

func has_adjacent_npc() -> bool:
	"""Check if there's an NPC adjacent to the player"""
	return interaction.can_start_dialogue() if interaction else false

func get_interaction_prompt() -> String:
	"""Get text to display when near an NPC"""
	return interaction.get_dialogue_prompt() if interaction else ""

func end_dialogue():
	"""End current dialogue"""
	if interaction:
		interaction.end_dialogue()

func check_npc_interaction_input():
	"""Alternative: Call this from your input handling code"""
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		try_interact_with_npc()

# Battle event handlers
func _on_battle_started():
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

func print_inventory():
	if inventory:
		inventory.print_inventory()

func print_equipped_gear():
	if inventory:
		inventory.print_equipped_gear()

func debug_interaction_state():
	"""Debug method for interaction system"""
	if interaction:
		interaction.debug_print_state()

extends Node

signal battle_started
signal battle_ended(won: bool, exp_gained: int)

var encounter_rates = {
	GameEnviroment.TileType.DRY: 0.15,
	GameEnviroment.TileType.ROCKY: 0.25,
}

var enemy_data = {
	GameEnviroment.TileType.DRY: [
		{"name": "Desert Rat", "hp": 60, "attack": 15, "defense": 15, "speed": 14, "weight": 50, "exp": 25},
		{"name": "Sand Viper", "hp": 45, "attack": 23, "defense": 12, "speed": 16, "weight": 30, "exp": 35},
		{"name": "Dust Devil", "hp": 80, "attack": 20, "defense": 20, "speed": 12, "weight": 20, "exp": 45},
	],
	GameEnviroment.TileType.ROCKY: [
		{"name": "Stone Golem", "hp": 120, "attack": 30, "defense": 40, "speed": 6, "weight": 40, "exp": 60},
		{"name": "Cave Troll", "hp": 150, "attack": 34, "defense": 25, "speed": 8, "weight": 25, "exp": 80},
		{"name": "Rock Lizard", "hp": 90, "attack": 26, "defense": 30, "speed": 10, "weight": 35, "exp": 50},
	]
}

var current_enemy_data = {}
var is_in_battle = false

# Reference to the actual player object instead of storing stats here
var player_reference: Player

func _ready():
	battle_ended.connect(_on_battle_ended)

func set_player_reference(player: Player):
	"""Call this from your main game scene to set the player reference"""
	player_reference = player
	print("EncounterManager: Player reference set")

func check_encounter(tile_type: GameEnviroment.TileType) -> bool:
	if is_in_battle:
		return false
	
	if not encounter_rates.has(tile_type):
		return false
	
	var encounter_chance = encounter_rates[tile_type]
	var roll = randf()
	
	print("Encounter check: ", roll, " vs ", encounter_chance, " on tile ", tile_type)
	
	if roll < encounter_chance:
		return trigger_encounter(tile_type)
	
	return false

func trigger_encounter(tile_type: GameEnviroment.TileType) -> bool:
	if not enemy_data.has(tile_type):
		print("No enemy data for tile type: ", tile_type)
		return false
		
	var possible_enemies = enemy_data[tile_type]
	var selected_enemy = selected_weighted_enemy(possible_enemies)
	
	if selected_enemy.is_empty():
		print("Failed to select enemy")
		return false
	
	current_enemy_data = selected_enemy
	start_battle()
	return true

func selected_weighted_enemy(enemies: Array) -> Dictionary:
	if enemies.is_empty():
		return {}
	
	var total_weight = 0
	for enemy in enemies:
		total_weight += enemy.get("weight", 1)
	
	var roll = randf() * total_weight
	var current_weight = 0
	
	for enemy in enemies:
		current_weight += enemy.get("weight", 1)
		if roll <= current_weight:
			return enemy
	return enemies[0]

func start_battle():
	if not player_reference:
		print("ERROR: No player reference set!")
		return
	
	is_in_battle = true
	print("Starting battle with: ", current_enemy_data.get("name", "Unknown"))
	print("Enemy data: ", current_enemy_data)
	print("Player stats: ", player_reference.get_stats_dictionary())
	
	if current_enemy_data.is_empty():
		print("ERROR: No enemy data!")
		is_in_battle = false
		return
	
	battle_started.emit()
	create_battle_popup()

func create_battle_popup():
	var battle_popup = PopupPanel.new()
	battle_popup.size = Vector2(800, 600)
	battle_popup.position = (get_viewport().size - battle_popup.size) / 2
	battle_popup.set_flag(Window.FLAG_RESIZE_DISABLED, true)
	
	var battle_system_scene = preload("res://battle_system.tscn")
	var battle_system = battle_system_scene.instantiate()
	
	battle_popup.add_child(battle_system)
	
	get_tree().current_scene.add_child(battle_popup)
	
	battle_popup.popup()
	
	get_tree().paused = true
	battle_popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	battle_system.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	battle_popup.popup_hide.connect(_on_battle_popup_closed)

func _on_battle_ended(won: bool, exp_gained: int = 0):
	is_in_battle = false
	
	if won and player_reference:
		print("Victory! Player will gain ", exp_gained, " EXP")
		# The player handles its own EXP gain now
	else:
		print("Defeat")
	
	var battle_popups = get_tree().get_nodes_in_group("battle_popup")
	for popup in battle_popups:
		popup.queue_free()
	
	get_tree().paused = false

# These functions now delegate to the player reference
func get_current_enemy() -> Dictionary:
	print("get_current_enemy() called, returning: ", current_enemy_data)
	return current_enemy_data

func get_player_stats() -> Dictionary:
	if player_reference:
		var stats = player_reference.get_stats_dictionary()
		print("get_player_stats() called, returning: ", stats)
		return stats
	else:
		print("ERROR: No player reference!")
		return {}

func update_player_stats(new_stats: Dictionary):
	if player_reference:
		# This method is now less needed since we work directly with the player
		# But we can keep it for backward compatibility
		player_reference.load_stats_from_dictionary(new_stats)
	else:
		print("ERROR: No player reference!")

func _on_battle_popup_closed():
	get_tree().paused = false
	is_in_battle = false

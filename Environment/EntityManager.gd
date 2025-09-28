extends Node2D
class_name EntityManager


var enemies: Array[WorldEnemy] = []
var npcs: Array[WorldNPC] = []

# References
var game_environment: GameEnviroment  
var player_reference: Player

# Spawn configuration
var enemy_spawn_count_min: int = 3
var enemy_spawn_count_max: int = 5
var npc_spawn_count_min: int = 2
var npc_spawn_count_max: int = 4

# Available NPC types for variety
var available_npc_types: Array[WorldNPC.NPCType] = [
	WorldNPC.NPCType.TRADER,
	WorldNPC.NPCType.GUIDE,
	WorldNPC.NPCType.SCHOLAR,
	WorldNPC.NPCType.HERMIT
]

func _init(env: GameEnviroment):  # Fixed: changed from GameEnvironment to GameEnviroment
	game_environment = env

func _ready():
	set_process(true)

func _process(delta):
	check_enemy_encounters()
	check_npc_interactions()

# ===== SPAWNING SYSTEM =====

func spawn_all_entities():
	"""Spawn both enemies and NPCs in the world"""
	spawn_enemies()
	spawn_npcs()

func spawn_enemies():
	var enemy_count = randi_range(enemy_spawn_count_min, enemy_spawn_count_max)
	var structure_tiles = game_environment.get_structure_digged_tiles()
	
	for i in enemy_count:
		if structure_tiles.size() > 0:
			var tile = structure_tiles[randi() % structure_tiles.size()]
			if tile.x == game_environment.WIDTH/2 and tile.y == 0:
				continue
			spawn_enemy_at(tile.x, tile.y)
			structure_tiles.erase(tile)

func spawn_npcs():
	var npc_count = randi_range(npc_spawn_count_min, npc_spawn_count_max)
	var structure_tiles = get_structure_digged_tiles()
	
	var available_tiles = []
	for tile in structure_tiles:
		var has_enemy = false
		for enemy in enemies:
			if enemy.get_grid_position() == tile:
				has_enemy = true
				break
		
		if not has_enemy:
			available_tiles.append(tile)
	
	var npc_types = [WorldNPC.NPCType.TRADER, WorldNPC.NPCType.GUIDE, WorldNPC.NPCType.SCHOLAR, WorldNPC.NPCType.HERMIT]
	
	for i in min(npc_count, available_tiles.size()):
		if available_tiles.size() > 0:
			var tile = available_tiles[randi() % available_tiles.size()]
			var npc_type = npc_types[i % npc_types.size()]  # Cycle through types
			spawn_npc_at(tile.x, tile.y, npc_type)
			available_tiles.erase(tile)

func spawn_enemy_at(x: int, y: int):
	"""Create and add enemy at specific coordinates"""
	var enemy = WorldEnemy.new(game_environment)
	enemy.position = Vector2(x * game_environment.SIZE, y * game_environment.SIZE)
	enemies.append(enemy)
	add_child(enemy)

func spawn_npc_at(x: int, y: int, npc_type: WorldNPC.NPCType = WorldNPC.NPCType.TRADER):
	"""Create and add NPC at specific coordinates"""
	var npc = WorldNPC.new(game_environment, npc_type)
	npc.position = Vector2(x * game_environment.SIZE, y * game_environment.SIZE)
	npcs.append(npc)
	add_child(npc)

# ===== SPAWN LOCATION LOGIC =====

func get_enemy_spawn_locations() -> Array[Vector2i]:
	"""Get valid tiles for enemy spawning (structure areas only)"""
	var structure_tiles = get_structure_digged_tiles()
	var player_start = Vector2i(game_environment.WIDTH / 2, 0)
	
	# Remove player starting position
	structure_tiles = structure_tiles.filter(func(tile): return tile != player_start)
	
	# Shuffle for randomness
	structure_tiles.shuffle()
	return structure_tiles

func get_npc_spawn_locations() -> Array[Vector2i]:
	"""Get valid tiles for NPC spawning (excluding enemy positions)"""
	var available_tiles = get_structure_digged_tiles()
	var player_start = Vector2i(game_environment.WIDTH / 2, 0)
	
	# Remove player starting position
	available_tiles = available_tiles.filter(func(tile): return tile != player_start)
	
	# Remove tiles occupied by enemies
	for enemy in enemies:
		var enemy_pos = enemy.get_grid_position()
		available_tiles = available_tiles.filter(func(tile): return tile != enemy_pos)
	
	available_tiles.shuffle()
	return available_tiles

func get_structure_digged_tiles() -> Array[Vector2i]:
	"""Get all digged tiles that are part of structures"""
	var structure_digged: Array[Vector2i] = []  # Fixed: explicitly typed array
	
	for x in range(game_environment.WIDTH):
		for y in range(game_environment.HEIGHT):
			if game_environment.grid_data[y][x] == GameEnviroment.TileType.DIGGED:
				structure_digged.append(Vector2i(x, y))
	
	return structure_digged

# ===== INTERACTION SYSTEM =====

func check_enemy_encounters():
	"""Check if player stepped on enemy tile"""
	var player_grid = get_player_grid_position()
	
	# Check backwards to safely remove during iteration
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		var enemy_grid = enemy.get_grid_position()
		
		if enemy_grid == player_grid:
			trigger_enemy_encounter(enemy, i)

func check_npc_interactions():
	"""Check for nearby NPCs (for UI prompts, etc.)"""
	for npc in npcs:
		if npc.is_adjacent_to_player():
			# Can add visual indicators here
			# Actual interaction handled by input system
			pass

func trigger_enemy_encounter(enemy: WorldEnemy, index: int):
	"""Handle enemy encounter and cleanup"""
	var enemy_position = enemy.get_grid_position()
	var tile_type = game_environment.get_tile_at(enemy_position.x, enemy_position.y)
	
	# Remove enemy from world
	remove_enemy_at_index(index)
	
	# Trigger battle system
	var encounter_tile_type = GameEnviroment.TileType.DRY if tile_type == GameEnviroment.TileType.DRY else GameEnviroment.TileType.ROCKY  # Fixed: changed from GameEnvironment to GameEnviroment
	EncounterManager.trigger_encounter(encounter_tile_type)

# ===== ENTITY QUERIES =====

func get_npc_at_position(grid_x: int, grid_y: int) -> WorldNPC:
	"""Get NPC at specific grid position"""
	for npc in npcs:
		var npc_grid = npc.get_grid_position()
		if npc_grid.x == grid_x and npc_grid.y == grid_y:
			return npc
	return null

func get_adjacent_npc() -> WorldNPC:
	"""Get NPC adjacent to player"""
	for npc in npcs:
		if npc.is_adjacent_to_player():
			return npc
	return null

func get_enemy_at_position(grid_x: int, grid_y: int) -> WorldEnemy:
	"""Get enemy at specific grid position"""
	for enemy in enemies:
		var enemy_grid = enemy.get_grid_position()
		if enemy_grid.x == grid_x and enemy_grid.y == grid_y:
			return enemy
	return null

# ===== ENTITY MANAGEMENT =====

func remove_npc(npc: WorldNPC):
	"""Remove specific NPC from the world"""
	var index = npcs.find(npc)
	if index != -1:
		npcs.remove_at(index)
		npc.queue_free()

func remove_enemy_at_index(index: int):
	"""Remove enemy at specific index"""
	if index >= 0 and index < enemies.size():
		var enemy = enemies[index]
		enemies.remove_at(index)
		enemy.queue_free()

func clear_all_entities():
	"""Remove all entities from the world"""
	for enemy in enemies:
		enemy.queue_free()
	for npc in npcs:
		npc.queue_free()
	
	enemies.clear()
	npcs.clear()

# ===== CONFIGURATION =====

func set_spawn_parameters(enemy_min: int, enemy_max: int, npc_min: int, npc_max: int):
	"""Configure spawn counts"""
	enemy_spawn_count_min = enemy_min
	enemy_spawn_count_max = enemy_max
	npc_spawn_count_min = npc_min
	npc_spawn_count_max = npc_max

func set_available_npc_types(types: Array[WorldNPC.NPCType]):
	"""Set which NPC types can spawn"""
	available_npc_types = types

# ===== UTILITY =====

func get_player_grid_position() -> Vector2i:
	"""Get current player grid position"""
	if player_reference:
		return Vector2i(
			int(player_reference.position.x / game_environment.SIZE), 
			int(player_reference.position.y / game_environment.SIZE)
		)
	else:
		# Fallback if no player reference - you'll need to add player_position to GameEnviroment
		# or get it through another method
		return Vector2i(game_environment.WIDTH / 2, 0)  # Default to spawn position

func set_player_reference(player: Player):
	"""Set reference to player for position tracking"""
	player_reference = player

# ===== DEBUG/INFO =====

func get_entity_counts() -> Dictionary:
	"""Get current entity counts for debugging"""
	return {
		"enemies": enemies.size(),
		"npcs": npcs.size(),
		"total": enemies.size() + npcs.size()
	}

func print_entity_info():
	"""Debug function to print entity information"""
	print("=== Entity Manager Info ===")
	print("Enemies: ", enemies.size())
	print("NPCs: ", npcs.size())
	
	for i in range(enemies.size()):
		var pos = enemies[i].get_grid_position()
		print("  Enemy ", i, " at (", pos.x, ", ", pos.y, ")")
	
	for i in range(npcs.size()):
		var pos = npcs[i].get_grid_position()
		print("  NPC ", i, " at (", pos.x, ", ", pos.y, ")")

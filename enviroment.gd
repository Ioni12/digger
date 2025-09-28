extends Node2D
class_name GameEnviroment

const SIZE = 98
const WIDTH = 300
const HEIGHT = 30

enum TileType {
	DRY,
	ROCKY,
	DIGGED,
}

var tile_dig_speeds: Dictionary = {
	TileType.DRY: 0,     # Fast to dig
	TileType.ROCKY: 1.5,   # Slow to dig
	TileType.DIGGED: 0.0    # Already dug, no digging needed
}

var grid_data: Array[Array] = []
var tile_textures: Dictionary = {}
var cluster_size: float = 0.1
var noise_seed: int = 0
var dry_amount: float = -0.08
var noise: FastNoiseLite
var fog_of_war: FogOfWarSystem
var structure_generator: StructureGenerator
var rng: RandomNumberGenerator

# Structure generation parameters
var structure_spawn_chance: float = 0.15  # 15% chance per attempt
var max_structures: int = 8
var current_structure_count: int = 0
var min_distance_between_structures: int = 5
var structure_areas: Array[Dictionary] = []
var structure_background_textures: Dictionary = {}

# Enemy system - minimal addition
var enemies: Array[WorldEnemy] = []
var npcs: Array[WorldNPC] = []
var player_position: Vector2 = Vector2((WIDTH/2) * SIZE, 0 * SIZE)
var player_reference: Player

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	load_textures()
	setup_noise()
	setup_grid_with_noise()
	fog_of_war = FogOfWarSystem.new(3)
	structure_generator = StructureGenerator.new()
	
	# Generate random structures after grid setup
	generate_random_structures()
	
	# Spawn enemies first, then NPCs
	spawn_enemies()
	spawn_npcs()

# Enemy system functions - spawn in structures only
func spawn_enemies():
	var enemy_count = randi_range(3, 5)
	var structure_tiles = get_structure_digged_tiles()
	
	for i in enemy_count:
		if structure_tiles.size() > 0:
			var tile = structure_tiles[randi() % structure_tiles.size()]
			if tile.x == WIDTH/2 and tile.y == 0:
				continue
			spawn_enemy(tile.x, tile.y)
			structure_tiles.erase(tile)

func get_structure_digged_tiles() -> Array:
	var structure_digged = []
	for x in range(WIDTH):
		for y in range(HEIGHT):
			# Skip starting position (0,0) and only include digged tiles that are part of structures
			if grid_data[y][x] == TileType.DIGGED and not (x == 0 and y == 0):
				structure_digged.append(Vector2i(x, y))
	return structure_digged

func spawn_enemy(x: int, y: int):
	var enemy = WorldEnemy.new(self)
	enemy.position = Vector2(x * SIZE, y * SIZE)
	enemies.append(enemy)
	add_child(enemy)

func spawn_npcs():
	var npc_count = randi_range(2, 4)  # Spawn 2-4 NPCs
	var structure_tiles = get_structure_digged_tiles()
	
	# Remove tiles that already have enemies
	var available_tiles = []
	for tile in structure_tiles:
		var has_enemy = false
		for enemy in enemies:
			if enemy.get_grid_position() == tile:
				has_enemy = true
				break
		
		if not has_enemy:
			available_tiles.append(tile)
	
	# Spawn NPCs with different types
	var npc_types = [WorldNPC.NPCType.TRADER, WorldNPC.NPCType.GUIDE, WorldNPC.NPCType.SCHOLAR, WorldNPC.NPCType.HERMIT]
	
	for i in min(npc_count, available_tiles.size()):
		if available_tiles.size() > 0:
			var tile = available_tiles[randi() % available_tiles.size()]
			var npc_type = npc_types[i % npc_types.size()]  # Cycle through types
			spawn_npc(tile.x, tile.y, npc_type)
			available_tiles.erase(tile)

func spawn_npc(x: int, y: int, npc_type: WorldNPC.NPCType = WorldNPC.NPCType.TRADER):
	var npc = WorldNPC.new(self, npc_type)
	npc.position = Vector2(x * SIZE, y * SIZE)
	npcs.append(npc)
	add_child(npc)

# Add NPC interaction checking to your _process function:
func _process(delta):
	check_enemy_encounters()
	check_npc_interactions()  # Add this line

# Add this new function for NPC interactions:
func check_npc_interactions():
	var player_grid = Vector2i(int(player_position.x / SIZE), int(player_position.y / SIZE))
	
	for npc in npcs:
		if npc.is_adjacent_to_player():
			# You can add visual indicators here, like showing interaction prompts
			# The actual interaction will be handled by your input system
			pass

# Add utility functions for NPC management:
func get_npc_at_position(grid_x: int, grid_y: int) -> WorldNPC:
	"""Get NPC at specific grid position, returns null if none"""
	for npc in npcs:
		var npc_grid = npc.get_grid_position()
		if npc_grid.x == grid_x and npc_grid.y == grid_y:
			return npc
	return null

func get_adjacent_npc() -> WorldNPC:
	"""Get NPC adjacent to player, returns null if none"""
	for npc in npcs:
		if npc.is_adjacent_to_player():
			return npc
	return null

func remove_npc(npc: WorldNPC):
	"""Remove an NPC from the world"""
	var index = npcs.find(npc)
	if index != -1:
		npcs.remove_at(index)
		npc.queue_free()

func check_enemy_encounters():
	var player_grid = Vector2i(int(player_position.x / SIZE), int(player_position.y / SIZE))
	
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		var enemy_grid = enemy.get_grid_position()
		
		if enemy_grid == player_grid:
			trigger_enemy_encounter(enemy, i)

func trigger_enemy_encounter(enemy: WorldEnemy, index: int):
	
	# Remove enemy from world
	enemies.remove_at(index)
	enemy.queue_free()
	
	# Trigger battle based on current tile type
	var tile_type = get_tile_at(enemy.get_grid_position().x, enemy.get_grid_position().y)
	# Convert to EncounterManager tile type (DRY or ROCKY)
	var encounter_tile_type = GameEnviroment.TileType.DRY if tile_type == TileType.DRY else GameEnviroment.TileType.ROCKY
	EncounterManager.trigger_encounter(encounter_tile_type)

func update_player_position_with_enemies(new_position: Vector2):
	player_position = new_position
	var grid_x = int(new_position.x / SIZE)
	var grid_y = int(new_position.y / SIZE)
	update_player_position(grid_x, grid_y)

# Rest of original functions
func load_textures():
	tile_textures[TileType.DRY] = load("res://Tiles/DRY.png")
	tile_textures[TileType.ROCKY] = load("res://Tiles/ROCKY.png")
	tile_textures[TileType.DIGGED] = load("res://Tiles/DIGGED.png")
	
func setup_noise():
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = noise_seed if noise_seed != 0 else randi()
	noise.frequency = cluster_size

func setup_grid_with_noise():
	grid_data = []
	var spawn_x = WIDTH / 2  # Player spawn X
	var spawn_y = 0          # Player spawn Y
	
	for y in range(HEIGHT):
		var row: Array[TileType] = []
		for x in range(WIDTH):
			if x == WIDTH/2 and y == 0:
				# Player starting position
				row.append(TileType.DIGGED)
			else:
				# Calculate distance from spawn
				var distance = sqrt(pow(x - spawn_x, 2) + pow(y - spawn_y, 2))
				
				var noise_value = noise.get_noise_2d(x, y) + dry_amount
				var should_be_rocky = noise_value >= 0
				
				# Force dry tiles if within 5 tiles of spawn, even if noise says rocky
				if should_be_rocky and distance < 5.0:
					row.append(TileType.DRY)  # Override rocky with dry near spawn
				else:
					var tile_type = TileType.DRY if noise_value < 0 else TileType.ROCKY
					row.append(tile_type)
		grid_data.append(row)

# Random structure generation functions
func generate_random_structures():
	var attempts = 0
	var max_attempts = 50  # Prevent infinite loops
	
	while current_structure_count < max_structures and attempts < max_attempts:
		attempts += 1
		
		if rng.randf() < structure_spawn_chance:
			var structure_type = rng.randi_range(0, 3)  # 0-3 for different structure types
			var success = false
			
			match structure_type:
				0:
					success = try_place_random_room()
				1:
					success = try_place_random_tunnel()
				2:
					success = try_place_random_chamber()
				3:
					success = try_place_random_corridor()
			
			if success:
				current_structure_count += 1

func try_place_random_room() -> bool:
	var room_width = rng.randi_range(3, 6)
	var room_height = rng.randi_range(3, 6)
	
	# Try to find a valid position
	for attempt in range(20):
		var start_x = rng.randi_range(2, WIDTH - room_width - 2)
		var start_y = rng.randi_range(2, HEIGHT - room_height - 2)
		
		if is_area_clear_for_structure(start_x, start_y, room_width, room_height):
			create_room(start_x, start_y, room_width, room_height)
			return true
	
	return false

func try_place_random_tunnel() -> bool:
	var is_horizontal = rng.randf() > 0.5
	var length = rng.randi_range(4, 8)
	
	for attempt in range(20):
		var start_x: int
		var start_y: int
		var width: int
		var height: int
		
		if is_horizontal:
			start_x = rng.randi_range(1, WIDTH - length - 1)
			start_y = rng.randi_range(1, HEIGHT - 2)
			width = length
			height = 1
		else:
			start_x = rng.randi_range(1, WIDTH - 2)
			start_y = rng.randi_range(1, HEIGHT - length - 1)
			width = 1
			height = length
		
		if is_area_clear_for_structure(start_x, start_y, width, height):
			create_tunnel(start_x, start_y, width, height)
			
			return true
	
	return false

func try_place_random_chamber() -> bool:
	var chamber_size = rng.randi_range(4, 7)
	
	for attempt in range(20):
		var start_x = rng.randi_range(1, WIDTH - chamber_size - 1)
		var start_y = rng.randi_range(1, HEIGHT - chamber_size - 1)
		
		if is_area_clear_for_structure(start_x, start_y, chamber_size, chamber_size):
			create_chamber(start_x, start_y, chamber_size)
			
			return true
	
	return false

func try_place_random_corridor() -> bool:
	# L-shaped corridor
	var arm1_length = rng.randi_range(3, 6)
	var arm2_length = rng.randi_range(3, 6)
	
	for attempt in range(20):
		var start_x = rng.randi_range(1, WIDTH - arm1_length - 1)
		var start_y = rng.randi_range(1, HEIGHT - arm2_length - 1)
		
		# Check if both arms fit and area is clear
		var fits = start_x + arm1_length < WIDTH and start_y + arm2_length < HEIGHT
		if fits and is_area_clear_for_structure(start_x, start_y, arm1_length + 1, arm2_length + 1):
			create_l_corridor(start_x, start_y, arm1_length, arm2_length)
			
			return true
	
	return false

func is_area_clear_for_structure(start_x: int, start_y: int, width: int, height: int) -> bool:
	# Check if area doesn't conflict with existing structures and has minimum distance
	var buffer = min_distance_between_structures
	
	for y in range(max(0, start_y - buffer), min(HEIGHT, start_y + height + buffer)):
		for x in range(max(0, start_x - buffer), min(WIDTH, start_x + width + buffer)):
			if grid_data[y][x] == TileType.DIGGED:
				# Skip the starting position (0,0) as it's always dug
				if x == 0 and y == 0:
					continue
				return false
	
	return true

func create_room(start_x: int, start_y: int, width: int, height: int):
	# Create walls (dig perimeter)
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			if x == start_x or x == start_x + width - 1 or y == start_y or y == start_y + height - 1:
				dig_tile(x, y)
	
	# Add random entrance
	var entrance_side = rng.randi_range(0, 3)
	match entrance_side:
		0:  # Top
			var x = rng.randi_range(start_x + 1, start_x + width - 2)
			grid_data[start_y][x] = TileType.DIGGED
		1:  # Right
			var y = rng.randi_range(start_y + 1, start_y + height - 2)
			grid_data[y][start_x + width - 1] = TileType.DIGGED
		2:  # Bottom
			var x = rng.randi_range(start_x + 1, start_x + width - 2)
			grid_data[start_y + height - 1][x] = TileType.DIGGED
		3:  # Left
			var y = rng.randi_range(start_y + 1, start_y + height - 2)
			grid_data[y][start_x] = TileType.DIGGED

func create_tunnel(start_x: int, start_y: int, width: int, height: int):
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			dig_tile(x, y)

func create_chamber(start_x: int, start_y: int, size: int):
	# Dig out entire chamber area
	for y in range(start_y, start_y + size):
		for x in range(start_x, start_x + size):
			dig_tile(x, y)

func create_l_corridor(start_x: int, start_y: int, arm1_length: int, arm2_length: int):
	# Horizontal arm
	for x in range(start_x, start_x + arm1_length):
		dig_tile(x, start_y)
	
	# Vertical arm
	for y in range(start_y, start_y + arm2_length):
		dig_tile(start_x, y)

# Structure-related functions (keep existing ones)
func get_structure_names() -> Array:
	return structure_generator.get_structure_names()

func place_structure(structure_name: String, start_x: int, start_y: int) -> bool:
	var pattern = structure_generator.get_structure(structure_name)
	if pattern.is_empty():
		return false
	
	# Check if structure fits in bounds
	var pattern_height = pattern.size()
	var pattern_width = pattern[0].size()
	
	if start_x + pattern_width > WIDTH or start_y + pattern_height > HEIGHT:
		return false
	
	# Apply the structure pattern
	for y in range(pattern_height):
		for x in range(pattern_width):
			if pattern[y][x] == 1:  # Should dig this tile
				var world_x = start_x + x
				var world_y = start_y + y
				dig_tile(world_x, world_y)
	
	return true

func dig_tile(x: int, y: int) -> TileType:
	if grid_data[y][x] != TileType.DIGGED:
		grid_data[y][x] = TileType.DIGGED
		queue_redraw()
		
		return grid_data[y][x]
	return grid_data[y][x]

func is_tile_digged(x: int, y: int) -> bool:
	if is_valid_position(x, y):
		return grid_data[y][x] == TileType.DIGGED
	return false

func _draw() -> void:
	# Draw regular tiles first
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var tile_type = grid_data[y][x]
			var current_pos = Vector2i(x, y)
			
			# Check if this position is part of a structure with background
			if not is_position_in_structure_with_background(current_pos) or tile_type != TileType.DIGGED:
				# Draw regular tile texture (not part of structure background or not digged)
				var texture = tile_textures[tile_type]
				if texture:
					var rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
					draw_texture_rect(texture, rect, false)
				else:
					print("WARNING: No texture found for tile type ", tile_type, " at ", x, ", ", y)
	
	# Draw structure backgrounds as single images spanning the entire structure
	draw_structure_backgrounds()
	
	# Draw player position
	var rect = Rect2((WIDTH/2) * SIZE, 0 * SIZE, SIZE, SIZE)
	draw_rect(rect, Color.BLUE, true)
	
	# Draw grid lines
	var color = Color(0.1, 0.1, 0.1, 0.5)
	
	for i in range(WIDTH + 1):
		draw_line(
			Vector2(i * SIZE, 0),
			Vector2(i * SIZE, HEIGHT * SIZE),
			color
		)
	
	for i in range(HEIGHT + 1):
		draw_line(
			Vector2(0, i * SIZE),
			Vector2(SIZE * WIDTH, i * SIZE),
			color
		)
	
	draw_fog_of_war()
	
func draw_fog_of_war():
	var fog_tiles = fog_of_war.get_fog_tiles()
	var fog_color = fog_of_war.get_fog_color()
	
	for tile_pos in fog_tiles:
		var rect = Rect2(tile_pos.x * SIZE, tile_pos.y * SIZE, SIZE, SIZE)
		draw_rect(rect, fog_color)

func update_player_position(grid_x: int, grid_y: int):
	fog_of_war.update_player_position(grid_x, grid_y)
	queue_redraw()

func get_tile_at(x: int, y: int) -> TileType:
	if is_valid_position(x, y):
		return grid_data[y][x]
	return TileType.DRY

func is_valid_position(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT

func get_dig_speed_for_tile(tile_type: TileType) -> float:
	return tile_dig_speeds.get(tile_type, 0.1)

# Additional utility functions for structure generation
func regenerate_structures():
	"""Call this if you want to generate new random structures"""
	current_structure_count = 0
	generate_random_structures()
	queue_redraw()

func set_structure_generation_params(spawn_chance: float, max_count: int, min_distance: int):
	"""Adjust structure generation parameters"""
	structure_spawn_chance = spawn_chance
	max_structures = max_count
	min_distance_between_structures = min_distance

func get_player_position() -> Vector2:
	if player_reference:
		return player_reference.position
	else:
		return player_position

func get_player_grid_position() -> Vector2i:
	if player_reference:
		return Vector2i(int(player_reference.position.x / SIZE), int(player_reference.position.y / SIZE))
	else:
		return Vector2i(int(player_position.x / SIZE), int(player_position.y / SIZE))

# Add this function to test the background feature
func place_test_structure_with_background(start_x: int, start_y: int) -> bool:
	var structure_data = structure_generator.get_structure("test_structure")
	var pattern = structure_data["pattern"]
	var background_path = structure_data["background"]
	
	if pattern.is_empty():
		return false
	
	var pattern_height = pattern.size()
	var pattern_width = pattern[0].size()
	
	# Check bounds
	if start_x + pattern_width > WIDTH or start_y + pattern_height > HEIGHT:
		return false
	
	# Dig the tiles according to pattern
	var dug_tiles = []
	for y in range(pattern_height):
		for x in range(pattern_width):
			if pattern[y][x] == 1:
				var world_x = start_x + x
				var world_y = start_y + y
				dig_tile(world_x, world_y)
				dug_tiles.append(Vector2i(world_x, world_y))
	
	# Store structure data with background if it exists
	if background_path:
		# Load the background texture if not already loaded
		if not structure_background_textures.has(background_path):
			structure_background_textures[background_path] = load(background_path)
		
		var structure_info = {
			"bounds": Rect2i(start_x, start_y, pattern_width, pattern_height),
			"background_path": background_path,
			"tiles": dug_tiles
		}
		structure_areas.append(structure_info)
	
	queue_redraw()
	return true

func spawn_test_structure_near_player():
	var player_grid = get_player_grid_position()
	
	# Try different offsets around the player
	var offsets = [
		Vector2i(3, 0),   # 3 tiles to the right
		Vector2i(-3, 0),  # 3 tiles to the left
		Vector2i(0, 3),   # 3 tiles down
		Vector2i(0, -3),  # 3 tiles up
		Vector2i(3, 3),   # 3 tiles diagonal
		Vector2i(-3, -3), # 3 tiles diagonal opposite
	]
	
	# Try each offset until we find a valid position
	for offset in offsets:
		var spawn_x = player_grid.x + offset.x
		var spawn_y = player_grid.y + offset.y
		
		# Check if the structure would fit in bounds
		if spawn_x >= 0 and spawn_y >= 0 and spawn_x + 3 <= WIDTH and spawn_y + 3 <= HEIGHT:
			if is_area_suitable_for_test_structure(spawn_x, spawn_y):
				place_test_structure_with_background(spawn_x, spawn_y)
				print("Test structure with background spawned at: ", spawn_x, ", ", spawn_y)
				return true
	
	print("Could not find suitable location for test structure near player")
	return false

func draw_structure_backgrounds():
	for structure in structure_areas:
		var background_path = structure["background_path"]
		var bounds = structure["bounds"]
		
		if structure_background_textures.has(background_path):
			var background_texture = structure_background_textures[background_path]
			if background_texture:
				# Draw background texture covering the structure area
				var bg_rect = Rect2(
					bounds.position.x * SIZE,
					bounds.position.y * SIZE,
					bounds.size.x * SIZE,
					bounds.size.y * SIZE
				)
				# Make the background slightly transparent so tiles show through
				var modulate_color = Color(1.0, 1.0, 1.0, 0.3)  # 30% opacity
				draw_texture_rect(background_texture, bg_rect, false, modulate_color)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:  # Press T to place test structure with background
			spawn_test_structure_near_player()

func is_area_suitable_for_test_structure(start_x: int, start_y: int) -> bool:
	var player_grid = get_player_grid_position()
	var structure_rect = Rect2i(start_x, start_y, 3, 3)
	
	if structure_rect.has_point(player_grid):
		return false
	
	var undigged_count = 0
	for y in range(start_y, start_y + 3):
		for x in range(start_x, start_x + 3):
			if grid_data[y][x] != TileType.DIGGED:
				undigged_count += 1
	
	return undigged_count >= 5

func get_structure_background_at_position(pos: Vector2i) -> Texture2D:
	for structure in structure_areas:
		var tiles = structure["tiles"]
		if pos in tiles:
			var background_path = structure["background_path"]
			if structure_background_textures.has(background_path):
				return structure_background_textures[background_path]
	return null

func is_position_in_structure_with_background(pos: Vector2i) -> bool:
	for structure in structure_areas:
		var tiles = structure["tiles"]
		var background_path = structure["background_path"]
		if pos in tiles and background_path:
			return true
	return false

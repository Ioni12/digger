extends RefCounted
class_name StructureSystem

# Structure generation parameters
var structure_spawn_chance: float = 0.15
var max_structures: int = 8
var current_structure_count: int = 0
var min_distance_between_structures: int = 5
var structure_areas: Array[Dictionary] = []
var structure_background_textures: Dictionary = {}
var placed_positions: Array[Vector2i] = []

# DEBUG: Track all created structures
var debug_structures: Array[Dictionary] = []

var rng: RandomNumberGenerator
var structure_generator: StructureGenerator

# Reference to the game environment for grid operations
var game_env: GameEnviroment

func _init(env: GameEnviroment):
	game_env = env
	rng = RandomNumberGenerator.new()
	rng.randomize()
	structure_generator = StructureGenerator.new()

func generate_random_structures():
	var attempts = 0
	var max_attempts = 50
	
	while current_structure_count < max_structures and attempts < max_attempts:
		attempts += 1
		
		if rng.randf() < structure_spawn_chance:
			var structure_type = rng.randi_range(0, 3)
			var success = false
			
			match structure_type:
				0: success = try_place_random_room()
				1: success = try_place_random_tunnel()
				2: success = try_place_random_chamber()
				3: success = try_place_random_corridor()
			
			if success:
				current_structure_count += 1

func try_place_random_room() -> bool:
	var room_width = rng.randi_range(3, 6)
	var room_height = rng.randi_range(3, 6)
	
	for attempt in range(20):
		var start_x = rng.randi_range(2, game_env.WIDTH - room_width - 2)
		var start_y = rng.randi_range(2, game_env.HEIGHT - room_height - 2)
		
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
			start_x = rng.randi_range(1, game_env.WIDTH - length - 1)
			start_y = rng.randi_range(1, game_env.HEIGHT - 2)
			width = length
			height = 1
		else:
			start_x = rng.randi_range(1, game_env.WIDTH - 2)
			start_y = rng.randi_range(1, game_env.HEIGHT - length - 1)
			width = 1
			height = length
		
		if is_area_clear_for_structure(start_x, start_y, width, height):
			create_tunnel(start_x, start_y, width, height)
			return true
	return false

func try_place_random_chamber() -> bool:
	var chamber_size = rng.randi_range(4, 7)
	
	for attempt in range(20):
		var start_x = rng.randi_range(1, game_env.WIDTH - chamber_size - 1)
		var start_y = rng.randi_range(1, game_env.HEIGHT - chamber_size - 1)
		
		if is_area_clear_for_structure(start_x, start_y, chamber_size, chamber_size):
			create_chamber(start_x, start_y, chamber_size)
			return true
	return false

func try_place_random_corridor() -> bool:
	var arm1_length = rng.randi_range(3, 6)
	var arm2_length = rng.randi_range(3, 6)
	
	for attempt in range(20):
		var start_x = rng.randi_range(1, game_env.WIDTH - arm1_length - 1)
		var start_y = rng.randi_range(1, game_env.HEIGHT - arm2_length - 1)
		
		var fits = start_x + arm1_length < game_env.WIDTH and start_y + arm2_length < game_env.HEIGHT
		if fits and is_area_clear_for_structure(start_x, start_y, arm1_length + 1, arm2_length + 1):
			create_l_corridor(start_x, start_y, arm1_length, arm2_length)
			return true
	return false

func is_area_clear_for_structure(start_x: int, start_y: int, width: int, height: int) -> bool:
	var buffer = min_distance_between_structures
	
	for y in range(max(0, start_y - buffer), min(game_env.HEIGHT, start_y + height + buffer)):
		for x in range(max(0, start_x - buffer), min(game_env.WIDTH, start_x + width + buffer)):
			if game_env.grid_data[y][x] == game_env.TileType.DIGGED:
				if x == 0 and y == 0:
					continue
				return false
	return true

func create_room(start_x: int, start_y: int, width: int, height: int):
	# DEBUG: Track structure
	debug_structures.append({
		"type": "ROOM",
		"pos": Vector2i(start_x, start_y),
		"size": Vector2i(width, height),
		"color": Color.GREEN
	})
	
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			if x == start_x or x == start_x + width - 1 or y == start_y or y == start_y + height - 1:
				game_env.dig_tile(x, y)
	
	var entrance_side = rng.randi_range(0, 3)
	match entrance_side:
		0: # Top
			var x = rng.randi_range(start_x + 1, start_x + width - 2)
			game_env.grid_data[start_y][x] = game_env.TileType.DIGGED
		1: # Right
			var y = rng.randi_range(start_y + 1, start_y + height - 2)
			game_env.grid_data[y][start_x + width - 1] = game_env.TileType.DIGGED
		2: # Bottom
			var x = rng.randi_range(start_x + 1, start_x + width - 2)
			game_env.grid_data[start_y + height - 1][x] = game_env.TileType.DIGGED
		3: # Left
			var y = rng.randi_range(start_y + 1, start_y + height - 2)
			game_env.grid_data[y][start_x] = game_env.TileType.DIGGED

func create_tunnel(start_x: int, start_y: int, width: int, height: int):
	# DEBUG: Track structure
	debug_structures.append({
		"type": "TUNNEL",
		"pos": Vector2i(start_x, start_y),
		"size": Vector2i(width, height),
		"color": Color.CYAN
	})
	
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			game_env.dig_tile(x, y)

func create_chamber(start_x: int, start_y: int, size: int):
	# DEBUG: Track structure
	debug_structures.append({
		"type": "CHAMBER",
		"pos": Vector2i(start_x, start_y),
		"size": Vector2i(size, size),
		"color": Color.YELLOW
	})
	
	for y in range(start_y, start_y + size):
		for x in range(start_x, start_x + size):
			game_env.dig_tile(x, y)

func create_l_corridor(start_x: int, start_y: int, arm1_length: int, arm2_length: int):
	# DEBUG: Track structure
	debug_structures.append({
		"type": "L-CORRIDOR",
		"pos": Vector2i(start_x, start_y),
		"size": Vector2i(arm1_length, arm2_length),
		"color": Color.MAGENTA
	})
	
	for x in range(start_x, start_x + arm1_length):
		game_env.dig_tile(x, start_y)
	for y in range(start_y, start_y + arm2_length):
		game_env.dig_tile(start_x, y)

func place_structure(structure_name: String, start_x: int, start_y: int) -> bool:
	var pattern = structure_generator.get_structure(structure_name)
	if pattern.is_empty():
		return false
	
	var pattern_height = pattern.size()
	var pattern_width = pattern[0].size()
	
	if start_x + pattern_width > game_env.WIDTH or start_y + pattern_height > game_env.HEIGHT:
		return false
	
	for y in range(pattern_height):
		for x in range(pattern_width):
			if pattern[y][x] == 1:
				var world_x = start_x + x
				var world_y = start_y + y
				game_env.dig_tile(world_x, world_y)
	return true

func place_test_structure_with_background(start_x: int, start_y: int) -> bool:
	var structure_data = structure_generator.get_structure("test_structure")
	var pattern = structure_data["pattern"]
	var background_path = structure_data["background"]
	
	if pattern.is_empty():
		return false
	
	var pattern_height = pattern.size()
	var pattern_width = pattern[0].size()
	
	if start_x + pattern_width > game_env.WIDTH or start_y + pattern_height > game_env.HEIGHT:
		return false
	
	var dug_tiles = []
	for y in range(pattern_height):
		for x in range(pattern_width):
			if pattern[y][x] == 1:
				var world_x = start_x + x
				var world_y = start_y + y
				game_env.dig_tile(world_x, world_y)
				dug_tiles.append(Vector2i(world_x, world_y))
	
	if background_path:
		if not structure_background_textures.has(background_path):
			structure_background_textures[background_path] = load(background_path)
		
		var structure_info = {
			"bounds": Rect2i(start_x, start_y, pattern_width, pattern_height),
			"background_path": background_path,
			"tiles": dug_tiles
		}
		structure_areas.append(structure_info)
	
	return true

func regenerate_structures():
	current_structure_count = 0
	structure_areas.clear()
	debug_structures.clear()  # Clear debug data too
	generate_random_structures()

func set_structure_generation_params(spawn_chance: float, max_count: int, min_distance: int):
	structure_spawn_chance = spawn_chance
	max_structures = max_count
	min_distance_between_structures = min_distance

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

func spawn_test_structure_near_player():
	var player_grid = game_env.get_player_grid_position()
	
	var offsets = [
		Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), 
		Vector2i(0, -3), Vector2i(3, 3), Vector2i(-3, -3)
	]
	
	for offset in offsets:
		var spawn_x = player_grid.x + offset.x
		var spawn_y = player_grid.y + offset.y
		
		if spawn_x >= 0 and spawn_y >= 0 and spawn_x + 3 <= game_env.WIDTH and spawn_y + 3 <= game_env.HEIGHT:
			if is_area_suitable_for_test_structure(spawn_x, spawn_y):
				place_test_structure_with_background(spawn_x, spawn_y)
				print("Test structure with background spawned at: ", spawn_x, ", ", spawn_y)
				return true
	
	print("Could not find suitable location for test structure near player")
	return false

func is_area_suitable_for_test_structure(start_x: int, start_y: int) -> bool:
	var player_grid = game_env.get_player_grid_position()
	var structure_rect = Rect2i(start_x, start_y, 3, 3)
	
	if structure_rect.has_point(player_grid):
		return false
	
	var undigged_count = 0
	for y in range(start_y, start_y + 3):
		for x in range(start_x, start_x + 3):
			if game_env.grid_data[y][x] != game_env.TileType.DIGGED:
				undigged_count += 1
	
	return undigged_count >= 5

func draw_structure_backgrounds():
	for structure in structure_areas:
		var background_path = structure["background_path"]
		var bounds = structure["bounds"]
		
		if structure_background_textures.has(background_path):
			var background_texture = structure_background_textures[background_path]
			if background_texture:
				# Draw background texture covering the structure area
				var bg_rect = Rect2(
					bounds.position.x * game_env.SIZE,
					bounds.position.y * game_env.SIZE,
					bounds.size.x * game_env.SIZE,
					bounds.size.y * game_env.SIZE
				)
				# Make the background slightly transparent so tiles show through
				var modulate_color = Color(1.0, 1.0, 1.0, 0.3)  # 30% opacity
				game_env.draw_texture_rect(background_texture, bg_rect, false, modulate_color)

func place_at_distance(from_pos: Vector2i, min_dist: int, max_dist: int, size: Vector2i) -> Vector2i:
	for attempt in range(100):
		# Random angle and distance
		var angle = rng.randf() * TAU
		var distance = rng.randf_range(min_dist, max_dist)
		
		# Calculate position
		var x = from_pos.x + int(cos(angle) * distance)
		var y = from_pos.y + int(sin(angle) * distance)
		var pos = Vector2i(x, y)
		
		# Check if valid
		if is_valid_placement(pos, size):
			placed_positions.append(pos)
			return pos
	
	return Vector2i(-1, -1)

func is_valid_placement(pos: Vector2i, size: Vector2i) -> bool:
	# Check bounds
	if pos.x < 0 or pos.y < 0:
		return false
	if pos.x + size.x >= game_env.WIDTH or pos.y + size.y >= game_env.HEIGHT:
		return false
	
	# Check distance from other structures
	for existing in placed_positions:
		if pos.distance_to(existing) < min_distance_between_structures:
			return false
	
	# Check if area is clear
	return is_area_clear_for_structure(pos.x, pos.y, size.x, size.y)

# Create tunnel near player (replaces your startup tunnel)
func create_tunnel_near_player() -> bool:
	var player_pos = game_env.get_player_grid_position()
	var tunnel_size = Vector2i(6, 1)  # 6 tiles long, 1 wide
	
	# Place tunnel 8-15 tiles from player
	var tunnel_pos = place_at_distance(player_pos, 8, 11, tunnel_size)
	
	if tunnel_pos.x >= 0:
		create_tunnel(tunnel_pos.x, tunnel_pos.y, tunnel_size.x, tunnel_size.y)
		print("Tunnel created at: ", tunnel_pos)
		return true
	
	return false

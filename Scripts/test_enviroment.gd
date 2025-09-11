extends Node2D
class_name GameEnviroment1

const SIZE = 60
const WIDTH = 30
const HEIGHT = 30

enum TileType {
	DRY,
	ROCKY,
	DIGGED
}

var grid_data: Array[Array] = []
var tile_textures: Dictionary = {}
var cluster_size: float = 0.1
var noise_seed: int = 0
var dry_amount: float = -0.08
var noise: FastNoiseLite

func _ready() -> void:
	load_textures()
	setup_noise()
	setup_grid_with_noise()

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
	
	# First create the base terrain with noise
	for y in range(HEIGHT):
		var row: Array[TileType] = []
		for x in range(WIDTH):
			var noise_value = noise.get_noise_2d(x, y) + dry_amount
			var tile_type = TileType.DRY if noise_value < 0 else TileType.ROCKY
			row.append(tile_type)
		grid_data.append(row)
	
	# Then add intentional digged patterns
	create_intentional_settlements()
	
	queue_redraw()

func create_intentional_settlements():
	# Choose which pattern type to use
	var pattern_type = randi() % 3
	
	match pattern_type:
		0: create_settlement_patterns()
		1: create_tunnel_network() 
		2: create_mining_operation()

func create_settlement_patterns():
	# Create a few "settlements" with intentional layouts
	create_central_hub(WIDTH / 2, HEIGHT / 2)  # Main settlement in center
	create_small_settlement(8, 10)   # Small outpost
	create_small_settlement(22, 20)   # Trading area

func create_central_hub(center_x: int, center_y: int):
	# Create main plaza (3x3 central area)
	for x in range(center_x - 1, center_x + 2):
		for y in range(center_y - 1, center_y + 2):
			if is_valid_position(x, y):
				grid_data[y][x] = TileType.DIGGED
	
	# Create 4 "streets" extending from center
	create_straight_tunnel(center_x, center_y - 1, 0, -1, 4)  # North
	create_straight_tunnel(center_x, center_y + 1, 0, 1, 4)   # South
	create_straight_tunnel(center_x - 1, center_y, -1, 0, 4)  # West
	create_straight_tunnel(center_x + 1, center_y, 1, 0, 4)   # East
	
	# Add some "buildings" (small rectangular areas)
	create_rectangular_room(center_x - 5, center_y - 3, 3, 2)
	create_rectangular_room(center_x + 3, center_y - 2, 2, 3)
	create_rectangular_room(center_x - 4, center_y + 2, 2, 2)

func create_tunnel_network():
	var network_points: Array[Vector2i] = [
		Vector2i(10, 10),   # Starting settlement
		Vector2i(20, 15),   # Mining area  
		Vector2i(8, 22),    # Secondary settlement
		Vector2i(22, 8)     # Outpost
	]
	
	# Create settlements at key points
	for point in network_points:
		create_small_settlement(point.x, point.y)
	
	# Connect settlements with winding tunnels
	connect_points_with_tunnel(network_points[0], network_points[1])
	connect_points_with_tunnel(network_points[1], network_points[2])
	connect_points_with_tunnel(network_points[0], network_points[3])
	connect_points_with_tunnel(network_points[2], network_points[3])

func create_mining_operation():
	# Main shaft entrance
	var entrance_x = 3
	var entrance_y = HEIGHT / 2
	
	# Create main vertical shaft
	create_straight_tunnel(entrance_x, entrance_y, 0, 1, 8)
	create_straight_tunnel(entrance_x, entrance_y, 0, -1, 8)
	
	# Create horizontal mining levels every few tiles
	for level in range(3):
		var level_y = entrance_y - 6 + (level * 4)
		create_mining_level(entrance_x + 1, level_y, level)
	
	# Add storage areas
	create_storage_complex(entrance_x + 15, entrance_y - 2)

func create_small_settlement(center_x: int, center_y: int):
	# Create irregular settlement shape
	var rooms = [
		{"pos": Vector2i(0, 0), "size": Vector2i(2, 2)},      # Main room
		{"pos": Vector2i(2, -1), "size": Vector2i(2, 1)},     # Storage
		{"pos": Vector2i(-1, 1), "size": Vector2i(1, 2)},     # Side room
		{"pos": Vector2i(1, 2), "size": Vector2i(1, 1)}       # Small alcove
	]
	
	for room in rooms:
		var room_x = center_x + room.pos.x
		var room_y = center_y + room.pos.y
		create_rectangular_room(room_x, room_y, room.size.x, room.size.y)

func create_mining_level(start_x: int, start_y: int, level: int):
	if not is_valid_position(start_x, start_y):
		return
		
	# Main horizontal tunnel
	create_straight_tunnel(start_x, start_y, 1, 0, 12)
	
	# Branch tunnels for mining
	for i in range(3):
		var branch_x = start_x + 3 + (i * 3)
		var branch_length = 3 + randi() % 3  # Variable length
		var direction = 1 if level % 2 == 0 else -1  # Alternate directions
		
		create_straight_tunnel(branch_x, start_y, 0, direction, branch_length)
		
		# Add small mining chambers at end of some branches
		if randf() < 0.6:
			create_rectangular_room(branch_x - 1, start_y + (direction * branch_length), 3, 2)

func create_storage_complex(center_x: int, center_y: int):
	# Main storage hall
	create_rectangular_room(center_x, center_y, 4, 3)
	
	# Connecting corridors
	create_straight_tunnel(center_x - 1, center_y + 1, -1, 0, 3)
	create_straight_tunnel(center_x + 4, center_y + 1, 1, 0, 3)
	
	# Side storage rooms
	create_rectangular_room(center_x - 4, center_y, 2, 2)
	create_rectangular_room(center_x + 6, center_y, 2, 2)

func connect_points_with_tunnel(from: Vector2i, to: Vector2i):
	var current = from
	var steps = 0
	var max_steps = 100  # Prevent infinite loops
	
	while current != to and steps < max_steps:
		# Add some randomness to make tunnels more organic
		var next_pos = current
		
		# Move towards target with some wandering
		if abs(to.x - current.x) > abs(to.y - current.y):
			# Move horizontally
			next_pos.x += 1 if to.x > current.x else -1
			# Sometimes add vertical drift
			if randf() < 0.3:
				next_pos.y += randi_range(-1, 1)
		else:
			# Move vertically  
			next_pos.y += 1 if to.y > current.y else -1
			# Sometimes add horizontal drift
			if randf() < 0.3:
				next_pos.x += randi_range(-1, 1)
		
		if is_valid_position(next_pos.x, next_pos.y):
			grid_data[next_pos.y][next_pos.x] = TileType.DIGGED
			current = next_pos
		
		steps += 1

func create_straight_tunnel(start_x: int, start_y: int, dir_x: int, dir_y: int, length: int):
	for i in range(length):
		var x = start_x + (dir_x * i)
		var y = start_y + (dir_y * i)
		if is_valid_position(x, y):
			grid_data[y][x] = TileType.DIGGED

func create_rectangular_room(start_x: int, start_y: int, width: int, height: int):
	for x in range(start_x, start_x + width):
		for y in range(start_y, start_y + height):
			if is_valid_position(x, y):
				grid_data[y][x] = TileType.DIGGED

func dig_tile(x: int, y: int) -> TileType:
	if grid_data[y][x] != TileType.DIGGED:
		grid_data[y][x] = TileType.DIGGED
		queue_redraw()
		print("Tile dug at ", x, ", ", y, " - Type now: ", TileType.keys()[grid_data[y][x]])
		return grid_data[y][x]
	return grid_data[y][x]

func is_tile_digged(x: int, y: int) -> bool:
	if is_valid_position(x, y):
		return grid_data[y][x] == TileType.DIGGED
	return false

func _draw() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var tile_type = grid_data[y][x]
			var texture = tile_textures[tile_type]
			
			if texture:
				var rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
				draw_texture_rect(texture, rect, false)
			else:
				print("WARNING: No texture found for tile type ", tile_type, " at ", x, ", ", y)
	
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

func get_tile_at(x: int, y: int) -> TileType:
	if is_valid_position(x, y):
		return grid_data[y][x]
	return TileType.DRY

func is_valid_position(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT

func print_grid():
	print("=== GRID STATE ===")
	for y in range(HEIGHT):
		var row_string = ""
		for x in range(WIDTH):
			match grid_data[y][x]:
				TileType.DRY:
					row_string += "D "
				TileType.ROCKY:
					row_string += "R "
				TileType.DIGGED:
					row_string += "X "
		print("Row ", y, ": ", row_string)
	print("==================")

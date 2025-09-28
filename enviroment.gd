extends Node2D
class_name GameEnviroment

const SIZE = 98
const WIDTH = 30
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
var rng: RandomNumberGenerator

var player_position: Vector2 = Vector2((WIDTH/2) * SIZE, 0 * SIZE)
var player_reference: Player
var entity_manager: EntityManager
var structure_system: StructureSystem

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	load_textures()
	setup_noise()
	setup_grid_with_noise()
	fog_of_war = FogOfWarSystem.new(3)
	entity_manager = EntityManager.new(self)
	structure_system = StructureSystem.new(self)
	
	add_child(entity_manager)
	
	# Generate random structures after grid setup
	structure_system.generate_random_structures()
	
	#spawn_enemies()
	entity_manager.spawn_all_entities()

func _process(delta):
	entity_manager.check_enemy_encounters()
	entity_manager.check_npc_interactions()  # Add this line

func update_player_position_with_enemies(new_position: Vector2):
	player_position = new_position
	var grid_x = int(new_position.x / SIZE)
	var grid_y = int(new_position.y / SIZE)
	update_player_position(grid_x, grid_y)

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
			if not structure_system.is_position_in_structure_with_background(current_pos) or tile_type != TileType.DIGGED:
				# Draw regular tile texture (not part of structure background or not digged)
				var texture = tile_textures[tile_type]
				if texture:
					var rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
					draw_texture_rect(texture, rect, false)
				else:
					print("WARNING: No texture found for tile type ", tile_type, " at ", x, ", ", y)
	
	# Draw structure backgrounds as single images spanning the entire structure
	structure_system.draw_structure_backgrounds()

	
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

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:  # Press T to place test structure with background
			structure_system.spawn_test_structure_near_player()

func get_structure_digged_tiles() -> Array:
	var structure_digged = []
	for x in range(WIDTH):
		for y in range(HEIGHT):
			if grid_data[y][x] == TileType.DIGGED and not (x == WIDTH/2 and y == 0):
				structure_digged.append(Vector2i(x, y))
	return structure_digged

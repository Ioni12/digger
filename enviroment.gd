extends Node2D
class_name GameEnviroment

const SIZE = 98
const WIDTH = 300
const HEIGHT = 300

enum TileType {
	DRY,
	ROCKY,
	DIGGED,
}

var tile_dig_speeds: Dictionary = {
	TileType.DRY: 0,
	TileType.ROCKY: 1.5,
	TileType.DIGGED: 0.0
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

# VIEWPORT CULLING: Cache for visible tile bounds
var visible_tile_bounds: Rect2i = Rect2i()
var last_camera_position: Vector2 = Vector2.ZERO
var camera_moved_threshold: float = SIZE * 0.5  # Recalculate when camera moves half a tile

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
	structure_system.generate_random_structures()
	structure_system.create_tunnel_near_player()
	entity_manager.spawn_all_entities()

func _process(delta):
	entity_manager.check_enemy_encounters()
	entity_manager.check_npc_interactions()
	
	# VIEWPORT CULLING: Only recalculate visible bounds when camera moves significantly
	var camera = get_viewport().get_camera_2d()
	if camera:
		var camera_pos = camera.global_position
		if last_camera_position.distance_to(camera_pos) > camera_moved_threshold:
			update_visible_bounds(camera)
			last_camera_position = camera_pos
			queue_redraw()

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
	var spawn_x = WIDTH / 2
	var spawn_y = 0
	
	for y in range(HEIGHT):
		var row: Array[TileType] = []
		for x in range(WIDTH):
			if x == WIDTH/2 and y == 0:
				row.append(TileType.DIGGED)
			else:
				var distance = sqrt(pow(x - spawn_x, 2) + pow(y - spawn_y, 2))
				var noise_value = noise.get_noise_2d(x, y) + dry_amount
				var should_be_rocky = noise_value >= 0
				
				if should_be_rocky and distance < 5.0:
					row.append(TileType.DRY)
				else:
					var tile_type = TileType.DRY if noise_value < 0 else TileType.ROCKY
					row.append(tile_type)
		grid_data.append(row)
		
	

# VIEWPORT CULLING: Calculate which tiles are visible
func update_visible_bounds(camera: Camera2D):
	if not camera:
		# Fallback: render everything
		visible_tile_bounds = Rect2i(0, 0, WIDTH, HEIGHT)
		return
	
	# Get viewport size
	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom
	
	# Calculate world space rect that's visible
	var camera_pos = camera.global_position
	var half_viewport = viewport_size / (2.0 * zoom)
	
	var world_rect = Rect2(
		camera_pos - half_viewport,
		viewport_size / zoom
	)
	
	# Convert to tile coordinates with 1 tile padding (for smooth scrolling)
	var min_x = max(0, int(world_rect.position.x / SIZE) - 1)
	var min_y = max(0, int(world_rect.position.y / SIZE) - 1)
	var max_x = min(WIDTH, int((world_rect.position.x + world_rect.size.x) / SIZE) + 2)
	var max_y = min(HEIGHT, int((world_rect.position.y + world_rect.size.y) / SIZE) + 2)
	
	visible_tile_bounds = Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)

func dig_tile(x: int, y: int) -> TileType:
	if grid_data[y][x] != TileType.DIGGED:
		grid_data[y][x] = TileType.DIGGED
		
		# Tell map to update
		if has_node("/root/Map"):  # Adjust path as needed
			get_node("/root/Map").mark_map_dirty()
		
		queue_redraw()
		return grid_data[y][x]
	return grid_data[y][x]

func is_tile_digged(x: int, y: int) -> bool:
	if is_valid_position(x, y):
		return grid_data[y][x] == TileType.DIGGED
	return false

func _draw() -> void:
	# Ensure we have valid bounds
	if visible_tile_bounds.size.x == 0 or visible_tile_bounds.size.y == 0:
		var camera = get_viewport().get_camera_2d()
		update_visible_bounds(camera)
	
	# VIEWPORT CULLING: Only draw visible tiles
	var start_x = visible_tile_bounds.position.x
	var start_y = visible_tile_bounds.position.y
	var end_x = min(WIDTH, start_x + visible_tile_bounds.size.x)
	var end_y = min(HEIGHT, start_y + visible_tile_bounds.size.y)
	
	# Draw regular tiles (only visible ones)
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var tile_type = grid_data[y][x]
			var current_pos = Vector2i(x, y)
			
			if not structure_system.is_position_in_structure_with_background(current_pos) or tile_type != TileType.DIGGED:
				var texture = tile_textures[tile_type]
				if texture:
					var rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
					draw_texture_rect(texture, rect, false)
	
	structure_system.draw_structure_backgrounds()
	
	# Draw player position
	var rect = Rect2((WIDTH/2) * SIZE, 0 * SIZE, SIZE, SIZE)
	draw_rect(rect, Color.BLUE, true)
	
	# VIEWPORT CULLING: Only draw visible grid lines
	draw_grid_lines_culled(start_x, start_y, end_x, end_y)
	
	# VIEWPORT CULLING: Fog of war with culling
	draw_fog_of_war_culled(start_x, start_y, end_x, end_y)

# VIEWPORT CULLING: Only draw grid lines in visible area
func draw_grid_lines_culled(start_x: int, start_y: int, end_x: int, end_y: int):
	var color = Color(0.1, 0.1, 0.1, 0.5)
	
	# Vertical lines
	for i in range(start_x, end_x + 1):
		draw_line(
			Vector2(i * SIZE, start_y * SIZE),
			Vector2(i * SIZE, end_y * SIZE),
			color
		)
	
	# Horizontal lines
	for i in range(start_y, end_y + 1):
		draw_line(
			Vector2(start_x * SIZE, i * SIZE),
			Vector2(end_x * SIZE, i * SIZE),
			color
		)

# VIEWPORT CULLING: Optimized fog rendering with culling
func draw_fog_of_war_culled(start_x: int, start_y: int, end_x: int, end_y: int):
	var fog_color = fog_of_war.get_fog_color()
	var visible_bounds = fog_of_war.get_visible_bounds()
	
	# Intersect fog bounds with viewport bounds
	var fog_start_x = max(start_x, 0)
	var fog_start_y = max(start_y, 0)
	var fog_end_x = min(end_x, WIDTH)
	var fog_end_y = min(end_y, HEIGHT)
	
	# Draw large fog rectangles (only in visible viewport)
	
	# Top fog
	if visible_bounds.position.y > fog_start_y:
		var rect = Rect2(
			fog_start_x * SIZE, 
			fog_start_y * SIZE, 
			(fog_end_x - fog_start_x) * SIZE, 
			(min(visible_bounds.position.y, fog_end_y) - fog_start_y) * SIZE
		)
		if rect.size.x > 0 and rect.size.y > 0:
			draw_rect(rect, fog_color, true)
	
	# Bottom fog
	var fog_bottom_start = visible_bounds.position.y + visible_bounds.size.y
	if fog_bottom_start < fog_end_y:
		var rect = Rect2(
			fog_start_x * SIZE, 
			max(fog_bottom_start, fog_start_y) * SIZE,
			(fog_end_x - fog_start_x) * SIZE,
			(fog_end_y - max(fog_bottom_start, fog_start_y)) * SIZE
		)
		if rect.size.x > 0 and rect.size.y > 0:
			draw_rect(rect, fog_color, true)
	
	# Left fog (in middle section, only visible part)
	var middle_start_y = max(visible_bounds.position.y, fog_start_y)
	var middle_end_y = min(visible_bounds.position.y + visible_bounds.size.y, fog_end_y)
	
	if visible_bounds.position.x > fog_start_x and middle_start_y < middle_end_y:
		var rect = Rect2(
			fog_start_x * SIZE,
			middle_start_y * SIZE,
			(min(visible_bounds.position.x, fog_end_x) - fog_start_x) * SIZE,
			(middle_end_y - middle_start_y) * SIZE
		)
		if rect.size.x > 0 and rect.size.y > 0:
			draw_rect(rect, fog_color, true)
	
	# Right fog (in middle section, only visible part)
	var fog_right_start = visible_bounds.position.x + visible_bounds.size.x
	if fog_right_start < fog_end_x and middle_start_y < middle_end_y:
		var rect = Rect2(
			max(fog_right_start, fog_start_x) * SIZE,
			middle_start_y * SIZE,
			(fog_end_x - max(fog_right_start, fog_start_x)) * SIZE,
			(middle_end_y - middle_start_y) * SIZE
		)
		if rect.size.x > 0 and rect.size.y > 0:
			draw_rect(rect, fog_color, true)
	
	# Draw individual fog tiles within visible area (for circular fog pattern)
	var check_start_y = max(visible_bounds.position.y, fog_start_y)
	var check_end_y = min(visible_bounds.position.y + visible_bounds.size.y, fog_end_y)
	var check_start_x = max(visible_bounds.position.x, fog_start_x)
	var check_end_x = min(visible_bounds.position.x + visible_bounds.size.x, fog_end_x)
	
	for y in range(check_start_y, check_end_y):
		for x in range(check_start_x, check_end_x):
			if not fog_of_war.is_tile_visible(x, y):
				var tile_rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
				draw_rect(tile_rect, fog_color, true)

func update_player_position(grid_x: int, grid_y: int):
	var old_pos = fog_of_war.get_player_position()
	fog_of_war.update_player_position(grid_x, grid_y)
	
	if old_pos.x != grid_x or old_pos.y != grid_y:
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
		if event.keycode == KEY_T:
			structure_system.spawn_test_structure_near_player()

func get_structure_digged_tiles() -> Array:
	var structure_digged = []
	for x in range(WIDTH):
		for y in range(HEIGHT):
			if grid_data[y][x] == TileType.DIGGED and not (x == WIDTH/2 and y == 0):
				structure_digged.append(Vector2i(x, y))
	return structure_digged

extends Node2D

# Game Environment Constants and Variables
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

# Player Variables
enum PlayerState {
	IDLE,
	DIGGING,
	MOVING
}

var grid_x: int = 0
var grid_y: int = 0
var start_position: Vector2
var target_position: Vector2
var current_state: PlayerState = PlayerState.IDLE
var is_moving: bool = false
var move_timer: float = 0.0
var move_speed: float = 0.12
var digg_speed: float = 1.0  # Time to dig a tile

var player_sprite: Sprite2D
var normal_color: Color = Color.BLUE
var digging_color: Color = Color.RED

func _ready() -> void:
	add_to_group("environment")
	load_textures()
	setup_noise()
	setup_grid_with_noise()
	setup_player()

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
	
	for y in range(HEIGHT):
		var row: Array[TileType] = []
		for x in range(WIDTH):
			var noise_value = noise.get_noise_2d(x, y) + dry_amount
			var tile_type = TileType.DRY if noise_value < 0 else TileType.ROCKY
			row.append(tile_type)
		grid_data.append(row)

func setup_player():
	player_sprite = Sprite2D.new()
	add_child(player_sprite)
	
	var image = Image.create(SIZE - 4, SIZE - 4, false, Image.FORMAT_RGBA8)
	image.fill(normal_color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	player_sprite.texture = texture
	
	# Position player at center of first tile
	position = Vector2(grid_x * SIZE, grid_y * SIZE)
	player_sprite.position = Vector2(SIZE / 2, SIZE / 2)
	target_position = position

func _process(delta: float) -> void:
	match current_state:
		PlayerState.IDLE:
			handle_input()
		PlayerState.DIGGING:
			update_digging(delta)
		PlayerState.MOVING:
			update_movement(delta)

func handle_input():
	if is_moving:
		return
		
	var new_x = grid_x
	var new_y = grid_y
	
	if Input.is_action_just_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		new_x += 1
	elif Input.is_action_just_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		new_x -= 1
	elif Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		new_y -= 1
	elif Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		new_y += 1
	
	if is_position_valid(new_x, new_y) and (new_x != grid_x or new_y != grid_y):
		var target_tile = get_tile_at(new_x, new_y)
		
		if target_tile != TileType.DIGGED:
			start_digging(new_x, new_y)
		else:
			move_to_position(new_x, new_y)

func start_digging(new_x: int, new_y: int):
	print("Starting to dig at position: ", new_x, ", ", new_y)
	grid_x = new_x
	grid_y = new_y
	target_position = Vector2(grid_x * SIZE, grid_y * SIZE)
	
	current_state = PlayerState.DIGGING
	change_player_color(digging_color)
	move_timer = 0.0
	
	print("Player is digging...")

func update_digging(delta: float):
	move_timer += delta
	
	# Create a bobbing effect while digging
	var bob_offset = sin(move_timer * 10) * 2
	player_sprite.position.y = (SIZE / 2) + bob_offset
	
	if move_timer >= digg_speed:
		finish_digging()

func finish_digging():
	print("Digging complete!")
	
	# Dig the tile
	dig_tile(grid_x, grid_y)
	
	change_player_color(normal_color)
	player_sprite.position.y = SIZE / 2
	
	# Start moving to the dug position
	start_position = position
	current_state = PlayerState.MOVING
	is_moving = true
	move_timer = 0.0

func move_to_position(new_x: int, new_y: int):
	grid_x = new_x
	grid_y = new_y
	start_position = position
	target_position = Vector2(grid_x * SIZE, grid_y * SIZE)
	current_state = PlayerState.MOVING
	is_moving = true
	move_timer = 0.0

func change_player_color(color: Color):
	if not player_sprite:
		return
	
	var image = Image.create(SIZE - 4, SIZE - 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	player_sprite.texture = texture

func update_movement(delta: float):
	if not is_moving:
		return
	
	move_timer += delta
	var progress = move_timer / move_speed
	
	if progress >= 1.0:
		position = target_position
		current_state = PlayerState.IDLE
		is_moving = false
		move_timer = 0.0
		print("Player moved to: ", grid_x, ", ", grid_y)
	else:
		position = start_position.lerp(target_position, progress)

func is_position_valid(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT

# Grid Environment Functions
func dig_tile(x: int, y: int) -> TileType:
	if grid_data[y][x] != TileType.DIGGED:
		grid_data[y][x] = TileType.DIGGED
		queue_redraw()
		print("Tile dug at ", x, ", ", y, " - Type now: ", TileType.keys()[grid_data[y][x]])
		return grid_data[y][x]
	return grid_data[y][x]

func is_tile_digged(x: int, y: int) -> bool:
	if is_position_valid(x, y):
		return grid_data[y][x] == TileType.DIGGED
	return false

func get_tile_at(x: int, y: int) -> TileType:
	if is_position_valid(x, y):
		return grid_data[y][x]
	return TileType.DRY

func _draw() -> void:
	# Draw tiles
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var tile_type = grid_data[y][x]
			var texture = tile_textures[tile_type]
			
			if texture:
				var rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
				draw_texture_rect(texture, rect, false)
			else:
				# Fallback colors if textures don't load
				var color: Color
				match tile_type:
					TileType.DRY:
						color = Color.YELLOW
					TileType.ROCKY:
						color = Color.GRAY
					TileType.DIGGED:
						color = Color.BROWN
				var rect = Rect2(x * SIZE, y * SIZE, SIZE, SIZE)
				draw_rect(rect, color)
	
	# Draw grid lines
	var grid_color = Color(0.1, 0.1, 0.1, 0.5)
	
	# Vertical lines
	for i in range(WIDTH + 1):
		draw_line(
			Vector2(i * SIZE, 0),
			Vector2(i * SIZE, HEIGHT * SIZE),
			grid_color
		)
	
	# Horizontal lines
	for i in range(HEIGHT + 1):
		draw_line(
			Vector2(0, i * SIZE),
			Vector2(SIZE * WIDTH, i * SIZE),
			grid_color
		)

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

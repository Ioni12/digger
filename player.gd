extends Node2D
class_name Player

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
var digg_speed: float = 0.1
var max_stamina: int = 100
var stamina: int = max_stamina

# This will be set by the parent scene - no more group lookups!
var environment: GameEnviroment
var player_sprite: Sprite2D

var normal_color: Color = Color.BLUE
var digging_color: Color = Color.RED

func _ready() -> void:
	# Remove the group lookup - environment is now set by parent
	if not environment:
		print("Error: Environment not set by parent scene!")
		return
	
	setup_player_sprite()
	target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
	
	if EncounterManager:
		EncounterManager.battle_started.connect(_on_battle_started)
	else:
		print("no encounter manager")

func _process(delta: float) -> void:
	if EncounterManager and EncounterManager.is_in_battle:
		return
	
	match current_state:
		PlayerState.IDLE:
			handle_input()
		PlayerState.DIGGING:
			update_digging(delta)
		PlayerState.MOVING:
			update_movement(delta)

func setup_player_sprite():
	if not environment:
		print("Environment not ready for sprite setup")
		return
	
	player_sprite = Sprite2D.new()
	add_child(player_sprite)
	
	var image = Image.create(environment.SIZE - 4, environment.SIZE - 4, false, Image.FORMAT_RGBA8)
	image.fill(normal_color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	player_sprite.texture = texture
	
	player_sprite.position = Vector2(environment.SIZE / 2, environment.SIZE / 2)

func handle_input():
	if is_moving or not environment:
		return
	
	if EncounterManager and EncounterManager.is_in_battle:
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
		var target_tile = environment.get_tile_at(new_x, new_y)
		
		if target_tile != environment.TileType.DIGGED:
			start_digging(new_x, new_y)
		else:
			grid_x = new_x
			grid_y = new_y
			start_position = position
			target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
			current_state = PlayerState.MOVING
			is_moving = true
			move_timer = 0.0

func start_digging(new_x: int, new_y: int):
	print("Starting to dig at position: ", new_x, ", ", new_y)
	grid_x = new_x
	grid_y = new_y
	target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
	
	current_state = PlayerState.DIGGING
	change_player_color(digging_color)
	move_timer = 0.0
	
	print("Player is digging...")

func update_digging(delta: float):
	move_timer += delta
	
	var bob_offset = sin(move_timer * 10) * 2
	player_sprite.position.y = (environment.SIZE / 2) + bob_offset
	
	if move_timer >= digg_speed:
		finish_digging()

func finish_digging():
	print("Digging complete!")
	
	var current_terrain = environment.get_tile_at(grid_x, grid_y)
	var revealed_terrain = environment.dig_tile(grid_x, grid_y)
	print("Revealed terrain: ", GameEnviroment.TileType.keys()[revealed_terrain])
	
	check_for_encounter(current_terrain)
	change_player_color(normal_color)
	player_sprite.position.y = environment.SIZE / 2
	
	start_position = position
	current_state = PlayerState.MOVING
	is_moving = true
	move_timer = 0.0

func change_player_color(color: Color):
	if not player_sprite:
		return
	
	var image = Image.create(environment.SIZE - 4, environment.SIZE - 4, false, Image.FORMAT_RGBA8)
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
		#check_for_encounter()
	else:
		position = start_position.lerp(target_position, progress)

func is_position_valid(x: int, y: int) -> bool:
	if x < 0 or y < 0:
		return false
	
	var max_x = environment.WIDTH 
	var max_y = environment.HEIGHT 
	
	if x >= max_x or y >= max_y:
		return false
	
	return true

func _on_battle_started():
	print("Player: Battle started, completing current movement")
	if is_moving:
		position = target_position
		is_moving = false
		current_state = PlayerState.IDLE
		move_timer = 0.0

func check_for_encounter(current_tile):
	if not environment or not EncounterManager:
		return
	
	#var current_tile = get_current_tile()
	EncounterManager.check_encounter(current_tile)

func get_current_tile() -> GameEnviroment.TileType:
	if environment:
		return environment.get_tile_at(grid_x, grid_y)
	return GameEnviroment.TileType.DRY

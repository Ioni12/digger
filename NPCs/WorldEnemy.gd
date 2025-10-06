extends Node2D
class_name WorldEnemy

var environment: GameEnviroment
var move_timer: float = 0.0
var move_speed: float = 1.0  # seconds between moves
var sprite: ColorRect

func _init(env: GameEnviroment):
	environment = env
	setup_sprite()

func setup_sprite():
	sprite = ColorRect.new()
	sprite.size = Vector2(environment.SIZE, environment.SIZE)
	sprite.color = Color.RED
	sprite.position = Vector2(0, 0)
	add_child(sprite)

func _process(delta):
	move_timer += delta
	if move_timer >= move_speed:
		move_timer = 0.0
		try_move()
	
	# Check for encounter every frame for instant response
	check_for_encounter()

func check_for_encounter():
	var enemy_grid = get_grid_position()
	var player_grid = environment.get_player_grid_position()
	
	if enemy_grid == player_grid:
		# Find this enemy's index and trigger encounter
		var enemy_index = environment.entity_manager.enemies.find(self)
		if enemy_index != -1:
			environment.entity_manager.trigger_enemy_encounter(self, enemy_index)

func try_move():
	var player_grid_pos = environment.get_player_grid_position()
	
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	directions.shuffle()
	
	for dir in directions:
		var new_pos = position + (dir * environment.SIZE)
		var grid_x = int(new_pos.x / environment.SIZE)
		var grid_y = int(new_pos.y / environment.SIZE)
		
		if environment.is_tile_digged(grid_x, grid_y):
			position = new_pos
			
			# Check for encounter immediately after moving
			var new_grid_pos = get_grid_position()
			if new_grid_pos == player_grid_pos:
				# Find this enemy's index in the environment's enemies array
				var enemy_index = environment.entity_manager.enemies.find(self)
				if enemy_index != -1:
					environment.entity_manager.trigger_enemy_encounter(self, enemy_index)
			break

# Get enemy's grid position (already implemented)
func get_grid_position() -> Vector2i:
	return Vector2i(int(position.x / environment.SIZE), int(position.y / environment.SIZE))

# Get enemy's world position (pixel coordinates)
func get_world_position() -> Vector2:
	return position

# Get player's grid position (already implemented)
func get_player_grid_position() -> Vector2i:
	return environment.get_player_grid_position()

# Additional utility functions
func get_distance_to_player() -> float:
	var enemy_grid = get_grid_position()
	var player_grid = get_player_grid_position()
	return enemy_grid.distance_to(Vector2(player_grid))

func is_adjacent_to_player() -> bool:
	var enemy_grid = get_grid_position()
	var player_grid = get_player_grid_position()
	var distance = enemy_grid.distance_to(Vector2(player_grid))
	return distance <= 1.41  # sqrt(2) for diagonal adjacency

func is_on_same_tile_as_player() -> bool:
	return get_grid_position() == get_player_grid_position()

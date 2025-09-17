# PlayerMovement.gd
extends Node
class_name PlayerMovement

enum PlayerState {
	IDLE,
	DIGGING,
	MOVING
}

var environment: GameEnviroment
var player_stats: PlayerStats
var stamina_system: StaminaSystem

# Movement and world interaction
var grid_x: int = 0
var grid_y: int = 0
var start_position: Vector2
var target_position: Vector2
var current_state: PlayerState = PlayerState.IDLE
var is_moving: bool = false
var move_timer: float = 0.0
var move_speed: float = 0.12
var digg_speed: float = 0.1

# Store original speeds for restoration
var base_digg_speed: float = 0.1
var base_move_speed: float = 0.12

var current_dig_failed: bool = false

func _ready():
	player_stats = get_parent().get_node("PlayerStats") if get_parent().has_node("PlayerStats") else null
	stamina_system = get_parent().get_node("StaminaSystem") if get_parent().has_node("StaminaSystem") else null
	
	if environment:
		target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)

func _process(delta: float):
	if EncounterManager and EncounterManager.is_in_battle:
		return
	
	match current_state:
		PlayerState.IDLE:
			handle_input()
		PlayerState.DIGGING:
			update_digging(delta)
		PlayerState.MOVING:
			update_movement(delta)

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
			move_to_position(new_x, new_y)
	environment.update_player_position(new_x, new_y)
	
func move_to_position(new_x: int, new_y: int):
	"""Move to a dug tile"""
	grid_x = new_x
	grid_y = new_y
	start_position = get_parent().position
	target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
	current_state = PlayerState.MOVING
	is_moving = true
	move_timer = 0.0
	
	if new_x == 0 and new_y == 0:
		heal_at_sanctuary()

func start_digging(new_x: int, new_y: int):
	"""Start digging at a new position"""
	
	var target_tile = environment.get_tile_at(new_x, new_y)
	
	# Set the digging speed based on tile type
	digg_speed = environment.get_dig_speed_for_tile(target_tile)
	
	print("Starting to dig at position: ", new_x, ", ", new_y)
	
	if stamina_system:
		print("Current stamina: ", player_stats.data.current_stamina, "/", player_stats.data.max_stamina)
		
		# Check if we can dig normally
		var can_dig_normally = stamina_system.can_dig()
		
		if not can_dig_normally:
			print("WARNING: Digging with low stamina - penalties will apply!")
			var collapsed = stamina_system.increase_exhaustion()
			if collapsed:
				return  # Player collapsed, stop digging
		
		# Always consume stamina
		stamina_system.consume_stamina(stamina_system.stamina_cost_per_dig)
		
		if stamina_system.should_dig_fail():
			print("DIG FAILED due to exhaustion!")
			current_dig_failed = stamina_system.should_dig_fail()
			if current_dig_failed:
				print("This dig will fail!")
	
	# Continue with normal digging process
	grid_x = new_x
	grid_y = new_y
	environment.update_player_position(grid_x, grid_y)
	target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
	
	current_state = PlayerState.DIGGING
	move_timer = 0.0
	
	print("Player is digging...")

func update_digging(delta: float):
	"""Update digging animation and timer"""
	move_timer += delta
	
	# Add shaking effect for exhausted digging
	var bob_intensity = 2.0
	if player_stats and player_stats.data.exhaustion_level >= 2:
		# Violent shaking for critical exhaustion
		bob_intensity = 8.0
	elif player_stats and player_stats.data.exhaustion_level >= 1:
		# Moderate shaking for level 1 exhaustion
		bob_intensity = 5.0
	
	# Apply visual effect to parent (Player node)
	var player_visual = get_parent().get_node("PlayerVisual") if get_parent().has_node("PlayerVisual") else null
	if player_visual:
		var bob_offset = sin(move_timer * 10) * bob_intensity
		player_visual.apply_digging_effect(bob_offset)
	
	if move_timer >= digg_speed:
		finish_digging()

func finish_digging():
	"""Complete the digging action"""
	
	
	if not current_dig_failed:
		print("Digging complete!")
	# Only do the actual terrain digging if the dig didn't fail
		var current_terrain = environment.get_tile_at(grid_x, grid_y)
		var revealed_terrain = environment.dig_tile(grid_x, grid_y)
		print("Revealed terrain: ", GameEnviroment.TileType.keys()[revealed_terrain])
		check_for_encounter(current_terrain)
	else:
		print("Dig failed! No terrain revealed.")
		current_dig_failed = false  # Reset for next dig
	
	# Reset visual effects
	var player_visual = get_parent().get_node("PlayerVisual") if get_parent().has_node("PlayerVisual") else null
	if player_visual:
		player_visual.reset_digging_effect()
	
	start_position = get_parent().position
	current_state = PlayerState.MOVING
	is_moving = true
	move_timer = 0.0

func update_movement(delta: float):
	"""Update movement interpolation"""
	if not is_moving:
		return
	
	move_timer += delta
	var progress = move_timer / move_speed
	
	if progress >= 1.0:
		get_parent().position = target_position
		current_state = PlayerState.IDLE
		is_moving = false
		move_timer = 0.0
	else:
		get_parent().position = start_position.lerp(target_position, progress)

func is_position_valid(x: int, y: int) -> bool:
	"""Check if a grid position is within bounds"""
	if x < 0 or y < 0:
		return false
	
	if not environment:
		return false
	
	var max_x = environment.WIDTH 
	var max_y = environment.HEIGHT 
	
	if x >= max_x or y >= max_y:
		return false
	
	return true

func relocate_to_safe_position():
	"""Find nearest dug tile or return to spawn (used after collapse)"""
	if not environment:
		return
		
	var search_radius = 1
	var found_safe_spot = false
	
	# Search in expanding circles for a dug tile
	while search_radius <= 5 and not found_safe_spot:
		for x in range(grid_x - search_radius, grid_x + search_radius + 1):
			for y in range(grid_y - search_radius, grid_y + search_radius + 1):
				if is_position_valid(x, y) and environment.get_tile_at(x, y) == environment.TileType.DIGGED:
					grid_x = x
					grid_y = y
					get_parent().position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
					target_position = get_parent().position
					found_safe_spot = true
					print("Relocated to safe position: (", x, ", ", y, ")")
					return
		search_radius += 1
	
	# If no dug tile found, return to spawn
	if not found_safe_spot:
		grid_x = 0
		grid_y = 0
		get_parent().position = Vector2(0, 0)
		target_position = get_parent().position
		print("No safe position found, returned to spawn (0, 0)")

func check_for_encounter(current_tile):
	"""Check for random encounters"""
	if not environment or not EncounterManager:
		return
	
	EncounterManager.check_encounter(current_tile)

func get_current_tile() -> GameEnviroment.TileType:
	"""Get the tile type at current position"""
	if environment:
		return environment.get_tile_at(grid_x, grid_y)
	return GameEnviroment.TileType.DRY

func on_battle_started():
	"""Handle battle start - complete current movement"""
	print("Movement: Battle started, completing current movement")
	if is_moving:
		get_parent().position = target_position
		is_moving = false
		current_state = PlayerState.IDLE
		move_timer = 0.0

func heal_at_sanctuary():
	"""Heal player when they reach the sanctuary at (0,0)"""
	if not player_stats or not stamina_system:
		return
		
	print("Reached sanctuary! Healing...")
	
	# Fully restore health and stamina
	player_stats.data.current_hp = player_stats.data.max_hp
	player_stats.data.current_stamina = player_stats.data.max_stamina
	
	# Reset exhaustion level and restore normal speeds
	player_stats.data.exhaustion_level = 0
	stamina_system.restore_normal_speeds()
	
	# Emit updates so UI refreshes
	player_stats.health_changed.emit(player_stats.data.current_hp, player_stats.data.max_hp)
	stamina_system.stamina_changed.emit(player_stats.data.current_stamina, player_stats.data.max_stamina)
	
	# Save the changes
	player_stats.save_stats()
	
	print("Fully healed! HP: %d/%d, Stamina: %d/%d" % [
		player_stats.data.current_hp, player_stats.data.max_hp,
		player_stats.data.current_stamina, player_stats.data.max_stamina
	])

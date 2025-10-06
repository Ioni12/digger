# PlayerMovement.gd - Enhanced with multi-tile digging
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
var grid_x: int = GameEnviroment.WIDTH/2
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

# NEW: Multi-tile digging support
var pending_dig_positions: Array = []
var dig_direction: Vector2i = Vector2i.ZERO  # For line patterns

func _ready():
	player_stats = get_parent().get_node("PlayerStats") if get_parent().has_node("PlayerStats") else null
	stamina_system = get_parent().get_node("StaminaSystem") if get_parent().has_node("StaminaSystem") else null
	
	if environment:
		target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
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
	
	if environment:
		environment.update_player_position(grid_x, grid_y)

func handle_input():
	if is_moving or not environment:
		return
	
	if EncounterManager and EncounterManager.is_in_battle:
		return
	
	# CHECK FOR NPC INTERACTION FIRST (before movement)
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		var player = get_parent() as Player
		if player and player.try_interact_with_npc():
			return  # Interaction occurred, don't process movement
	
	# EXISTING MOVEMENT CODE (unchanged)
	var new_x = grid_x
	var new_y = grid_y
	var movement_direction = Vector2i.ZERO
	
	if Input.is_action_just_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		new_x += 1
		movement_direction = Vector2i(1, 0)
	elif Input.is_action_just_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		new_x -= 1
		movement_direction = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		new_y -= 1
		movement_direction = Vector2i(0, -1)
	elif Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		new_y += 1
		movement_direction = Vector2i(0, 1)
		
	if is_position_valid(new_x, new_y) and (new_x != grid_x or new_y != grid_y):
		var target_tile = environment.get_tile_at(new_x, new_y)
		
		if target_tile != environment.TileType.DIGGED:
			# Store the movement direction for line patterns
			dig_direction = movement_direction
			start_digging(new_x, new_y)
		else:
			move_to_position(new_x, new_y)
	environment.update_player_position(new_x, new_y)

# NEW: Get digging pattern based on tool and direction
func get_dig_pattern(pattern_type: String, range_val: int, target_x: int, target_y: int) -> Array:
	var positions = []
	
	match pattern_type:
		"single":
			positions.append(Vector2i(target_x, target_y))
		
		"cross":
			positions.append(Vector2i(target_x, target_y))  # Center
			positions.append(Vector2i(target_x + 1, target_y))  # Right
			positions.append(Vector2i(target_x - 1, target_y))  # Left
			positions.append(Vector2i(target_x, target_y + 1))  # Down
			positions.append(Vector2i(target_x, target_y - 1))  # Up
		
		"square":
			for y in range(target_y - range_val, target_y + range_val + 1):
				for x in range(target_x - range_val, target_x + range_val + 1):
					positions.append(Vector2i(x, y))
		
		"line":
			# Dig in a line in the direction of movement
			positions.append(Vector2i(target_x, target_y))  # Starting position
			for i in range(1, range_val + 1):
				var line_x = target_x + (dig_direction.x * i)
				var line_y = target_y + (dig_direction.y * i)
				positions.append(Vector2i(line_x, line_y))
	
	# Filter out invalid positions
	var valid_positions = []
	for pos in positions:
		if is_position_valid(pos.x, pos.y):
			valid_positions.append(pos)
	
	return valid_positions

func start_digging(new_x: int, new_y: int):
	"""Enhanced start digging with tool support"""
	
	var player = get_parent()
	var digging_tool = null
	
	# Get equipped digging tool
	if player and player.inventory:
		digging_tool = player.inventory.get_equipped_in_slot(Item.EquipmentSlot.TOOL)
	
	# Get tool properties or use defaults
	var speed_multiplier = digging_tool.dig_speed_multiplier if digging_tool else 1.0
	var pattern = digging_tool.dig_pattern if digging_tool else "single"
	var range_val = digging_tool.dig_range if digging_tool else 1
	var stamina_multiplier = digging_tool.stamina_efficiency if digging_tool else 1.0
	
	# Calculate positions to dig based on tool pattern
	pending_dig_positions = get_dig_pattern(pattern, range_val, new_x, new_y)
	
	print("Starting to dig with pattern '%s' at %d positions" % [pattern, pending_dig_positions.size()])
	if digging_tool:
		print("Using tool: %s (Speed: x%.1f, Stamina: x%.1f)" % [digging_tool.name, speed_multiplier, stamina_multiplier])
	
	# Use the target tile type for speed calculation (primary tile being dug)
	var target_tile = environment.get_tile_at(new_x, new_y)
	var base_speed = environment.get_dig_speed_for_tile(target_tile)
	
	# Apply tool speed multiplier
	digg_speed = base_speed / speed_multiplier
	
	# Calculate total stamina cost
	if stamina_system:
		print("Current stamina: ", player_stats.data.current_stamina, "/", player_stats.data.max_stamina)
		
		# Calculate stamina cost: base cost * number of tiles * tool efficiency
		var total_stamina_cost = int(stamina_system.stamina_cost_per_dig * pending_dig_positions.size() * stamina_multiplier)
		print("Total stamina cost for this dig: %d" % total_stamina_cost)
		
		# Check if we can dig normally
		var can_dig_normally = stamina_system.can_dig()
		
		if not can_dig_normally:
			print("WARNING: Digging with low stamina - penalties will apply!")
			var collapsed = stamina_system.increase_exhaustion()
			if collapsed:
				pending_dig_positions.clear()
				return  # Player collapsed, stop digging
		
		# Consume stamina for all tiles being dug
		stamina_system.consume_stamina(total_stamina_cost)
		
		if stamina_system.should_dig_fail():
			print("DIG FAILED due to exhaustion!")
			current_dig_failed = true
	
	# Move to the primary dig position (first in the pattern)
	if pending_dig_positions.size() > 0:
		var primary_pos = pending_dig_positions[0]
		grid_x = primary_pos.x
		grid_y = primary_pos.y
	else:
		# Fallback to original position if pattern failed
		grid_x = new_x
		grid_y = new_y
	
	environment.update_player_position(grid_x, grid_y)
	target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
	
	current_state = PlayerState.DIGGING
	move_timer = 0.0
	
	print("Player is digging...")

func update_digging(delta: float):
	"""Update digging animation and timer - enhanced for multi-tile feedback"""
	move_timer += delta
	
	# Add shaking effect for exhausted digging
	var bob_intensity = 2.0
	if player_stats and player_stats.data.exhaustion_level >= 2:
		# Violent shaking for critical exhaustion
		bob_intensity = 8.0
	elif player_stats and player_stats.data.exhaustion_level >= 1:
		# Moderate shaking for level 1 exhaustion
		bob_intensity = 5.0
	
	# Enhanced shaking for multi-tile digging
	if pending_dig_positions.size() > 1:
		bob_intensity *= 1.5  # More intense shaking for bigger operations
	
	# Apply visual effect to parent (Player node)
	var player_visual = get_parent().get_node("PlayerVisual") if get_parent().has_node("PlayerVisual") else null
	if player_visual:
		var bob_offset = sin(move_timer * 12) * bob_intensity  # Slightly faster for power tools
		player_visual.apply_digging_effect(bob_offset)
	
	if move_timer >= digg_speed:
		finish_digging()

func finish_digging():
	"""Enhanced finish digging - handles multiple tiles"""
	var items_found = 0
	var total_tiles_dug = 0
	
	if not current_dig_failed:
		print("Multi-tile digging complete!")
		
		# Dig all positions in the pattern
		for pos in pending_dig_positions:
			if is_position_valid(pos.x, pos.y):
				var current_terrain = environment.get_tile_at(pos.x, pos.y)
				
				# Only dig if not already dug
				if current_terrain != environment.TileType.DIGGED:
					var revealed_terrain = environment.dig_tile(pos.x, pos.y)
					total_tiles_dug += 1
					
					# Lower chance for items per tile to balance multi-tile digging
					var item_chance = 0.3 if pending_dig_positions.size() == 1 else 0.15
					if randf() < item_chance:
						var player = get_parent()
						var random_item = Item.create_misc("Stone", "A common stone", 1)
						random_item.is_stackable = true
						player.add_item(random_item)
						items_found += 1
					
					# Check for encounter only on the primary tile (first one)
					if pos == pending_dig_positions[0]:
						check_for_encounter(current_terrain)
		
		# Show summary popup for multi-tile operations
		if total_tiles_dug > 1:
			var summary_text = "%d tiles dug" % total_tiles_dug
			if items_found > 0:
				summary_text += ", +%d items" % items_found
			show_resource_popup(summary_text, Color.CYAN)
		elif items_found > 0:
			show_resource_popup("+1 Stone", Color.GRAY)
		
		print("Dig summary: %d tiles dug, %d items found" % [total_tiles_dug, items_found])
	else:
		print("Dig failed! No terrain revealed.")
		current_dig_failed = false  # Reset for next dig
	
	# Clean up
	pending_dig_positions.clear()
	dig_direction = Vector2i.ZERO
	
	# Reset visual effects
	var player_visual = get_parent().get_node("PlayerVisual") if get_parent().has_node("PlayerVisual") else null
	if player_visual:
		player_visual.reset_digging_effect()
	
	start_position = get_parent().position
	current_state = PlayerState.MOVING
	is_moving = true
	move_timer = 0.0

func move_to_position(new_x: int, new_y: int):
	"""Move to a dug tile"""
	grid_x = new_x
	grid_y = new_y
	start_position = get_parent().position
	target_position = Vector2(grid_x * environment.SIZE, grid_y * environment.SIZE)
	current_state = PlayerState.MOVING
	is_moving = true
	move_timer = 0.0
	
	if new_x == GameEnviroment.WIDTH/2 and new_y == 0:
		heal_at_sanctuary()

func show_resource_popup(text: String, color: Color):
	var popup_scene = preload("res://UIs/ResourcePopup.tscn")
	var popup = popup_scene.instantiate()
	
	# Add to the scene tree (use main scene or UI layer)
	get_tree().current_scene.add_child(popup)
	
	# Position it above the player
	var player_pos = get_parent().global_position
	popup.show_text(text, color, player_pos + Vector2(0, -50))

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
	"""Handle battle start - complete current movement and clear pending digs"""
	print("Movement: Battle started, completing current movement")
	if is_moving:
		get_parent().position = target_position
		is_moving = false
		current_state = PlayerState.IDLE
		move_timer = 0.0
	
	# Clear any pending dig operations
	pending_dig_positions.clear()
	current_dig_failed = false

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

# === DEBUG METHODS ===
func debug_print_dig_info():
	"""Debug method to show current digging tool info"""
	var player = get_parent()
	if player and player.inventory:
		var tool = player.inventory.get_equipped_in_slot(Item.EquipmentSlot.TOOL)
		if tool:
			print("=== EQUIPPED DIGGING TOOL ===")
			tool.print_item_info()
		else:
			print("No digging tool equipped - using hands (single tile, normal speed)")
	else:
		print("No player inventory found")

func debug_spawn_tools():
	"""Debug method to add sample digging tools to inventory"""
	var player = get_parent()
	if player and player.inventory:
		player.add_item(Item.create_basic_shovel())
		player.add_item(Item.create_iron_pickaxe())
		player.add_item(Item.create_mining_drill())
		player.add_item(Item.create_excavator_shovel())
		player.add_item(Item.create_tunnel_bore())
		player.add_item(Item.create_power_drill())
		print("Added all sample digging tools to inventory!")

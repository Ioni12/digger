# StaminaSystem.gd
extends Node
class_name StaminaSystem

var player_stats: PlayerStats
var movement: PlayerMovement

signal stamina_changed(current_stamina: int, max_stamina: int)

# STAMINA SYSTEM VARIABLES
var stamina_cost_per_dig: int = 3
var min_stamina_to_dig: int = 1
var low_stamina_threshold: int = 25
var max_exhaustion: int = 3

# Dig failure chances by exhaustion level
var dig_failure_rates = [0.0, 0.25, 0.5]  # 0%, 25%, 50% chance

func _ready():
	player_stats = get_parent().get_node("PlayerStats") if get_parent().has_node("PlayerStats") else null
	movement = get_parent().get_node("PlayerMovement") if get_parent().has_node("PlayerMovement") else null
	
	if player_stats:
		# Emit initial stamina state
		stamina_changed.emit(player_stats.data.current_stamina, player_stats.data.max_stamina)

func _process(delta: float):
	if not player_stats:
		return
		
	# Skip processing during battle
	if EncounterManager and EncounterManager.is_in_battle:
		return

func consume_stamina(amount: int):
	"""Safely consume stamina and emit updates"""
	if not player_stats:
		return
		
	var old_stamina = player_stats.data.current_stamina
	player_stats.data.current_stamina = max(0, player_stats.data.current_stamina - amount)
	
	if player_stats.data.current_stamina != old_stamina:
		stamina_changed.emit(player_stats.data.current_stamina, player_stats.data.max_stamina)
		player_stats.save_stats()
		print("Stamina consumed: ", amount, " | Current: ", player_stats.data.current_stamina, "/", player_stats.data.max_stamina)

func restore_stamina(amount: int):
	"""Restore stamina and emit updates"""
	if not player_stats:
		return
		
	var old_stamina = player_stats.data.current_stamina
	player_stats.data.current_stamina = min(player_stats.data.max_stamina, player_stats.data.current_stamina + amount)
	
	if player_stats.data.current_stamina != old_stamina:
		stamina_changed.emit(player_stats.data.current_stamina, player_stats.data.max_stamina)
		player_stats.save_stats()
		print("Stamina restored: ", amount, " | Current: ", player_stats.data.current_stamina, "/", player_stats.data.max_stamina)

func can_dig() -> bool:
	"""Check if player has enough stamina to dig normally"""
	return player_stats.data.current_stamina >= min_stamina_to_dig if player_stats else false

func is_low_stamina() -> bool:
	"""Check if player has low stamina"""
	return player_stats.data.current_stamina <= low_stamina_threshold if player_stats else false

func apply_exhaustion_penalties():
	"""Apply speed penalties based on exhaustion level"""
	if not movement or not player_stats:
		return
		
	match player_stats.data.exhaustion_level:
		1:
			# Level 1: 150% slower digging, 30% slower movement
			movement.digg_speed = movement.base_digg_speed * 2.5  # 250% of original time
			movement.move_speed = movement.base_move_speed * 1.3  # 130% of original time
			print("Level 1 Exhaustion: Digging much slower, movement slightly slower")
			
		2:
			# Level 2: 300% slower digging, 60% slower movement
			movement.digg_speed = movement.base_digg_speed * 4.0  # 400% of original time
			movement.move_speed = movement.base_move_speed * 1.6  # 160% of original time
			print("Level 2 Exhaustion: CRITICAL - Very slow digging and movement")
			
		_:
			print("Unexpected exhaustion level: ", player_stats.data.exhaustion_level)

func increase_exhaustion():
	"""Increase exhaustion level and apply penalties"""
	if not player_stats:
		return false
		
	player_stats.data.exhaustion_level += 1
	print("Exhaustion level increased to: ", player_stats.data.exhaustion_level)
	
	# Check for collapse
	if player_stats.data.exhaustion_level >= max_exhaustion:
		trigger_collapse()
		return true
	
	apply_exhaustion_penalties()
	return false

func trigger_collapse():
	"""Handle player collapse from over-exhaustion"""
	if not player_stats or not movement:
		return
		
	print("PLAYER COLLAPSED from exhaustion!")
	
	# Immediate penalties
	var stamina_loss = 20
	player_stats.data.max_stamina = max(30, player_stats.data.max_stamina - stamina_loss)  # Don't go below 30
	player_stats.data.current_stamina = int(player_stats.data.max_stamina * 0.25)  # Wake up with 25% stamina
	
	# Reset exhaustion and speeds
	player_stats.data.exhaustion_level = 0
	restore_normal_speeds()
	
	# Find safe location
	movement.relocate_to_safe_position()
	
	# Emit stamina update after collapse
	stamina_changed.emit(player_stats.data.current_stamina, player_stats.data.max_stamina)
	player_stats.save_stats()
	
	print("Collapsed! Lost ", stamina_loss, " max stamina. Current: ", player_stats.data.current_stamina, "/", player_stats.data.max_stamina)

func restore_normal_speeds():
	"""Restore original movement and digging speeds"""
	if not movement:
		return
		
	movement.digg_speed = movement.base_digg_speed
	movement.move_speed = movement.base_move_speed
	print("Speeds restored to normal")

func get_stamina_color() -> Color:
	"""Get color based on current stamina level"""
	if not player_stats:
		return Color.BLUE
		
	if player_stats.data.current_stamina <= low_stamina_threshold:
		if player_stats.data.exhaustion_level >= 2:
			return Color.DARK_RED  # Critical exhaustion
		elif player_stats.data.exhaustion_level >= 1:
			return Color.PURPLE    # Exhaustion
		else:
			return Color.ORANGE    # Low stamina
	else:
		return Color.BLUE  # Normal

# Debug function
func debug_modify_stamina(amount: int):
	"""Debug function to test stamina system"""
	if amount > 0:
		restore_stamina(amount)
	else:
		consume_stamina(abs(amount))

func should_dig_fail() -> bool:
	"""Check if dig should fail due to exhaustion"""
	if not player_stats:
		return false
		
	var level = min(player_stats.data.exhaustion_level, dig_failure_rates.size() - 1)
	var failure_chance = dig_failure_rates[level]
	
	if failure_chance > 0:
		var roll = randf()
		print("Dig failure check: ", roll, " vs ", failure_chance)
		return roll < failure_chance
	
	return false

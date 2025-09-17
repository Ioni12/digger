extends Node

class_name Character

# Character stats
var char_name: String
var max_hp: int
var current_hp: int
var attack: int
var defense: int
var base_defense: int
var base_speed: int
var current_speed: int
var is_defending: bool = false

func _init(n: String = "", hp: int = 100, att: int = 10, def: int = 5, spd: int = 10):
	char_name = n
	max_hp = hp
	current_hp = hp
	attack = att
	defense = def
	base_defense = def
	base_speed = spd
	current_speed = spd

func is_alive() -> bool:
	return current_hp > 0

func take_damage(damage: int):
	# Apply defense reduction if defending
	var actual_damage = damage
	if is_defending:
		actual_damage = max(1, damage - defense)  # Minimum 1 damage
	else:
		actual_damage = max(0, damage - (defense / 2))  # Partial defense when not defending
	
	current_hp = max(0, current_hp - actual_damage)
	
	# Reset defending state after taking damage
	is_defending = false

func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)

func defend():
	is_defending = true
	# Defending characters get their turn faster
	current_speed -= base_speed / 2

func act():
	current_speed -= base_speed
	# Reset defending state when taking other actions
	is_defending = false

func advance_time():
	var speed_bonus = get_speed_with_fatigue()
	current_speed += speed_bonus

func get_speed_with_fatigue() -> int:
	var health_percentage = float(current_hp) / float(max_hp)
	
	# No fatigue above 75% health
	if health_percentage > 0.75:
		return base_speed
	
	# Calculate speed reduction based on health loss
	var fatigue_threshold = 0.75
	var health_loss = fatigue_threshold - health_percentage
	var speed_reduction = (health_loss / fatigue_threshold) * 0.5
	var fatigued_speed = base_speed * (1.0 - speed_reduction)
	
	return max(1, int(fatigued_speed))

func get_current_defense() -> int:
	if is_defending:
		return defense
	else:
		return defense / 2

# Utility functions
func get_health_percentage() -> float:
	return float(current_hp) / float(max_hp)

func is_critically_injured() -> bool:
	return get_health_percentage() < 0.25

func reset_character():
	current_hp = max_hp
	current_speed = base_speed
	defense = base_defense
	is_defending = false

# Debug function
func print_status():
	print("=== %s Status ===" % char_name)
	print("HP: %d/%d (%.1f%%)" % [current_hp, max_hp, get_health_percentage() * 100])
	print("Attack: %d | Defense: %d | Speed: %d" % [attack, get_current_defense(), current_speed])
	print("Defending: %s | Alive: %s" % [is_defending, is_alive()])

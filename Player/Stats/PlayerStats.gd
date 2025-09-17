# PlayerStats.gd
extends Node
class_name PlayerStats

var data: PlayerStatsData

signal health_changed(current_hp: int, max_hp: int)
signal level_up(new_level: int)
signal stats_changed()

func _ready():
	if not data:
		data = PlayerStatsData.new()
	
	# Emit initial state
	health_changed.emit(data.current_hp, data.max_hp)
	stats_changed.emit()

func get_stats_dictionary() -> Dictionary:
	"""Returns all player stats as a dictionary for saving/serialization"""
	return {
		"name": data.player_name,
		"level": data.level,
		"max_hp": data.max_hp,
		"current_hp": data.current_hp,
		"base_attack": data.base_attack,
		"base_defense": data.base_defense,
		"base_speed": data.base_speed,
		"exp": data.exp,
		"exp_to_next": data.exp_to_next,
		"max_stamina": data.max_stamina,
		"stamina": data.current_stamina,
		"exhaustion_level": data.exhaustion_level
	}

func load_stats_from_dictionary(stats: Dictionary):
	"""Loads player stats from a dictionary"""
	data.player_name = stats.get("name", "Hero")
	data.level = stats.get("level", 1)
	data.max_hp = stats.get("max_hp", 100)
	data.current_hp = stats.get("current_hp", data.max_hp)
	data.base_attack = stats.get("base_attack", 25)
	data.base_defense = stats.get("base_defense", 15)
	data.base_speed = stats.get("base_speed", 12)
	data.exp = stats.get("exp", 0)
	data.exp_to_next = stats.get("exp_to_next", 100)
	data.max_stamina = stats.get("max_stamina", 100)
	data.current_stamina = stats.get("stamina", data.max_stamina)
	data.exhaustion_level = stats.get("exhaustion_level", 0)
	
	data.reset_combat_stats()
	health_changed.emit(data.current_hp, data.max_hp)
	stats_changed.emit()

func save_stats():
	"""Save stats to persistent storage"""
	ResourceSaver.save(data, "user://player_stats.tres")
	
func load_stats():
	"""Load stats from persistent storage"""
	if ResourceLoader.exists("user://player_stats.tres"):
		data = ResourceLoader.load("user://player_stats.tres")
		data.reset_combat_stats()
	else:
		data = PlayerStatsData.new()
	
	health_changed.emit(data.current_hp, data.max_hp)
	stats_changed.emit()

func reset_combat_stats():
	"""Resets combat stats to base values"""
	data.reset_combat_stats()

func gain_exp(amount: int):
	"""Adds experience and handles level ups"""
	data.exp += amount
	print("Gained ", amount, " EXP! Total: ", data.exp, "/", data.exp_to_next)
	
	while data.exp >= data.exp_to_next:
		level_up_character()
	
	save_stats()

func level_up_character():
	"""Handles level up progression"""
	data.exp -= data.exp_to_next
	data.level += 1
	
	# Stat increases per level
	var hp_increase = 15
	var attack_increase = 2
	var defense_increase = 2
	var speed_increase = 1
	
	data.max_hp += hp_increase
	data.current_hp = data.max_hp  # Full heal on level up
	data.base_attack += attack_increase
	data.base_defense += defense_increase
	data.base_speed += speed_increase
	
	# Increase exp requirement
	data.exp_to_next = int(data.exp_to_next * 1.5)
	
	data.reset_combat_stats()
	
	print("LEVEL UP! Now level ", data.level)
	print("Stats: HP=", data.max_hp, " ATK=", data.base_attack, " DEF=", data.base_defense, " SPD=", data.base_speed)
	
	level_up.emit(data.level)
	health_changed.emit(data.current_hp, data.max_hp)
	stats_changed.emit()

func take_damage(damage: int):
	"""Applies damage with defense calculation"""
	var actual_damage = damage
	if data.is_defending:
		actual_damage = max(1, damage - data.current_defense)
	else:
		actual_damage = max(1, damage - (data.current_defense / 2))
	
	data.current_hp = max(0, data.current_hp - actual_damage)
	data.is_defending = false
	
	health_changed.emit(data.current_hp, data.max_hp)
	save_stats()
	return actual_damage

func heal(amount: int):
	"""Heals the player"""
	var old_hp = data.current_hp
	data.current_hp = min(data.max_hp, data.current_hp + amount)
	var actual_heal = data.current_hp - old_hp
	
	if actual_heal > 0:
		health_changed.emit(data.current_hp, data.max_hp)
		save_stats()
	
	return actual_heal

func is_alive() -> bool:
	return data.current_hp > 0

func get_health_percentage() -> float:
	return data.get_health_percentage()

# Combat functions
func defend():
	"""Sets defending state"""
	data.is_defending = true
	data.current_speed -= data.base_speed / 2

func act():
	"""Called after taking an action in combat"""
	data.current_speed -= data.base_speed
	data.is_defending = false

func advance_time():
	"""Advances the combat turn timer"""
	var speed_bonus = data.get_speed_with_fatigue()
	data.current_speed += speed_bonus

func get_current_defense() -> int:
	"""Gets current defense value"""
	if data.is_defending:
		return data.current_defense
	else:
		return data.current_defense / 2

func print_stats():
	print("=== %s Stats ===" % data.player_name)
	print("Level: %d | EXP: %d/%d" % [data.level, data.exp, data.exp_to_next])
	print("HP: %d/%d | ATK: %d | DEF: %d | SPD: %d" % [data.current_hp, data.max_hp, data.base_attack, data.base_defense, data.base_speed])
	if data.is_defending:
		print("Status: DEFENDING")

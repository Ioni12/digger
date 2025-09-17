extends Resource
class_name PlayerStatsData

@export var player_name: String = "Hero"
@export var level: int = 1
@export var current_hp: int = 100
@export var max_hp: int = 100
@export var base_attack: int = 25
@export var base_defense: int = 15
@export var base_speed: int = 12
@export var exp: int = 0
@export var exp_to_next: int = 100
@export var max_stamina: int = 100
@export var current_stamina: int = max_stamina
@export var exhaustion_level: int = 0

var current_attack: int 
var current_defense: int
var current_speed: int 
var is_defending: bool = false

func _init() -> void:
	reset_combat_stats()

func reset_combat_stats():
	current_attack = base_attack
	current_defense = base_defense
	current_speed = base_speed
	is_defending = false

func get_health_percentage() -> float:
	return float(current_hp) / float(max_hp)

func get_speed_with_fatigue() -> int:
	var health_percentage = get_health_percentage()
	
	if health_percentage > 0.75:
		return base_speed
	
	var fatigue_threshold = 0.75
	var health_loss = fatigue_threshold - health_percentage
	var speed_reduction = (health_loss / fatigue_threshold) * 0.5
	var fatigued_speed = base_speed * (1.0 - speed_reduction)
	
	return max(1, int(fatigued_speed))

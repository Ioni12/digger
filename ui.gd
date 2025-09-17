# GameUI.gd - Simplified for Option 1 (inventory handled by main game)
extends CanvasLayer
class_name GameUI

# Existing UI elements
@onready var health_bar: ProgressBar = $UIContainer/HealthBar
@onready var stamina_bar: ProgressBar = $UIContainer/StaminaBar

# Player reference
var player: Player

func _ready():
	layer = 10
	
	# Set initial bar properties
	if health_bar:
		health_bar.min_value = 0
		health_bar.max_value = 100
	
	if stamina_bar:
		stamina_bar.min_value = 0
		stamina_bar.max_value = 100

func setup_ui(player_ref: Player):
	player = player_ref

# Existing methods (keeping your original logic)
func update_health(current: int, max_health: int):
	if health_bar:
		health_bar.value = (float(current) / float(max_health)) * 100
		
		# Optional: Change health bar color based on health level
		if current <= max_health * 0.25:  # Critical health (25%)
			health_bar.modulate = Color.RED
		elif current <= max_health * 0.5:  # Low health (50%)
			health_bar.modulate = Color.ORANGE
		else:  # Normal health
			health_bar.modulate = Color.GREEN

func update_stamina(current: int, max_stamina: int):
	if stamina_bar:
		stamina_bar.value = (float(current) / float(max_stamina)) * 100
		
		# Change stamina bar color based on level
		if current <= 10:  # Critical stamina
			stamina_bar.modulate = Color.RED
		elif current <= 25:  # Low stamina warning
			stamina_bar.modulate = Color.ORANGE
		else:  # Normal stamina
			stamina_bar.modulate = Color.CYAN

extends Control
class_name ResourcePopup

@onready var label: Label = $Label
var tween: Tween

func show_text(text: String, color: Color, world_pos: Vector2):
	label.text = text
	label.modulate = color
	global_position = world_pos
	
	# Create animation
	tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations
	
	# Float upward
	tween.tween_property(self, "position:y", position.y - 100, 1.5)
	# Fade in then out
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(1.0)
	
	# Clean up when done
	tween.finished.connect(queue_free)

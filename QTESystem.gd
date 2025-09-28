extends Control
class_name QTESystem

signal qte_completed(success: bool, performance: float)
signal qte_cancelled()

@onready var background: ColorRect = $Background
@onready var keys_container: HBoxContainer = $CenterContainer/VBoxContainer/KeysContainer
@onready var timer_bar: ProgressBar = $CenterContainer/VBoxContainer/TimerBar
@onready var instruction_label: Label = $CenterContainer/VBoxContainer/InstructionLabel
@onready var current_key_label: Label = $CenterContainer/VBoxContainer/CurrentKeyLabel

var qte_sequence: Array[String] = []
var current_index: int = 0
var time_per_key: float = 5.0  # Default 5 seconds per key - much more reasonable
var key_time_remaining: float = 0.0
var success_count: int = 0
var is_active: bool = false

# Timer control settings
var timer_speed_multiplier: float = 1.0  # Adjust this to make timer faster (>1.0) or slower (<1.0)
var pause_timer: bool = false  # Set to true to pause the timer

# Difficulty presets
enum Difficulty { EASY, NORMAL, HARD, CUSTOM }
var current_difficulty: Difficulty = Difficulty.NORMAL
# Visual settings
var key_size: Vector2 = Vector2(60, 60)
var correct_color: Color = Color.GREEN
var current_color: Color = Color.YELLOW
var failed_color: Color = Color.RED

func _ready():
	hide()
	set_process(false)
	
	# Create current key label if it doesn't exist
	if not current_key_label:
		current_key_label = Label.new()
		current_key_label.name = "CurrentKeyLabel"
		$CenterContainer/VBoxContainer.add_child(current_key_label)
		$CenterContainer/VBoxContainer.move_child(current_key_label, 1) # Put it after instruction label

func _process(delta):
	if is_active and not pause_timer:
		key_time_remaining -= delta * timer_speed_multiplier
		update_timer_display()
		
		if key_time_remaining <= 0:
			complete_qte(false)

func _input(event):
	if not is_active or not event.is_pressed():
		return
	
	# Only handle keyboard events
	if event is InputEventKey:
		var pressed_key = get_key_string(event.keycode)
		if pressed_key != "":
			handle_key_press(pressed_key)

func start_sequence(sequence: Array[String], time_limit: float = 5.0):  # Default 5 seconds per key
	qte_sequence = sequence.duplicate()
	
	# Apply difficulty settings if not custom
	if current_difficulty != Difficulty.CUSTOM:
		time_limit = get_difficulty_time_limit()
	
	time_per_key = time_limit
	current_index = 0
	success_count = 0
	key_time_remaining = time_per_key
	is_active = true
	pause_timer = false
	
	setup_ui()
	show()
	set_process(true)

# Helper function to get time limits based on difficulty
func get_difficulty_time_limit() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 8.0  # 8 seconds per key
		Difficulty.NORMAL:
			return 5.0  # 5 seconds per key  
		Difficulty.HARD:
			return 3.0  # 3 seconds per key
		_:
			return 5.0  # Default fallback

# Control functions you can call from outside
func set_difficulty(difficulty: Difficulty):
	current_difficulty = difficulty

func set_timer_speed(speed: float):
	timer_speed_multiplier = speed

func pause_qte_timer():
	pause_timer = true

func resume_qte_timer():
	pause_timer = false

func add_time(extra_seconds: float):
	key_time_remaining += extra_seconds
	if key_time_remaining > time_per_key:
		key_time_remaining = time_per_key

func setup_ui():
	instruction_label.text = "Hit the keys in sequence!"
	timer_bar.value = 100.0
	
	# Clear existing key displays
	for child in keys_container.get_children():
		child.queue_free()
	
	# DEBUG: Print sequence info
	print("Creating buttons for sequence: ", qte_sequence)
	
	# Create key display buttons
	for i in range(qte_sequence.size()):
		var key_button = create_key_display(qte_sequence[i])
		keys_container.add_child(key_button)
		print("Added button: ", key_button.text, " Size: ", key_button.custom_minimum_size)
	
	# DEBUG: Check container contents
	print("Keys container now has ", keys_container.get_child_count(), " children")
	
	update_key_displays()
	update_current_key_prompt()

func create_key_display(key_text: String) -> Button:
	var button = Button.new()
	button.text = key_text
	button.custom_minimum_size = Vector2(80, 80)  # Bigger
	button.disabled = true
	
	# Simpler styling
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color.ALICE_BLUE
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	
	button.add_theme_color_override("font_color", Color.BLACK)
	button.add_theme_color_override("font_color_disabled", Color.BLACK)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("disabled", style_normal)
	
	# Better text visibility
	button.add_theme_color_override("font_color", Color.BLACK)
	button.add_theme_color_override("font_color_disabled", Color.BLACK)
	button.add_theme_font_size_override("font_size", 20)
	
	return button

func update_key_displays():
	var key_buttons = keys_container.get_children()
	
	for i in range(key_buttons.size()):
		if i >= key_buttons.size():
			continue
			
		var button = key_buttons[i] as Button
		var style = button.get_theme_stylebox("disabled") as StyleBoxFlat
		
		if i < current_index:
			# Completed key
			style.bg_color = correct_color
		elif i == current_index:
			# Current key
			style.bg_color = current_color
			# Add pulsing effect (Godot 4 syntax)
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.3)
			tween.tween_property(button, "modulate", Color.WHITE, 0.3)
		else:
			# Pending key
			style.bg_color = Color.ALICE_BLUE
			button.modulate = Color.WHITE

func update_current_key_prompt():
	if current_index < qte_sequence.size():
		var current_key = qte_sequence[current_index]
		current_key_label.text = "PRESS: " + current_key
		current_key_label.add_theme_font_size_override("font_size", 36)
		current_key_label.add_theme_color_override("font_color", current_color)
		current_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Add pulsing effect to the text prompt
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(current_key_label, "modulate", Color(1.5, 1.5, 1.5), 0.4)
		tween.tween_property(current_key_label, "modulate", Color.WHITE, 0.4)
	else:
		current_key_label.text = ""

func update_timer_display():
	var progress = (key_time_remaining / time_per_key) * 100.0
	timer_bar.value = progress
	
	# Change timer color based on remaining time
	if progress > 60:
		timer_bar.modulate = Color.WHITE
	elif progress > 30:
		timer_bar.modulate = Color.YELLOW
	else:
		timer_bar.modulate = Color.RED

func handle_key_press(pressed_key: String):
	if current_index >= qte_sequence.size():
		return
	
	var expected_key = qte_sequence[current_index]
	
	if pressed_key == expected_key:
		# Correct key!
		success_count += 1
		current_index += 1
		key_time_remaining = time_per_key
		
		update_key_displays()
		update_current_key_prompt()
		
		# Brief success feedback
		current_key_label.text = "GOOD!"
		current_key_label.modulate = correct_color
		await get_tree().create_timer(0.2).timeout
		
		# Check if sequence is complete
		if current_index >= qte_sequence.size():
			complete_qte(true)
		else:
			update_current_key_prompt()
	else:
		# Wrong key - fail immediately
		show_wrong_key_feedback(pressed_key)
		complete_qte(false)

func show_wrong_key_feedback(wrong_key: String):
	instruction_label.text = "Wrong key! Expected: " + qte_sequence[current_index] + ", Got: " + wrong_key
	instruction_label.modulate = failed_color
	
	current_key_label.text = "WRONG!"
	current_key_label.modulate = failed_color
	
	# Flash the current key red
	var key_buttons = keys_container.get_children()
	if current_index < key_buttons.size():
		var button = key_buttons[current_index]
		var style = button.get_theme_stylebox("disabled") as StyleBoxFlat
		style.bg_color = failed_color

func complete_qte(success: bool):
	is_active = false
	set_process(false)
	
	var performance = float(success_count) / float(qte_sequence.size())
	
	if success:
		instruction_label.text = "Perfect!"
		instruction_label.modulate = correct_color
		current_key_label.text = "COMPLETE!"
		current_key_label.modulate = correct_color
	
	# Brief pause before emitting signal
	await get_tree().create_timer(0.5).timeout
	
	qte_completed.emit(success, performance)
	hide()

func cancel_qte():
	is_active = false
	set_process(false)
	qte_cancelled.emit()
	hide()

func get_key_string(keycode: int) -> String:
	match keycode:
		KEY_Z: return "Z"
		KEY_X: return "X" 
		KEY_C: return "C"
		KEY_V: return "V"
		_: return ""

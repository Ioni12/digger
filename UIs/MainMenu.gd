extends Control

# Path to your main game scene
const GAME_SCENE_PATH = "res://main.tscn"  # Change this to your actual game scene path

# UI References
@onready var start_button: Button = $MarginContainer/VBoxContainer/Start
@onready var quit_button: Button = $MarginContainer/VBoxContainer/Quit
@onready var game_title: Label = $MarginContainer/VBoxContainer/Label
@onready var background: ColorRect = $ColorRect

func _ready() -> void:
	setup_ui()
	connect_signals()
	setup_background()

func setup_ui() -> void:
	# Set button text
	start_button.text = "Start Game"
	quit_button.text = "Quit"
	
	# Set title text (change this to your game's name)
	game_title.text = "RPG Adventure"
	
	# Style the title
	if game_title:
		game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# You can add a custom font here if you have one
		# game_title.add_theme_font_size_override("font_size", 48)

func connect_signals() -> void:
	# Connect button signals
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func setup_background() -> void:
	# Set a simple background color
	if background:
		background.color = Color(0.1, 0.1, 0.2)  # Dark blue background
		background.anchors_preset = Control.PRESET_FULL_RECT

func _on_start_pressed() -> void:
	print("Starting game...")
	
	# Add a small delay for better feel (optional)
	start_button.disabled = true
	await get_tree().create_timer(0.2).timeout
	
	# Change to the main game scene
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		print("Error loading game scene: ", error)
		start_button.disabled = false

func _on_quit_pressed() -> void:
	print("Quitting game...")
	
	# Add a small delay for better feel (optional)
	quit_button.disabled = true
	await get_tree().create_timer(0.1).timeout
	
	# Quit the application
	get_tree().quit()

# Optional: Handle escape key to quit
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key by default
		_on_quit_pressed()

extends Control

# Scene paths
const MAIN_MENU_PATH = "res://MainMenu.tscn"
const GAME_SCENE_PATH = "res://main.tscn"  # Change to your game scene path

# UI References
@onready var game_over_title: Label = $MarginContainer/VBoxContainer/GameOverTitle
@onready var restart_button: Button = $MarginContainer/VBoxContainer/Start
@onready var main_menu_button: Button = $MarginContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/Quit
@onready var background: ColorRect = $ColorRect

func _ready() -> void:
	setup_ui()
	connect_signals()
	setup_background()
	
	# Unpause the game in case it was paused
	get_tree().paused = false

func setup_ui() -> void:
	# Set button and label text
	game_over_title.text = "GAME OVER"
	restart_button.text = "Restart"
	main_menu_button.text = "Main Menu"
	quit_button.text = "Quit"
	
	# Style the title
	if game_over_title:
		game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# You can customize font size and color here
		# game_over_title.add_theme_font_size_override("font_size", 48)
		# game_over_title.add_theme_color_override("font_color", Color.RED)

func connect_signals() -> void:
	# Connect button signals
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func setup_background() -> void:
	# Set a dark background with red tint for game over feeling
	if background:
		background.color = Color(0.2, 0.05, 0.05)  # Dark red background
		background.anchors_preset = Control.PRESET_FULL_RECT

func _on_restart_pressed() -> void:
	print("Restarting game...")
	
	# Disable button to prevent multiple clicks
	restart_button.disabled = true
	await get_tree().create_timer(0.2).timeout
	
	# Restart the game scene
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		print("Error loading game scene: ", error)
		restart_button.disabled = false

func _on_main_menu_pressed() -> void:
	print("Returning to main menu...")
	
	# Disable button to prevent multiple clicks
	main_menu_button.disabled = true
	await get_tree().create_timer(0.2).timeout
	
	# Go back to main menu
	var error = get_tree().change_scene_to_file(MAIN_MENU_PATH)
	if error != OK:
		print("Error loading main menu: ", error)
		main_menu_button.disabled = false

func _on_quit_pressed() -> void:
	print("Quitting game...")
	
	# Disable button and quit
	quit_button.disabled = true
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

# Optional: Handle input
func _input(event: InputEvent) -> void:
	# Press R to restart quickly
	if event.is_action_pressed("ui_accept"):  # Enter/Space
		_on_restart_pressed()
	elif event.is_action_pressed("ui_cancel"):  # Escape
		_on_main_menu_pressed()

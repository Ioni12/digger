extends Control

signal resume_pressed
signal quit_pressed

@onready var resume_button: Button = $CenterContainer/VBoxContainer/Resume
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Quit

func _ready() -> void:
	# Make sure this node processes when paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Initially hide the pause menu
	visible = false
	
	# Connect button signals
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _input(event) -> void:
	# Allow ESC key to close pause menu
	if visible and event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

func open_pause_menu() -> void:
	visible = true
	# Focus the resume button so player can navigate with keyboard
	if resume_button:
		resume_button.grab_focus()

func close_pause_menu() -> void:
	visible = false

func _on_resume_pressed() -> void:
	resume_pressed.emit()

func _on_quit_pressed() -> void:
	quit_pressed.emit()

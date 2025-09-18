extends Node2D

var environment: GameEnviroment
var player: Player
var camera: Camera2D
var ui: GameUI
var inventory_scene: PackedScene
var inventory_instance: InventoryGUI

func _ready() -> void:
	setup_game()
	inventory_scene = preload("res://inventory.tscn")

func _process(delta: float) -> void:
	if EncounterManager and EncounterManager.is_in_battle:
		return
	
	if player and not player.is_alive():
		game_over()
		return 
		
	if ui.health_bar.value < 1:
		player.health_changed.emit(player.current_hp, player.max_hp)
		
	if ui.stamina_bar.value < 1:
		player.stamina_changed.emit(player.stamina, player.max_stamina)
	
	if player and camera:
		var target_pos = player.position + Vector2(environment.SIZE/2, environment.SIZE/2)
		
		var viewport_size = get_viewport().get_visible_rect().size
		var half_viewport = viewport_size / 2
		
		target_pos.x = max(target_pos.x, half_viewport.x)
		target_pos.y = max(target_pos.y, half_viewport.y)
		
		var env_width = environment.WIDTH * environment.SIZE
		var env_height = environment.HEIGHT * environment.SIZE
		target_pos.x = min(target_pos.x, env_width - half_viewport.x)
		target_pos.y = min(target_pos.y, env_height - half_viewport.y)
		
		camera.position = camera.position.lerp(target_pos, 0.1)

func _input(event):
	if event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and event.keycode == KEY_I):
		toggle_inventory()
		get_viewport().set_input_as_handled()

func open_inventory():
	if not inventory_instance:
		inventory_instance = inventory_scene.instantiate()
		ui.add_child(inventory_instance)
		inventory_instance.setup(player.inventory, player)
		inventory_instance.inventory_closed.connect(close_inventory)  # This is fine - signal connection
	
	inventory_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	inventory_instance.open_inventory()
	get_tree().paused = true

func close_inventory():
	# Don't call inventory_instance.close_inventory() here!
	# This function should only be called BY the inventory via signal
	if inventory_instance:
		get_tree().paused = false

func toggle_inventory():
	if inventory_instance and inventory_instance.visible:
		# Let InventoryGUI close itself
		inventory_instance.close_inventory()
	else:
		open_inventory()

func setup_game():
	# Create environment first
	environment = GameEnviroment.new()
	environment.position = Vector2.ZERO
	add_child(environment)
	
	# Create player and give it the environment reference
	player = Player.new()
	player.environment = environment
	add_child(player)
	
	# IMPORTANT: Set the player reference in EncounterManager
	EncounterManager.set_player_reference(player)
	
	var ui_scene = load("res://ui.tscn")
	ui = ui_scene.instantiate()
	add_child(ui)
	
	# Setup UI with player reference
	ui.setup_ui(player)
	
	setup_camera()
	connect_all_signals()

func setup_camera():
	camera = Camera2D.new()
	add_child(camera)
	
	camera.enabled = true
	
	var env_width = environment.WIDTH * environment.SIZE
	var env_height = environment.HEIGHT * environment.SIZE
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = max(env_width, viewport_size.x)
	camera.limit_bottom = max(env_height, viewport_size.y)

func connect_all_signals():
	# Connect player signals to UI
	player.health_changed.connect(ui.update_health)
	player.stamina_changed.connect(ui.update_stamina)
	player.level_up.connect(on_player_level_up)

func on_player_level_up(new_level: int):
	print("Player reached level ", new_level, "!")

func game_over():
	print("Game Over - Player has died!")
	
	# Close inventory if open
	if inventory_instance and inventory_instance.visible:
		close_inventory()
	
	get_tree().paused = true
	await get_tree().create_timer(2.0).timeout
	get_tree().paused = false
	
	var error = get_tree().change_scene_to_file("res://GameOver.tscn")
	if error != OK:
		print("Error loading Game Over scene: ", error)
		get_tree().reload_current_scene()

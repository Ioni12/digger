extends Node2D

var environment: GameEnviroment
var player: Player
var camera: Camera2D
var ui: GameUI
var inventory_scene: PackedScene
var dialogue_ui_scene: PackedScene
var dialogue_ui_instance: DialogueUI
var inventory_instance: InventoryGUI
var pause_menu_scene: PackedScene
var pause_menu_instance: Control
var map_scene: PackedScene
var map_instance: Control
var event_system: EventSystem
var is_paused: bool = false

func _ready() -> void:
	setup_game()
	inventory_scene = preload("res://inventory.tscn")
	pause_menu_scene = preload("res://PauseMenu.tscn")
	if ResourceLoader.exists("res://DialogueUI.tscn"):
		dialogue_ui_scene = preload("res://DialogueUI.tscn")
		print("DialogueUI.tscn loaded successfully")
	else:
		print("DialogueUI.tscn not found - dialogue system disabled")
	setup_map()

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
	# Handle pause menu first
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		# If dialogue is open, close it first
		if dialogue_ui_instance and dialogue_ui_instance.is_dialogue_active:
			dialogue_ui_instance.close_dialogue()
			get_viewport().set_input_as_handled()
			return
		
		if not EncounterManager.is_in_battle:  # Don't allow pausing during battle
			toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return
	
	# Handle inventory (only if not paused and no dialogue active)
	if not is_paused and not (dialogue_ui_instance and dialogue_ui_instance.is_dialogue_active):
		if (event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and event.keycode == KEY_I)):
			toggle_inventory()
			get_viewport().set_input_as_handled()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		if not is_paused and not (dialogue_ui_instance and dialogue_ui_instance.is_dialogue_active):
			toggle_map()
			get_viewport().set_input_as_handled()

func setup_map():
	map_scene = preload("res://Map.tscn")  # Adjust path if needed
	map_instance = map_scene.instantiate()
	ui.add_child(map_instance)  # Add to UI layer
	map_instance.setup(environment, player)

func toggle_pause_menu():
	# Don't open pause menu if dialogue is active
	if dialogue_ui_instance and dialogue_ui_instance.is_dialogue_active:
		return
		
	if is_paused:
		close_pause_menu()
	else:
		open_pause_menu()

func open_pause_menu():
	# Don't open if inventory is already open
	if inventory_instance and inventory_instance.visible:
		return
		
	if not pause_menu_instance:
		pause_menu_instance = pause_menu_scene.instantiate()
		ui.add_child(pause_menu_instance)
		# Connect signals from pause menu
		pause_menu_instance.resume_pressed.connect(close_pause_menu)
		pause_menu_instance.quit_pressed.connect(quit_game)
	
	pause_menu_instance.open_pause_menu()
	get_tree().paused = true
	is_paused = true

func close_pause_menu():
	if pause_menu_instance:
		pause_menu_instance.close_pause_menu()
		get_tree().paused = false
		is_paused = false

func quit_game():
	get_tree().quit()

func open_inventory():
	if not inventory_instance:
		inventory_instance = inventory_scene.instantiate()
		ui.add_child(inventory_instance)
		inventory_instance.setup(player.inventory, player)
		inventory_instance.inventory_closed.connect(close_inventory)
		inventory_instance.refresh_display()  
	
	inventory_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	inventory_instance.open_inventory()
	get_tree().paused = true

func close_inventory():
	# Don't call inventory_instance.close_inventory() here!
	# This function should only be called BY the inventory via signal
	if inventory_instance:
		get_tree().paused = false

func toggle_inventory():
	# Don't open inventory if game is paused
	if is_paused:
		return
		
	if inventory_instance and inventory_instance.visible:
		# Let InventoryGUI close itself
		inventory_instance.close_inventory()
	else:
		open_inventory()

# Game Setup Functions
func setup_game():
	# Create environment first
	environment = GameEnviroment.new()
	environment.position = Vector2.ZERO
	add_child(environment)
	
	# Create player and give it the environment reference
	player = Player.new()
	player.environment = environment
	player.position = Vector2((GameEnviroment.WIDTH/2) * GameEnviroment.SIZE, 0 * GameEnviroment.SIZE)
	add_child(player)
	
	environment.player_reference = player
	
	# IMPORTANT: Set the player reference in EncounterManager
	EncounterManager.set_player_reference(player)
	
	var ui_scene = load("res://ui.tscn")
	ui = ui_scene.instantiate()
	add_child(ui)
	
	# Setup UI with player reference
	ui.setup_ui(player)
	
	setup_camera()
	connect_all_signals()
	setup_dialogue_ui()
	
	# Initialize event system AFTER everything else is set up
	initialize_event_system()

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

func setup_dialogue_ui():
	# Load the scene if not already loaded
	if not dialogue_ui_scene:
		if ResourceLoader.exists("res://DialogueUI.tscn"):
			dialogue_ui_scene = preload("res://DialogueUI.tscn")
		else:
			print("ERROR: DialogueUI.tscn not found")
			return
	
	if not dialogue_ui_instance:
		print("DEBUG: Creating dialogue UI instance...")
		dialogue_ui_instance = dialogue_ui_scene.instantiate()
		
		if not dialogue_ui_instance:
			print("ERROR: Failed to instantiate DialogueUI scene")
			return
			
		ui.add_child(dialogue_ui_instance)
		dialogue_ui_instance.add_to_group("dialogue_ui")
		
		# Connect dialogue signals
		if dialogue_ui_instance.has_signal("dialogue_closed"):
			dialogue_ui_instance.dialogue_closed.connect(_on_dialogue_closed)
		if dialogue_ui_instance.has_signal("trade_requested"):
			dialogue_ui_instance.trade_requested.connect(_on_trade_requested)
		
		print("DEBUG: Dialogue UI setup complete")

func connect_all_signals():
	# Connect player signals to UI
	player.health_changed.connect(ui.update_health)
	player.stamina_changed.connect(ui.update_stamina)
	player.level_up.connect(on_player_level_up)
	
	# Connect NPC interaction signals with updated signature
	player.npc_interaction.connect(_on_npc_interaction)
	print("DEBUG: Connected npc_interaction signal")

func on_player_level_up(new_level: int):
	print("Player reached level ", new_level, "!")

func game_over():
	# Close inventory if open
	if inventory_instance and inventory_instance.visible:
		close_inventory()
	
	# Close pause menu if open
	if pause_menu_instance and pause_menu_instance.visible:
		close_pause_menu()
	
	get_tree().paused = true
	await get_tree().create_timer(2.0).timeout
	get_tree().paused = false
	
	var error = get_tree().change_scene_to_file("res://GameOver.tscn")
	if error != OK:
		print("Error loading Game Over scene: ", error)
		get_tree().reload_current_scene()

func _on_dialogue_closed():
	print("DEBUG: Main game received dialogue_closed signal")
	if player and player.interaction:
		print("DEBUG: Calling player.interaction.end_dialogue()")
		player.interaction.end_dialogue()
	else:
		print("DEBUG: Player or interaction is null!")

func _on_trade_requested(npc: WorldNPC):
	"""Called when player wants to trade with an NPC"""
	print("Trade requested with: ", npc.npc_name)
	
	# You can implement trading here, for example:
	# 1. Open inventory in trade mode
	# 2. Create a dedicated trading UI
	# 3. Show available items from NPC
	
	# Simple implementation: just show NPC inventory for now
	if npc.inventory.size() > 0:
		print("Available items from %s:" % npc.npc_name)
		for item in npc.inventory:
			print("  - %s" % item)
	else:
		print("This trader has no items available.")

func _on_npc_interaction(npc: WorldNPC, message: String, interaction_data: Dictionary):
	"""Handle NPC interaction events - now receives NPC reference directly"""
	print("DEBUG: _on_npc_interaction called")
	print("DEBUG: NPC: ", npc.npc_name, " Message: ", message)
	print("DEBUG: dialogue_ui_instance exists: ", dialogue_ui_instance != null)
	print("DEBUG: dialogue_ui_instance visible: ", dialogue_ui_instance.visible if dialogue_ui_instance else "N/A")
	
	if dialogue_ui_instance:
		print("DEBUG: Calling show_dialogue with NPC reference...")
		dialogue_ui_instance.show_dialogue(npc, interaction_data)
		print("DEBUG: show_dialogue called - UI should be visible now")
	else:
		print("ERROR: dialogue_ui_instance is null!")
		# Fallback: show a simple dialog
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "[%s]: %s" % [npc.npc_name, message]
		add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(dialog.queue_free)

func initialize_event_system():
	event_system = EventSystem.new()
	add_child(event_system)
	event_system.initialize(environment)
	
	# Trigger the initial NPC spawn event
	event_system.trigger_initial_npc_spawn()

func toggle_map():
	if map_instance.visible:
		map_instance.close_map()
	else:
		map_instance.open_map()

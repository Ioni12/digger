extends Control
class_name BattleSystem

enum BattleState {
	INIT,
	PLAYER_TURN,
	ENEMY_TURN,
	BATTLE_WON,
	BATTLE_LOST,
	ANIMATING,
	DIGGING,
	IDLE,
	MOVING,
	QTE_CHOICE,
	QTE_ACTIVE
}

var current_state: BattleState = BattleState.INIT
var player_character: Character  # Battle-specific character wrapper
var enemy: Character
var battle_log: Array[String] = []
var enemy_exp_reward: int = 0
var qte_choice_active = false
var qte_choice_timer = 3.0  # 3 seconds to decide
var qte_choice_time_remaining = 0.0

# Run mechanics
var run_attempt_count = 0
var base_run_success_chance = 0.4  # 40% base chance
var run_difficulty_increase = 0.15  # Each attempt reduces chance by 15%

# QTE System
var qte_system: QTESystem

# Reference to the actual player object
var actual_player: Player

var player_sprite: Sprite2D
var enemy_sprite: Sprite2D


@onready var battle_log_text: RichTextLabel = %BattleLog
@onready var action_panel: VBoxContainer = $BattleUI/Actions/ActionPanel
@onready var player_name_label: Label = %PlayerName
@onready var player_hp_bar: ProgressBar = %HPBar
@onready var player_hp_label: Label = %HPLabel
@onready var enemy_name_label: Label = %EnemyName
@onready var enemy_hp_bar: ProgressBar = %EnemyHPBar
@onready var enemy_hp_label: Label = %EnemyHPLabel
@onready var attack_button: Button = $BattleUI/Actions/ActionPanel/ActionButtons/Attack
@onready var defend_button: Button = $BattleUI/Actions/ActionPanel/ActionButtons/Defend
@onready var run: Button = $BattleUI/Actions/ActionPanel/ActionButtons/Run
@onready var restart_button: Button = %Restart
@onready var actions: PanelContainer = $BattleUI/Actions
@onready var qte_choice_label: RichTextLabel = $BattleUI/ChoiceLabel
@onready var qte_choice_timer_bar: ProgressBar = $BattleUI/TimerBar
@onready var items_panel: PanelContainer = $BattleUI/ItemsPanel
@onready var items_list: ItemList = $BattleUI/ItemsPanel/MarginContainer/VBoxContainer/ItemsList
@onready var use_item_button: Button = $BattleUI/ItemsPanel/MarginContainer/VBoxContainer/HBoxContainer/UseButton
@onready var back_button: Button = $BattleUI/ItemsPanel/MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var items_button: Button = $BattleUI/Actions/ActionPanel/ActionButtons/Items
@onready var battle_music: AudioStreamPlayer = AudioStreamPlayer.new()

var available_actions = [
	{"name": "Attack", "type": "attack", "cost": 0},
	{"name": "Magic Blast", "type": "magic", "cost": 15},
	{"name": "Heal", "type": "heal", "cost": 10},
	{"name": "Defend", "type": "defend", "cost": 0}
]

func _ready():
	initialize_battle()
	setup_ui()
	setup_run_button()
	setup_qte_system()
	setup_battle_music()
	start_battle()

func _process(delta):
	if qte_choice_active:
		handle_qte_choice_timer(delta)

func _input(event):
	if event.is_pressed() and qte_choice_active and event is InputEventKey:
		handle_qte_choice_input(event)

func handle_qte_choice_timer(delta):
	qte_choice_time_remaining -= delta
	qte_choice_timer_bar.value = (qte_choice_time_remaining / qte_choice_timer) * 100
	
	# Auto-skip if time runs out
	if qte_choice_time_remaining <= 0:
		end_qte_choice("skip")

func handle_qte_choice_input(event):
	if event.keycode == KEY_A:
		end_qte_choice("attempt")
	elif event.keycode == KEY_D:
		end_qte_choice("skip")
	
func initialize_battle():
	print("Initializing battle..." + "\n")
	run_attempt_count = 0

	actual_player = EncounterManager.player_reference
	
	if not actual_player:
		print("ERROR: No player reference!")
		return
	
	# Create a battle-specific Character wrapper from the player stats
	var player_stats = actual_player.get_stats_dictionary()
	player_character = Character.new(
		player_stats.get("name"),
		player_stats.get("max_hp"),
		player_stats.get("base_attack"),
		player_stats.get("base_defense"),
		player_stats.get("base_speed")
	)
	# Set current HP
	player_character.current_hp = player_stats.get("current_hp")
	
	var enemy_data = EncounterManager.get_current_enemy()
	
	enemy = Character.new(
		enemy_data.get("name", "Unknown Enemy"),
		enemy_data.get("hp", 50),
		enemy_data.get("attack", 15),
		enemy_data.get("defense", 10),
		enemy_data.get("speed", 12)
	)
	enemy_exp_reward = enemy_data.get("exp", 30)
	
	current_state = BattleState.INIT
	battle_log.clear()
	
	print("Battle initialized successfully!")
	print("Player: ", player_character.char_name, " HP:", player_character.current_hp, "/", player_character.max_hp)
	print("Enemy: ", enemy.char_name, " HP:", enemy.current_hp, "/", enemy.max_hp, "\n")
	
func setup_ui():
	setup_attack_button()
	setup_defend_button()
	setup_items_button()
	setup_restart_button()
	update_ui()
	
	var bg_sprite = Sprite2D.new()
	bg_sprite.texture = load("res://backrounds/Background Complete.png")
	bg_sprite.z_index = -1
	
	bg_sprite.centered = true
	bg_sprite.position = Vector2(640, 360)  # Center of 1280x720

	# Scale to fit 1280x720
	var texture_size = bg_sprite.texture.get_size()
	bg_sprite.scale = Vector2(1280.0 / texture_size.x, 720.0 / texture_size.y)
	
	add_child(bg_sprite)
	move_child(bg_sprite, 0)
	
	player_sprite = Sprite2D.new()
	player_sprite.texture = load("res://goku.png")
	player_sprite.z_index = 1
	player_sprite.centered = true
	player_sprite.position = Vector2(200, 350)
	player_sprite.scale = Vector2(30.0 / texture_size.x, 30.0 / texture_size.y)
	add_child(player_sprite)
	
	enemy_sprite = Sprite2D.new()
	enemy_sprite.texture = load("res://cell1.webp")
	enemy_sprite.z_index = 1
	enemy_sprite.centered = true
	enemy_sprite.position = Vector2(1050, 350)
	enemy_sprite.scale = Vector2(150.0 / texture_size.x, 150.0 / texture_size.y)
	add_child(enemy_sprite)
	
	# Hide QTE UI initially
	qte_choice_label.visible = false
	qte_choice_timer_bar.visible = false

func setup_qte_system():
	qte_system = preload("res://QTESystem.tscn").instantiate()
	add_child(qte_system)
	qte_system.qte_completed.connect(_on_qte_completed)
	qte_system.qte_cancelled.connect(_on_qte_cancelled)

func start_battle():
	battle_music.play()
	add_log("Battle begins!")
	add_log(player_character.char_name + " (Speed: " + str(player_character.base_speed) + ") vs " + enemy.char_name + " (Speed: " + str(enemy.base_speed) + ")")
	
	determine_next_turn()

func setup_attack_button():
	if attack_button:
		attack_button.text = "Attack"
		attack_button.pressed.connect(_on_attack_pressed)

func setup_defend_button():
	if defend_button:
		defend_button.text = "Defend"
		defend_button.pressed.connect(_on_defend_pressed)

func setup_restart_button():
	if restart_button:
		restart_button.pressed.connect(_ready)
	
func _on_attack_pressed():
	if current_state != BattleState.PLAYER_TURN:
		return
	
	current_state = BattleState.ANIMATING
	process_player_action(available_actions[0])
	
func _on_defend_pressed():
	if current_state != BattleState.PLAYER_TURN:
		return
	
	current_state = BattleState.ANIMATING
	process_player_action(available_actions[3])

func update_action_buttons():
	if attack_button:
		attack_button.disabled = current_state != BattleState.PLAYER_TURN
	if defend_button:
		defend_button.disabled = current_state != BattleState.PLAYER_TURN
	if items_button:
		items_button.disabled = current_state != BattleState.PLAYER_TURN
	if run:
		run.disabled = current_state != BattleState.PLAYER_TURN

func process_player_action(action: Dictionary):
	match action.type:
		"attack":
			player_attack()
		"defend":
			player_defend()
	
	if not qte_choice_active and current_state != BattleState.QTE_ACTIVE:
		complete_player_turn()

func complete_player_turn():
	player_character.act()
	
	# Sync damage back to actual player
	sync_player_health()
	update_ui()
	
	if not enemy.is_alive():
		end_battle(true)
		return
	
	await get_tree().create_timer(1.0).timeout
	
	determine_next_turn()

func player_attack():
	# 80% chance for QTE (changed from 20% to make it more common for testing)
	if randf() < 0.8:
		start_attack_qte()
	else:
		execute_normal_attack()

func start_attack_qte():
	current_state = BattleState.QTE_CHOICE
	qte_choice_active = true
	qte_choice_time_remaining = qte_choice_timer
	
	qte_choice_label.text = "[center]QTE Opportunity!\nPress [color=green]A[/color] to attempt bonus damage\nPress [color=red]D[/color] to skip[/center]"
	qte_choice_label.visible = true
	qte_choice_timer_bar.visible = true
	qte_choice_timer_bar.value = 100
	
	# Disable action buttons during QTE choice
	actions.visible = false

func end_qte_choice(choice: String):
	qte_choice_active = false
	qte_choice_label.visible = false
	qte_choice_timer_bar.visible = false
	
	match choice:
		"attempt":
			start_actual_qte()
		"skip":
			current_state = BattleState.ANIMATING
			execute_normal_attack()
			complete_player_turn()

func start_actual_qte():
	current_state = BattleState.QTE_ACTIVE
	
	# Generate random sequence
	var sequence_length = randi_range(3, 5)
	var sequence: Array[String] = []
	var available_keys = ["Z", "X", "C", "V"]
	
	for i in sequence_length:
		sequence.append(available_keys[randi() % available_keys.size()])
	
	# Start the QTE system
	qte_system.start_sequence(sequence, 1.0)

func _on_qte_completed(success: bool, performance: float):
	current_state = BattleState.ANIMATING
	
	if success:
		var damage_multiplier = 1.0 + (performance * 0.8)  # Up to 1.8x damage
		var bonus_damage = int(calculate_damage(player_character.attack, enemy.get_current_defense()) * damage_multiplier)
		enemy.take_damage(bonus_damage)
		add_log(player_character.char_name + " performs a perfect combo for " + str(bonus_damage) + " damage!")
	else:
		add_log("QTE failed! Normal attack.")
		execute_normal_attack()
	
	complete_player_turn()

func _on_qte_cancelled():
	current_state = BattleState.ANIMATING
	execute_normal_attack()
	complete_player_turn()

func execute_normal_attack():
	var damage = calculate_damage(player_character.attack, enemy.get_current_defense())
	enemy.take_damage(damage)
	add_log(player_character.char_name + " attacks for " + str(damage) + " damage!")

func player_defend():
	player_character.defend()
	add_log(player_character.char_name + " takes a defensive stance! (Defense: " + str(player_character.get_current_defense()) + ")")

func process_enemy_turn():
	if current_state != BattleState.ENEMY_TURN:
		return 
	
	current_state = BattleState.ANIMATING
	
	var actions = ["attack", "attack"]
	var chosen_action = actions[randi() % actions.size()]
	
	match chosen_action:
		"attack":
			enemy_attack()
	
	enemy.act()
	
	# Sync damage back to actual player
	sync_player_health()
	update_ui()
	
	if not player_character.is_alive():
		end_battle(false)
		return
	
	await get_tree().create_timer(1.0).timeout
	
	determine_next_turn()

func enemy_attack():
	var damage = calculate_damage(enemy.attack, player_character.get_current_defense())
	player_character.take_damage(damage)
	add_log(enemy.char_name + " attacks for " + str(damage) + " damage!")

func sync_player_health():
	"""Sync health changes back to the actual player object"""
	if actual_player and actual_player.stats:
		actual_player.stats.data.current_hp = player_character.current_hp
		actual_player.health_changed.emit(actual_player.current_hp, actual_player.max_hp)

func end_battle(player_won: bool):
	# Final health sync
	sync_player_health()
	battle_music.stop()
	
	if player_won:
		current_state = BattleState.BATTLE_WON
		add_log("Victory! " + enemy.char_name + " has been defeated!")
		add_log("Gained " + str(enemy_exp_reward) + " EXP!\n")
	
		# Give EXP directly to the actual player
		
		
		await get_tree().create_timer(1.0).timeout
		EncounterManager.battle_ended.emit(true, enemy_exp_reward)
		close_battle_popup()
	else:
		current_state = BattleState.BATTLE_LOST
		add_log("Defeat! " + player_character.char_name + " has fallen...\n")
		
		await get_tree().create_timer(1.0).timeout
		EncounterManager.battle_ended.emit(false, 0)
		close_battle_popup()
	
	action_panel.visible = false

func close_battle_popup():
	var current_node = self
	while current_node != null:
		if current_node is PopupPanel:
			current_node.hide()
			current_node.queue_free()
			break
		current_node = current_node.get_parent()
	
	get_tree().paused = false

func update_ui():
	if player_name_label and actual_player:
		player_name_label.text = actual_player.player_name + " (Lv." + str(actual_player.level) + ")"
	
	if player_hp_bar and player_hp_label:
		var hp_ratio = float(player_character.current_hp) / float(player_character.max_hp)
		player_hp_bar.value = hp_ratio * 100
		player_hp_label.text = str(player_character.current_hp) + "/" + str(player_character.max_hp)
	
	if enemy_name_label:
		enemy_name_label.text = enemy.char_name
		
	if enemy_hp_bar and enemy_hp_label:
		var hp_ratio = float(enemy.current_hp) / float(enemy.max_hp)
		enemy_hp_bar.value = hp_ratio * 100
		enemy_hp_label.text = str(enemy.current_hp) + "/" + str(enemy.max_hp)
	
	update_action_buttons()
	
	print("Current state: ", BattleState.keys()[current_state], "\n")
	if player_character and enemy:
		print("Player speed: ", player_character.current_speed, " | Enemy speed: ", enemy.current_speed, "\n")

func get_next_actor() -> Character:
	if player_character.current_speed >= enemy.current_speed:
		return player_character
	else:
		return enemy

func determine_next_turn():
	if not player_character.is_alive() or not enemy.is_alive():
		return
	
	player_character.advance_time()
	enemy.advance_time()
	
	var next_actor = get_next_actor()
	
	if next_actor == player_character:
		actions.visible = true
		var effective_speed = player_character.get_speed_with_fatigue()
		var fatigue_text = ""
		if effective_speed < player_character.base_speed:
			fatigue_text = " (Fatigued: " + str(effective_speed) + "/" + str(player_character.base_speed) + ")"
		add_log(player_character.char_name + "'s turn! (Speed: " + str(player_character.current_speed) + ")" + fatigue_text)
		current_state = BattleState.PLAYER_TURN
		update_ui()
	else:
		actions.visible = false
		var effective_speed = enemy.get_speed_with_fatigue()
		var fatigue_text = ""
		if effective_speed < enemy.base_speed:
			fatigue_text = " (Fatigued: " + str(effective_speed) + "/" + str(enemy.base_speed) + ")"
		add_log(enemy.char_name + "'s turn! (Speed: " + str(enemy.current_speed) + ")" + fatigue_text)
		current_state = BattleState.ENEMY_TURN
		await get_tree().create_timer(1.0).timeout
		process_enemy_turn()

func add_log(message: String):
	battle_log.append(message)
	update_battle_log()
	print(message)

func update_battle_log():
	if battle_log_text:
		var log_text = ""
		var start_index = max(0, battle_log.size() - 4)
		
		for i in range(start_index, battle_log.size()):
			log_text += battle_log[i] + "\n"
		
		battle_log_text.text = log_text

func calculate_damage(attack_power: int, defense: int) -> int:
	var base_damage = attack_power - (defense / 2)
	var damage = max(1, base_damage + randi() % 8)
	return damage

func setup_battle_music():
	battle_music.bus = "Master"  # Optional: set audio bus
	battle_music.volume_db = 0
	add_child(battle_music)
	
	var music = load("res://battle-music-1-looping-theme-225558.mp3")
	if music:
		battle_music.stream = music
	else:
		print("ERROR: Battle music file not found!")

func setup_items_button():
	if items_list:
		items_list.item_selected.connect(_on_item_selected)
	
	if use_item_button:
		use_item_button.text = "Use"
		use_item_button.pressed.connect(_on_use_item_confirmed)
	
	if back_button:
		back_button.text = "Back"
		back_button.pressed.connect(_on_items_back)
	
	if items_button:
		items_button.text = "Items"
		items_button.pressed.connect(_on_items_pressed)
	
	if items_panel:
		items_panel.visible = false

# NEW: Items Button Pressed
func _on_items_pressed():
	if current_state != BattleState.PLAYER_TURN:
		return
	
	current_state = BattleState.ANIMATING
	show_items_menu()

# NEW: Show Items Menu
func show_items_menu():
	print("=== SHOWING ITEMS MENU ===")
	print("actions visible before: ", actions.visible)
	print("items_panel visible before: ", items_panel.visible)
	print("items_list item_count: ", items_list.item_count)
	
	actions.visible = false
	items_panel.visible = true
	
	print("actions visible after: ", actions.visible)
	print("items_panel visible after: ", items_panel.visible)
	
	refresh_items_display()
	
	print("items_list item_count after refresh: ", items_list.item_count)
	print("items_list visible: ", items_list.visible)
	print("items_list size: ", items_list.size)
	
	current_state = BattleState.PLAYER_TURN

# NEW: Refresh Items Display
# NEW: Refresh Items Display - Simple Debug
func refresh_items_display():
	items_list.clear()
	
	print("\n=== REFRESH ITEMS DISPLAY ===")
	print("actual_player: ", actual_player)
	print("actual_player is null: ", actual_player == null)
	
	if actual_player == null:
		print("ERROR: actual_player is null!")
		return
	
	print("actual_player.inventory: ", actual_player.inventory)
	
	var player_inventory = actual_player.inventory
	
	if player_inventory == null:
		print("ERROR: player_inventory is null!")
		return
	
	print("inventory.items: ", player_inventory.items)
	print("items array size: ", player_inventory.items.size())
	
	# List all items regardless of type
	for i in range(player_inventory.items.size()):
		var item = player_inventory.items[i]
		print("\nItem %d: %s" % [i, item.name])
		print("  Type: %s (index %d)" % [Item.ItemType.keys()[item.item_type], item.item_type])
		print("  Can consume: %s" % item.can_be_consumed())
		print("  Quantity: %d" % item.quantity)
		
		if item.can_be_consumed():
			items_list.add_item("%s x%d" % [item.name, item.quantity])
	
	print("\nItems displayed in list: %d" % items_list.item_count)

# NEW: Item Selected
func _on_item_selected(index: int):
	# Item is selected, ready to use
	pass

# NEW: Use Item Confirmed
func _on_use_item_confirmed():
	if current_state != BattleState.PLAYER_TURN:
		return
	
	var selected_indices = items_list.get_selected_items()
	if selected_indices.is_empty():
		add_log("Select an item first!")
		return
	
	var selected_index = selected_indices[0]
	var selected_text = items_list.get_item_text(selected_index)
	var item_name = selected_text.split(" x")[0]  # Extract name before " x"
	
	current_state = BattleState.ANIMATING
	use_consumable_item(item_name)

# NEW: Use Consumable Item
# NEW: Use Consumable Item
func use_consumable_item(item_name: String):
	print("\n=== USING CONSUMABLE ITEM: %s ===" % item_name)
	
	var player_inventory = actual_player.inventory
	
	print("Inventory exists: ", player_inventory != null)
	print("Attempting to use item...")
	
	var use_result = player_inventory.use_item(item_name)
	print("use_item() returned: ", use_result)
	
	if use_result:
		print("Item used successfully!")
		
		# CRITICAL FIX: Sync the actual player's health back to the battle character
		player_character.current_hp = actual_player.current_hp
		
		# Now update the UI with the synced health
		update_ui()
		add_log(player_character.char_name + " used " + item_name + "!")
		
		# Close items menu
		items_panel.visible = false
		actions.visible = true
		
		complete_player_turn()
	else:
		print("Failed to use item - checking why...")
		var item = player_inventory.find_item(item_name)
		if item:
			print("Item found: %s" % item.name)
			print("Can be consumed: %s" % item.can_be_consumed())
		else:
			print("Item not found in inventory!")
		
		add_log("Failed to use " + item_name)
		current_state = BattleState.PLAYER_TURN

# NEW: Back Button Pressed
func _on_items_back():
	items_panel.visible = false
	actions.visible = true
	current_state = BattleState.PLAYER_TURN
	update_ui()

func setup_run_button():
	if run:
		run.text = "Run"
		run.pressed.connect(_on_run_pressed)

func _on_run_pressed():
	if current_state != BattleState.PLAYER_TURN:
		return
	
	current_state = BattleState.ANIMATING
	attempt_run()

func attempt_run():
	run_attempt_count += 1
	
	# Calculate success chance (decreases with each attempt)
	var success_chance = base_run_success_chance - (run_attempt_count - 1) * run_difficulty_increase
	success_chance = clamp(success_chance, 0.1, 1.0)  # Keep between 10% and 100%
	
	if randf() < success_chance:
		add_log(player_character.char_name + " successfully fled from battle!")
		end_battle_escape()
	else:
		add_log(player_character.char_name + " failed to escape!")
		complete_player_turn()  # Continue to enemy turn

func end_battle_escape():
	current_state = BattleState.BATTLE_WON  # Or create BATTLE_ESCAPED state
	battle_music.stop()
	
	await get_tree().create_timer(1.0).timeout
	EncounterManager.battle_ended.emit(false, 0)  # No exp reward for running
	close_battle_popup()

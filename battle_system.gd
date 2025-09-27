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

# QTE System variables
var qte_active = false
var qte_sequence: Array[String] = []
var qte_current_index = 0
var qte_time_per_key = 1.0
var qte_key_time_remaining = 0.0
var qte_success_count = 0
var available_qte_keys = ["Z", "X", "C", "V"]

# Reference to the actual player object
var actual_player: Player

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
@onready var restart_button: Button = %Restart
@onready var actions: PanelContainer = $BattleUI/Actions
@onready var qte_choice_label: RichTextLabel = $BattleUI/ChoiceLabel
@onready var qte_choice_timer_bar: ProgressBar = $BattleUI/TimerBar

var available_actions = [
	{"name": "Attack", "type": "attack", "cost": 0},
	{"name": "Magic Blast", "type": "magic", "cost": 15},
	{"name": "Heal", "type": "heal", "cost": 10},
	{"name": "Defend", "type": "defend", "cost": 0}
]

func _ready():
	initialize_battle()
	setup_ui()
	start_battle()

func _process(delta):
	if qte_choice_active:
		handle_qte_choice_timer(delta)
	elif qte_active:
		handle_qte_sequence_timer(delta)

func _input(event):
	if event.is_pressed():
		if qte_choice_active:
			handle_qte_choice_input(event)
		elif qte_active:
			handle_qte_sequence_input(event)

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

func handle_qte_sequence_timer(delta):
	qte_key_time_remaining -= delta
	qte_choice_timer_bar.value = (qte_key_time_remaining / qte_time_per_key) * 100
	
	# Failed if time runs out on current key
	if qte_key_time_remaining <= 0:
		complete_qte(false)

func handle_qte_sequence_input(event):
	if qte_current_index < qte_sequence.size():
		var expected_key = qte_sequence[qte_current_index]
		var pressed_key = ""
		
		match event.keycode:
			KEY_Z:
				pressed_key = "Z"
			KEY_X:
				pressed_key = "X"
			KEY_C:
				pressed_key = "C"
			KEY_V:
				pressed_key = "V"
		
		if pressed_key == expected_key:
			qte_success_count += 1
			qte_current_index += 1
			qte_key_time_remaining = qte_time_per_key
			
			# Update display
			update_qte_display()
			
			# Check if sequence is complete
			if qte_current_index >= qte_sequence.size():
				complete_qte(true)
		else:
			# Wrong key pressed - fail immediately
			complete_qte(false)
	
func initialize_battle():
	print("Initializing battle..." + "\n")
	
	# Get the actual player reference instead of stats dictionary
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
	setup_restart_button()
	update_ui()
	
	# Hide QTE UI initially
	qte_choice_label.visible = false
	qte_choice_timer_bar.visible = false

func start_battle():
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

func process_player_action(action: Dictionary):
	match action.type:
		"attack":
			player_attack()
		"defend":
			player_defend()
	
	if not qte_choice_active and not qte_active:
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
	# 20% chance for QTE
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
	current_state = BattleState.ANIMATING
	
	match choice:
		"attempt":
			start_actual_qte()
		"skip":
			execute_normal_attack()
			complete_player_turn()

func start_actual_qte():
	current_state = BattleState.QTE_ACTIVE
	qte_active = true
	qte_current_index = 0
	qte_success_count = 0
	qte_key_time_remaining = qte_time_per_key
	
	# Generate random sequence of 3-5 keys
	var sequence_length = randi_range(3, 5)
	qte_sequence.clear()
	for i in sequence_length:
		qte_sequence.append(available_qte_keys[randi() % available_qte_keys.size()])
	
	update_qte_display()
	qte_choice_label.visible = true
	qte_choice_timer_bar.visible = true

func update_qte_display():
	var display_text = "[center]QTE Sequence!\n\n"
	
	for i in range(qte_sequence.size()):
		if i < qte_current_index:
			display_text += "[color=green]" + qte_sequence[i] + "[/color] "
		elif i == qte_current_index:
			display_text += "[color=yellow][b]" + qte_sequence[i] + "[/b][/color] "
		else:
			display_text += qte_sequence[i] + " "
	
	display_text += "\n\nProgress: " + str(qte_current_index) + "/" + str(qte_sequence.size()) + "[/center]"
	qte_choice_label.text = display_text

func complete_qte(success: bool):
	qte_active = false
	qte_choice_label.visible = false
	qte_choice_timer_bar.visible = false
	current_state = BattleState.ANIMATING
	
	if success:
		var success_rate = float(qte_success_count) / float(qte_sequence.size())
		var damage_multiplier = 1.0 + (success_rate * 0.8)  # Up to 1.8x damage
		var bonus_damage = int(calculate_damage(player_character.attack, enemy.get_current_defense()) * damage_multiplier)
		enemy.take_damage(bonus_damage)
		add_log(player_character.char_name + " performs a perfect combo for " + str(bonus_damage) + " damage!")
	else:
		add_log("QTE failed! Normal attack.")
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

extends Control

class_name BattleSystem  # Fixed typo

enum BattleState {
	INIT,
	PLAYER_TURN,
	ENEMY_TURN,
	BATTLE_WON,
	BATTLE_LOST,
	ANIMATING,
	DIGGING,
	IDLE,
	MOVING
}

var current_state: BattleState = BattleState.INIT
var player: Character
var enemy: Character
var battle_log: Array[String] = []
var enemy_exp_reward: int = 0

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
	
func initialize_battle():
	print("Initializing battle..." + "\n")
	
	var player_stats = EncounterManager.get_player_stats()
	
	if player_stats == null:
		print("ERROR: Player stats is null!")
		return
	
	# Create new Character instances (not using singleton for individual battle characters)
	player = Character.new(
		player_stats.get("name"),
		player_stats.get("max_hp"),  # Use max_hp for initialization
		player_stats.get("base_attack"),
		player_stats.get("base_defense"),
		player_stats.get("base_speed")
	)
	# Set current HP after creation
	player.current_hp = player_stats.get("current_hp")
	
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
	print("Player: ", player.char_name, " HP:", player.current_hp, "/", player.max_hp)
	print("Enemy: ", enemy.char_name, " HP:", enemy.current_hp, "/", enemy.max_hp, "\n")
	
func setup_ui():
	setup_attack_button()
	setup_defend_button()
	setup_restart_button()
	update_ui()

func start_battle():
	add_log("Battle begins!")
	add_log(player.char_name + " (Speed: " + str(player.base_speed) + ") vs " + enemy.char_name + " (Speed: " + str(enemy.base_speed) + ")")
	
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
	
	# The Character class now handles speed reduction in act()
	player.act()
	
	update_ui()
	
	if not enemy.is_alive():
		end_battle(true)
		return
	
	await get_tree().create_timer(1.0).timeout
	
	determine_next_turn()

func player_attack():
	# Use the improved damage calculation from Character class
	var damage = calculate_damage(player.attack, enemy.get_current_defense())
	enemy.take_damage(damage)
	add_log(player.char_name + " attacks for " + str(damage) + " damage!")

func player_defend():
	player.defend()
	add_log(player.char_name + " takes a defensive stance! (Defense: " + str(player.get_current_defense()) + ")")

func process_enemy_turn():
	if current_state != BattleState.ENEMY_TURN:
		return 
	
	current_state = BattleState.ANIMATING
	
	var actions = ["attack", "attack"]
	var chosen_action = actions[randi() % actions.size()]
	
	match chosen_action:
		"attack":
			enemy_attack()
	
	# The Character class now handles speed reduction and defense reset
	enemy.act()
	
	update_ui()
	
	if not player.is_alive():
		end_battle(false)
		return
	
	await get_tree().create_timer(1.0).timeout
	
	determine_next_turn()

func enemy_attack():
	var damage = calculate_damage(enemy.attack, player.get_current_defense())
	player.take_damage(damage)
	add_log(enemy.char_name + " attacks for " + str(damage) + " damage!")
	
func end_battle(player_won: bool):
	if player_won:
		current_state = BattleState.BATTLE_WON
		add_log("Victory! " + enemy.char_name + " has been defeated!")
		add_log("Gained " + str(enemy_exp_reward) + " EXP!\n")
	
		var updated_stats = EncounterManager.get_player_stats()
		if updated_stats != null:
			updated_stats["current_hp"] = player.current_hp
			EncounterManager.update_player_stats(updated_stats)
		
		await get_tree().create_timer(1.0).timeout
		EncounterManager.battle_ended.emit(true, enemy_exp_reward)
		close_battle_popup()
	else:
		current_state = BattleState.BATTLE_LOST
		add_log("Defeat! " + player.char_name + " has fallen...\n")
		
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
	if player_name_label:
		var player_stats = EncounterManager.get_player_stats()
		player_name_label.text = player.char_name + " (Lv." + str(player_stats["level"]) + ")"
	
	if player_hp_bar and player_hp_label:
		var hp_ratio = float(player.current_hp) / float(player.max_hp)
		player_hp_bar.value = hp_ratio * 100
		player_hp_label.text = str(player.current_hp) + "/" + str(player.max_hp)
	
	if enemy_name_label:
		enemy_name_label.text = enemy.char_name
		
	if enemy_hp_bar and enemy_hp_label:
		var hp_ratio = float(enemy.current_hp) / float(enemy.max_hp)
		enemy_hp_bar.value = hp_ratio * 100
		enemy_hp_label.text = str(enemy.current_hp) + "/" + str(enemy.max_hp)
	
	update_action_buttons()
	
	print("Current state: ", BattleState.keys()[current_state], "\n")
	if player and enemy:
		print("Player speed: ", player.current_speed, " | Enemy speed: ", enemy.current_speed, "\n")

func get_next_actor() -> Character:
	if player.current_speed >= enemy.current_speed:
		return player
	else:
		return enemy

func determine_next_turn():
	if not player.is_alive() or not enemy.is_alive():
		return
	
	player.advance_time()
	enemy.advance_time()
	
	var next_actor = get_next_actor()
	
	if next_actor == player:
		actions.visible = true
		var effective_speed = player.get_speed_with_fatigue()
		var fatigue_text = ""
		if effective_speed < player.base_speed:
			fatigue_text = " (Fatigued: " + str(effective_speed) + "/" + str(player.base_speed) + ")"
		add_log(player.char_name + "'s turn! (Speed: " + str(player.current_speed) + ")" + fatigue_text)
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

extends Node2D
class_name WorldNPC

enum NPCType {
	TRADER,
	GUIDE,
	SCHOLAR,
	HERMIT,
	NEIGHBOUR
}

var environment: GameEnviroment
var npc_type: NPCType
var sprite: ColorRect
var interaction_label: Label
var dialogue: Dictionary = {}
var inventory: Array[String] = []
var is_interactable: bool = true
var has_been_talked_to: bool = false
var dialogue_key: String = ""
var current_stage: int = 0
var player: Player


# NPC-specific data
var npc_name: String = ""
var npc_description: String = ""

func _init(env: GameEnviroment, type: NPCType = NPCType.TRADER):
	environment = env
	npc_type = type
	setup_npc_data()
	setup_sprite()

func setup_npc_data():
	match npc_type:
		NPCType.TRADER:
			npc_name = "Merchant"
			npc_description = "A traveling trader with various goods"
			inventory = ["Health Potion", "Mining Pick", "Map Fragment"]
			dialogue_key = "merchant_trader"
		
		NPCType.GUIDE:
			npc_name = "Guide"
			npc_description = "An experienced explorer who knows these tunnels"
			dialogue_key = "helpful_guide"
		
		NPCType.SCHOLAR:
			npc_name = "Scholar"
			npc_description = "A learned person studying these ancient structures"
			dialogue_key = "ancient_scholar"
		
		NPCType.HERMIT:
			npc_name = "Hermit"
			npc_description = "A reclusive figure who has made these tunnels their home"
			dialogue_key = "wise_hermit"
		
		NPCType.NEIGHBOUR:
			npc_name = "Steve"
			npc_description = "A helpful neighbor who knows the area"
			dialogue_key = "steve_neighbour"

func setup_sprite():
	sprite = ColorRect.new()
	sprite.size = Vector2(environment.SIZE, environment.SIZE)
	
	# Different colors for different NPC types
	match npc_type:
		NPCType.TRADER:
			sprite.color = Color.GOLD
		NPCType.GUIDE:
			sprite.color = Color.GREEN
		NPCType.SCHOLAR:
			sprite.color = Color.BLUE
		NPCType.HERMIT:
			sprite.color = Color.PURPLE
		NPCType.NEIGHBOUR:
			sprite.color = Color.AQUAMARINE
	
	sprite.position = Vector2(0, 0)
	add_child(sprite)
	
	# Add interaction indicator
	interaction_label = Label.new()
	interaction_label.text = "!"
	interaction_label.position = Vector2(environment.SIZE - 15, -20)
	interaction_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(interaction_label)

func interact_with_player() -> Dictionary:
	var dialogue_data = DialogueSystem.get_dialogue_data()
	var response = {}
	
	if dialogue_key != "" and dialogue_data.has(dialogue_key):
		var npc_dialogue = dialogue_data[dialogue_key]
		var stages = npc_dialogue["stages"]
		
		# Get current stage (ensure we don't go past the last stage)
		var stage_index = min(current_stage, stages.size() - 1)
		var current_stage_data = stages[stage_index]
		
		# Set basic response data
		response["message"] = current_stage_data["message"]
		response["npc_name"] = npc_name
		response["npc_type"] = npc_type
		
		var current_player = environment.player_reference
		
		# Handle specific action flags for compatibility
		if current_stage_data.has("function") and current_stage_data["function"] != "":
			var function_result = call(current_stage_data["function"], current_player)
			if function_result:
				response.merge(function_result)
		
		# Advance to next stage if current stage is not repeatable
		if not current_stage_data.get("repeatable", false):
			if current_stage < stages.size() - 1:
				current_stage += 1
	else:
		# Fallback for NPCs without dialogue system
		response["message"] = "Hello there."
		response["npc_name"] = npc_name
		response["npc_type"] = npc_type
		response["actions"] = []
		has_been_talked_to = true
	
	return response

func get_grid_position() -> Vector2i:
	return Vector2i(int(position.x / environment.SIZE), int(position.y / environment.SIZE))

func get_world_position() -> Vector2:
	return position

func is_adjacent_to_player() -> bool:
	var npc_grid = get_grid_position()
	var player_grid = environment.get_player_grid_position()
	var distance = npc_grid.distance_to(Vector2(player_grid))
	return distance <= 1.41  # sqrt(2) for diagonal adjacency

func get_interaction_info() -> Dictionary:
	return {
		"name": npc_name,
		"description": npc_description,
		"type": npc_type,
		"can_interact": is_interactable,
		"talked_before": has_been_talked_to
	}

func give_potion(player: Player) -> void:
	player.inventory.add_item_by_name("Health Potion", Item.ItemType.CONSUMABLE, 3)
	player.inventory.add_item_by_name("Stamina Potion", Item.ItemType.CONSUMABLE, 2)
	player.inventory.add_item_by_name("Mining Pick", Item.ItemType.MISC, 1)
	

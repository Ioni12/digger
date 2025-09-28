# PlayerInteraction.gd - Handles dialogue interactions with NPCs
extends Node
class_name PlayerInteraction

# Signals for dialogue system
signal dialogue_started(npc: WorldNPC, message: String, npc_data: Dictionary)
signal dialogue_ended()

# Dependencies (injected by Player)
var player_movement: PlayerMovement
var environment: GameEnviroment

# State
var is_in_dialogue: bool = false
var current_npc: WorldNPC = null

func _ready():
	# Connect to input if needed
	pass

## PUBLIC INTERFACE ##

func try_start_dialogue() -> bool:
	print("DEBUG: try_start_dialogue called, is_in_dialogue: ", is_in_dialogue)
	
	if is_in_dialogue:
		print("DEBUG: Already in dialogue, returning false")
		return false
		
	var adjacent_npc = get_adjacent_npc()
	print("DEBUG: Adjacent NPC found: ", adjacent_npc != null)
	
	if not adjacent_npc:
		return false
	
	print("DEBUG: Starting dialogue with: ", adjacent_npc.npc_name)
	start_dialogue_with_npc(adjacent_npc)
	return true

func can_start_dialogue() -> bool:
	"""Check if dialogue can be started (NPC nearby and not already in dialogue)."""
	return not is_in_dialogue and get_adjacent_npc() != null

func get_dialogue_prompt() -> String:
	"""Get text to display when near an NPC."""
	if is_in_dialogue:
		return ""
		
	var npc = get_adjacent_npc()
	if npc:
		return "Press [E] to talk to %s" % npc.npc_name
	return ""

func end_dialogue():
	print("DEBUG: PlayerInteraction.end_dialogue() called")
	print("DEBUG: Was in dialogue: ", is_in_dialogue)
	
	if not is_in_dialogue:
		print("DEBUG: Not in dialogue, nothing to end")
		return
		
	is_in_dialogue = false
	current_npc = null
	
	if player_movement:
		player_movement.current_state = PlayerMovement.PlayerState.IDLE
	
	dialogue_ended.emit()
	print("DEBUG: Dialogue ended, is_in_dialogue now: ", is_in_dialogue)

## SETUP METHODS ##

func setup_dependencies(movement_component: PlayerMovement, environment_ref: GameEnviroment):
	"""Setup required component references."""
	player_movement = movement_component
	environment = environment_ref

## PRIVATE METHODS ##

func get_adjacent_npc() -> WorldNPC:
	"""Find NPC adjacent to player."""
	if not environment:
		return null
	return environment.entity_manager.get_adjacent_npc()

func start_dialogue_with_npc(npc: WorldNPC):
	"""Begin dialogue with specified NPC."""
	if not npc or is_in_dialogue:
		return
		
	# Set dialogue state
	is_in_dialogue = true
	current_npc = npc
	
	# Pause player movement
	if player_movement:
		player_movement.current_state = PlayerMovement.PlayerState.IDLE
		player_movement.is_moving = false
	
	# Get NPC's dialogue response
	var interaction_response = npc.interact_with_player()
	var npc_name = interaction_response.get("npc_name", npc.npc_name)
	var message = interaction_response.get("message", "...")
	
	print("Started dialogue with: %s" % npc_name)
	
	# Signal to main game for UI handling
	dialogue_started.emit(npc, message, interaction_response)

## INPUT HANDLING ##

func handle_interaction_input():
	"""Call this from your input handling code."""
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		try_start_dialogue()

# Alternative: Handle input internally


## UTILITY METHODS ##

func get_current_npc_info() -> Dictionary:
	"""Get information about the NPC currently being talked to."""
	if current_npc:
		return {
			"name": current_npc.npc_name,
			"type": current_npc.npc_type,
			"position": current_npc.position
		}
	return {}

func has_current_npc() -> bool:
	"""Check if currently in dialogue with an NPC."""
	return current_npc != null and is_in_dialogue

## DEBUG METHODS ##

func debug_force_end_dialogue():
	"""Force end dialogue for debugging purposes."""
	if is_in_dialogue:
		print("DEBUG: Force ending dialogue")
		end_dialogue()

func debug_print_state():
	"""Print current interaction state."""
	print("PlayerInteraction State:")
	print("  In dialogue: %s" % is_in_dialogue)
	print("  Current NPC: %s" % (current_npc.npc_name if current_npc else "None"))
	print("  Can start dialogue: %s" % can_start_dialogue())
	print("  Adjacent NPC: %s" % (get_adjacent_npc().npc_name if get_adjacent_npc() else "None"))

# In PlayerInteraction.gd, replace the _input function with:
func _input(event):
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		# Only start NEW dialogue if not already in one
		if not is_in_dialogue:
			try_start_dialogue()
		# If we're in dialogue, let the DialogueUI handle the input

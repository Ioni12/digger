# DialogueUI.gd - Fixed version with correct function names
extends Control
class_name DialogueUI

@onready var dialogue_panel: Panel = $DialoguePanel
@onready var npc_name_label: Label = $DialoguePanel/VBoxContainer/NPCNameLabel
@onready var dialogue_text: Label = $DialoguePanel/VBoxContainer/DialogueText
@onready var continue_button: Button = $DialoguePanel/VBoxContainer/HBoxContainer/ContinueButton
@onready var trade_button: Button = $DialoguePanel/VBoxContainer/HBoxContainer/TradeButton
@onready var close_button: Button = $DialoguePanel/VBoxContainer/HBoxContainer/CloseButton

var current_npc: WorldNPC
var current_response: Dictionary
var is_dialogue_active: bool = false

signal dialogue_closed
signal trade_requested(npc: WorldNPC)

func _ready():
	print("DEBUG: DialogueUI _ready() called")
	
	# Connect button signals with error checking
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		print("DEBUG: Continue button connected")
	else:
		print("ERROR: continue_button not found")
		
	if trade_button:
		trade_button.pressed.connect(_on_trade_pressed)
		print("DEBUG: Trade button connected")
	else:
		print("ERROR: trade_button not found")
		
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		print("DEBUG: Close button connected")
	else:
		print("ERROR: close_button not found")
	
	# Hide UI initially
	hide()
	print("DEBUG: DialogueUI hidden initially")

func _input(event):
	if is_dialogue_active and event.is_action_pressed("ui_cancel"):
		close_dialogue()

func show_dialogue(npc: WorldNPC, response: Dictionary):
	"""Display dialogue with the given NPC and response data"""
	print("DEBUG: show_dialogue called")
	print("DEBUG: NPC: ", npc.npc_name if npc else "null")
	print("DEBUG: Response: ", response)
	
	current_npc = npc
	current_response = response
	is_dialogue_active = true
	
	# Set UI content with error checking
	if npc_name_label:
		npc_name_label.text = response.get("npc_name", "Unknown")
		print("DEBUG: Set NPC name to: ", npc_name_label.text)
	else:
		print("ERROR: npc_name_label is null")
		
	if dialogue_text:
		dialogue_text.text = response.get("message", "...")
		print("DEBUG: Set dialogue text to: ", dialogue_text.text)
	else:
		print("ERROR: dialogue_text is null")
	
	# Configure buttons based on NPC type
	setup_buttons(response)
	
	# Show the UI
	show()
	print("DEBUG: DialogueUI show() called - visible: ", visible)
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Focus the continue button so it can receive input
	if continue_button:
		continue_button.grab_focus()
	
	print("DEBUG: DialogueUI show() called - visible: ", visible)
	# Pause game
	get_tree().paused = true
	print("DEBUG: Game paused for dialogue")

func setup_buttons(response: Dictionary):
	"""Configure which buttons are visible based on NPC type and interaction"""
	print("DEBUG: setup_buttons called")
	
	# Always show continue button
	if continue_button:
		continue_button.visible = true
	
	# Show trade button only for traders
	if trade_button:
		if response.get("can_trade", false):
			trade_button.visible = true
			trade_button.text = "Trade"
		else:
			trade_button.visible = false
	
	# Always show close button
	if close_button:
		close_button.visible = true
	
	print("DEBUG: Buttons configured - continue: ", continue_button.visible if continue_button else "null", " trade: ", trade_button.visible if trade_button else "null", " close: ", close_button.visible if close_button else "null")

func close_dialogue():
	print("DEBUG: DialogueUI.close_dialogue called")
	is_dialogue_active = false
	hide()
	get_tree().paused = false
	dialogue_closed.emit()
	print("DEBUG: DialogueUI dialogue closed and signal emitted")

# FIXED FUNCTION NAMES (removed asterisks)
func _on_continue_pressed():
	"""Handle continue button press - could show more dialogue"""
	print("DEBUG: Continue button pressed")
	if current_npc:
		# Get next dialogue from NPC
		var next_response = current_npc.interact_with_player()
		
		# Update dialogue text
		if dialogue_text:
			dialogue_text.text = next_response.get("message", "...")
		
		# Update current response
		current_response = next_response
		
		# Reconfigure buttons if needed
		setup_buttons(next_response)

func _on_trade_pressed():
	"""Handle trade button press"""
	print("DEBUG: Trade button pressed")
	if current_npc:
		trade_requested.emit(current_npc)
		close_dialogue()

func _on_close_pressed():
	"""Handle close button press"""
	print("DEBUG: Close button pressed")
	close_dialogue()
